// Opt-in real-server test. Run only against the isolated collapse development server:
// COLLAPSE_INTEGRATION_CONFIG=../collapse-backend/.local/client.json fvm flutter test test/local_server_integration_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/data/profile/profile_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:collapse/src/presentation/chat/chat_cubit.dart';
import 'package:collapse/src/presentation/chat/window_policy.dart';
import 'package:collapse_tinode/tinode.dart';
import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/fake_gateway.dart';

final _configPath = Platform.environment['COLLAPSE_INTEGRATION_CONFIG'];

void main() {
  test(
    'repository disposal drains an active SQLite snapshot before close',
    () async {
      final directory = await Directory.systemTemp.createTemp('collapse_close_');
      final file = File('${directory.path}/messages.sqlite');
      final database = _HeldSnapshotDatabase(file);
      final gateway = TinodeGateway(
        endpoint: Uri.parse('http://localhost:6060'),
        apiKey: 'test',
      );
      final repository = ChatsRepository(
        database: database,
        gateway: gateway,
        serverId: 'local',
      );
      await repository.start('fixture');
      await repository.send('usrPeer', 'queued');
      final window = (await repository.openHistory('usrPeer'))!;
      database.hold = true;
      final reading = repository.inspectHistoryWindow('usrPeer', window.span);
      await database.entered.future;
      var disposed = false;
      final closing = repository.dispose().then((_) => disposed = true);
      try {
        await pumpEventQueue();
        expect(
          disposed,
          isFalse,
          reason: 'caller must not close a live transaction',
        );
      } finally {
        database.release.complete();
        await reading;
        await closing;
        await database.close();
        await gateway.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'disposal waits for an event continuation outside a SQLite transaction',
    () async {
      final database = _HeldEventDatabase();
      final gateway = FakeGateway();
      final repository = ChatsRepository(
        database: database,
        gateway: gateway,
        serverId: 'local',
      );
      await repository.start('me');
      gateway.controller.add(
        const TinodeEvent('data', {
          'topic': 'usrPeer',
          'seq': 1,
          'from': 'peer',
          'content': 'held before the next local query',
        }),
      );
      await database.entered.future;
      var disposed = false;
      final closing = repository.dispose().then((_) => disposed = true);
      try {
        await pumpEventQueue();
        expect(disposed, isFalse);
      } finally {
        database.release.complete();
        await closing;
        await database.close();
        await gateway.dispose();
      }
    },
  );

  test(
    'disposal after logout retains an already accepted publish until its ACK',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final gateway = FakeGateway();
      final repository = ChatsRepository(
        database: database,
        gateway: gateway,
        serverId: 'local',
      );
      final accepted = Completer<void>(), releaseAck = Completer<void>();
      gateway.afterPublish = (_) {
        accepted.complete();
        return releaseAck.future;
      };
      await repository.start('me');
      await repository.send('usrPeer', 'accepted before logout');
      final id = (await database.pendingOutbox('local|me')).single.clientId;
      gateway.ready = true;
      final flushing = repository.flushOutbox();
      await accepted.future;
      await repository.stop();
      var disposed = false;
      final closing = repository.dispose().then((_) => disposed = true);
      try {
        await pumpEventQueue();
        expect(
          disposed,
          isFalse,
          reason: 'the original account still owns ACK',
        );
      } finally {
        releaseAck.complete();
        await flushing;
        await closing;
        expect((await database.messageById('local|me', id))!.seq, 1);
        expect(await database.pendingOutbox('local|me'), isEmpty);
        await database.close();
        await gateway.dispose();
      }
    },
  );

  test(
    'failed local initialization can be retried for the same account',
    () async {
      final database = _FailFirstOriginsDatabase();
      final gateway = TinodeGateway(
        endpoint: Uri.parse('http://localhost:6060'),
        apiKey: 'test',
      );
      final repository = ChatsRepository(
        database: database,
        gateway: gateway,
        serverId: 'local',
      );
      try {
        await expectLater(repository.start('fixture'), throwsStateError);
        expect(repository.currentUserId, isEmpty);
        await repository.start('fixture');
        expect(database.attempts, 2);
        expect(repository.currentUserId, 'fixture');
      } finally {
        await repository.dispose();
        await database.close();
        await gateway.dispose();
      }
    },
  );

  test(
    'real Tinode + Flutter repositories: media, offline outbox, receipts and bounded history',
    () async {
      // Each simulated device has its own independent executor/file, never a shared connection.
      final oldDatabaseWarning =
          driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(() {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = oldDatabaseWarning;
      });
      final config = jsonDecode(await File(_configPath!).readAsString()) as Map;
      expect(
        config['TINODE_HOST'],
        '127.0.0.1:6060',
        reason: 'This test must never create or delete production accounts.',
      );
      expect(config['TINODE_TLS'], false);
      final endpoint = Uri.parse('http://${config['TINODE_HOST']}');
      final apiKey = config['TINODE_API_KEY'] as String;
      final directory = await Directory.systemTemp.createTemp(
        'collapse_client_e2e_',
      );
      final clients = <_Client>[];
      final accounts = <({String user, String token})>[];
      addTearDown(() async {
        for (final client in clients.reversed) {
          await client.dispose();
        }
        // Delete only accounts created by this run, using standard Tinode packets.
        // No production API or application code gains an administrator operation.
        for (final account in accounts.reversed) {
          await _deleteTestAccount(
            endpoint,
            apiKey,
            account.user,
            account.token,
          );
        }
        await directory.delete(recursive: true);
      });

      Future<_Client> register(String label, {File? databaseFile}) async {
        final gateway = TinodeGateway(endpoint: endpoint, apiKey: apiKey);
        final client = _Client(gateway, databaseFile);
        clients.add(client);
        await gateway.connect();
        final suffix = List.generate(
          7,
          (_) => Random.secure().nextInt(16).toRadixString(16),
        ).join();
        client.username = 'e2e${label.toLowerCase()}$suffix';
        final password = List.generate(
          24,
          (_) => Random.secure().nextInt(16).toRadixString(16),
        ).join();
        await gateway.createAccountBasic(
          client.username,
          password,
          public: {'fn': 'E2E $label'},
        );
        client.user = gateway.userId!;
        client.token = gateway.token!;
        accounts.add((user: client.user, token: client.token));
        await gateway.disconnect();
        await gateway.connect();
        await gateway.loginBasic(client.username, password);
        await gateway.probe();
        expect(gateway.userId, client.user);
        client.token = gateway.token!;
        await client.openDatabase();
        return client;
      }

      final alice = await register(
        'Alice',
        databaseFile: File('${directory.path}/alice.sqlite'),
      );
      final bob = await register('Bob');
      final aliceProfile = ProfileRepository(alice.gateway);
      final bobProfile = ProfileRepository(bob.gateway);
      final image = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jR1cAAAAASUVORK5CYII=',
      );
      await aliceProfile.update(
        name: 'E2E Alice edited',
        about: 'Local integration fixture',
        photo: image,
        photoName: 'avatar.png',
        photoMime: 'image/png',
      );
      final search = await bobProfile.search(alice.username);
      expect(search.map((profile) => profile.id), contains(alice.user));
      final profile = await bobProfile.get(alice.user, refresh: true);
      expect(profile.name, 'E2E Alice edited');
      expect(profile.avatarRef, isNotEmpty);
      expect(profile.avatarRef, startsWith('/v0/file/s/'));
      await alice.chat.open(bob.user);

      Future<ChatMessage> sendAndReceive(
        Object content, {
        Map<String, dynamic> head = const {},
        List<PendingUpload> uploads = const [],
      }) async {
        final previous =
            (await bob.repository.getTopic(alice.user))?.serverSeq ?? 0;
        await alice.chat.send(content, head: head, uploads: uploads);
        await _drain(alice);
        await _eventually(
          () async =>
              ((await bob.repository.getTopic(alice.user))?.serverSeq ?? 0) >
              previous,
        );
        final latest = (await alice.repository.loadLatest(bob.user)).last;
        await _eventually(
          () async =>
              (await bob.repository.getMessage(alice.user, latest.seq)) != null,
        );
        expect(latest.seq, greaterThan(0));
        expect(latest.localSeq, greaterThan(0));
        expect(latest.head['x-client-id'], latest.id);
        expect(await alice.database.pendingOutbox(alice.scope), isEmpty);
        final matching = await alice.database
            .customSelect(
              'SELECT count(*) AS count FROM messages WHERE scope = ? AND client_id = ?',
              variables: [Variable(alice.scope), Variable(latest.id)],
            )
            .getSingle();
        expect(
          matching.read<int>('count'),
          1,
          reason: 'ACK and echo must merge into one durable row.',
        );
        return latest;
      }

      final plain = await sendAndReceive(
        DraftyCodec.text('E2E first message\nsecond line'),
      );
      expect(
        DraftyCodec.plainText(plain.content),
        'E2E first message\nsecond line',
      );
      final unopened = await bob.repository.getTopic(alice.user);
      expect(unopened?.title, 'E2E Alice edited');
      expect(unopened?.lastPreview, contains('E2E first message'));
      expect(
        unopened?.unreadCount,
        1,
        reason:
            'New conversation preview must load without opening its screen.',
      );
      await bob.chat.open(alice.user);
      await bob.chat.markVisible(plain.seq);
      await _eventually(
        () async =>
            ((await alice.repository.getTopic(bob.user))?.peerReadSeq ?? 0) >=
            plain.seq,
      );
      expect(
        (await alice.repository.getMessage(bob.user, plain.seq))!.delivery,
        Delivery.read,
      );
      expect(
        (await bob.repository.getTopic(alice.user))!.lastPreview,
        contains('E2E first message'),
      );

      final formatted = DraftyCodec.markdown(
        '**👩‍💻** and _e\u0301_\n[link](https://example.com)',
      );
      final rich = await sendAndReceive(formatted);
      expect(
        (await bob.repository.getMessage(alice.user, rich.seq))!.content,
        formatted,
      );
      final quote = DraftyCodec.reply(
        content: DraftyCodec.markdown('A **reply**'),
        quote: rich.content,
        authorId: alice.user,
        authorName: '👩‍💻',
      );
      final richReply = await sendAndReceive(quote, head: {'reply': rich.seq});
      expect(
        (await bob.repository.getMessage(alice.user, richReply.seq))!.content,
        quote,
      );
      expect(
        DraftyCodec.formats(quote).where((format) => format['tp'] == 'QQ'),
        hasLength(1),
      );

      final wav = Uint8List(2044);
      final wavView = ByteData.sublistView(wav);
      wav.setRange(0, 4, ascii.encode('RIFF'));
      wavView.setUint32(4, wav.length - 8, Endian.little);
      wav.setRange(8, 16, ascii.encode('WAVEfmt '));
      wavView.setUint32(16, 16, Endian.little);
      wavView.setUint16(20, 1, Endian.little);
      wavView.setUint16(22, 1, Endian.little);
      wavView.setUint32(24, 8000, Endian.little);
      wavView.setUint32(28, 16000, Endian.little);
      wavView.setUint16(32, 2, Endian.little);
      wavView.setUint16(34, 16, Endian.little);
      wav.setRange(36, 40, ascii.encode('data'));
      wavView.setUint32(40, 2000, Endian.little);
      // The video fixture exercises transport and VD metadata, not a media decoder.
      final video = Uint8List.fromList([
        0,
        0,
        0,
        24,
        ...ascii.encode('ftypmp42'),
        0,
        0,
        0,
        0,
        ...ascii.encode('mp42isom'),
        ...List.filled(520, 0),
      ]);
      final fixtures = [
        (type: 'IM', mime: 'image/png', name: 'image.png', bytes: image),
        (type: 'AU', mime: 'audio/wav', name: 'voice.wav', bytes: wav),
        (type: 'VD', mime: 'video/mp4', name: 'video.mp4', bytes: video),
        (
          type: 'EX',
          mime: 'application/octet-stream',
          name: 'file.bin',
          bytes: Uint8List.fromList(utf8.encode('E2E attachment fixture')),
        ),
      ];
      ChatMessage? imageMessage;
      for (final fixture in fixtures) {
        final content = DraftyCodec.media(
          type: fixture.type,
          ref: '',
          name: fixture.name,
          mime: fixture.mime,
          size: fixture.bytes.length,
          caption: 'E2E ${fixture.type}',
        );
        final sent = await sendAndReceive(
          content,
          uploads: [
            PendingUpload(
              entityIndex: 0,
              bytes: fixture.bytes,
              name: fixture.name,
              mime: fixture.mime,
            ),
          ],
        );
        if (fixture.type == 'IM') imageMessage = sent;
        final received = await bob.repository.getMessage(alice.user, sent.seq);
        expect(received!.content, sent.content);
        final ref = ((sent.content as Map)['ent'][0]['data']['ref']) as String;
        expect(ref, isNotEmpty);
        expect(ref, startsWith('/v0/file/s/'));
        expect(Uri.parse(ref).hasAuthority, isFalse);
        expect(
          sent.head['attachments'],
          contains(ref),
          reason:
              'Attachments must be protected from server garbage collection.',
        );
        final download = await http.get(
          bob.gateway.resolveFile(ref),
          headers: {
            'X-Tinode-APIKey': apiKey,
            'Authorization': 'token ${bob.token}',
          },
        );
        expect(download.statusCode, 200);
        expect(download.bodyBytes, fixture.bytes);
      }
      final reply = DraftyCodec.reply(
        content: DraftyCodec.text('E2E reply'),
        quote: imageMessage!.content,
        authorId: alice.user,
        authorName: 'E2E Alice edited',
      );
      final replied = await sendAndReceive(
        reply,
        head: {'reply': imageMessage.seq.toString()},
      );
      expect(replied.head['reply'], imageMessage.seq.toString());
      expect((replied.content as Map)['ent'], isNotEmpty);
      final forwarded = await sendAndReceive(
        DraftyCodec.forward(imageMessage.content),
        head: {
          'forwarded': '${alice.user}:${imageMessage.seq}',
          'attachments': imageMessage.head['attachments'],
        },
      );
      expect(forwarded.content, imageMessage.content);

      // Persist two offline sends, including bytes, close SQLite, reopen it, then reconnect.
      await alice.gateway.disconnect();
      await alice.chat.send(DraftyCodec.text('E2E durable offline text'));
      await alice.chat.send(
        DraftyCodec.media(
          type: 'IM',
          ref: '',
          name: 'offline.png',
          mime: 'image/png',
          size: image.length,
        ),
        uploads: [
          PendingUpload(
            entityIndex: 0,
            bytes: image,
            name: 'offline.png',
            mime: 'image/png',
          ),
        ],
      );
      final queued = await alice.database.pendingOutbox(alice.scope);
      expect(queued, hasLength(2));
      final offlineIds = queued.map((row) => row.clientId).toSet();
      await alice.closeDatabase();
      await alice.openDatabase();
      expect(
        (await alice.database.pendingOutbox(
          alice.scope,
        )).map((row) => row.clientId).toSet(),
        offlineIds,
      );
      final attachment = await alice.database.uploads(
        alice.scope,
        queued.last.clientId,
      );
      expect(attachment.single.bytes, image);
      await alice.chat.open(bob.user);
      expect(
        alice.chat.state.messages.where((message) => message.pending),
        hasLength(2),
      );
      await alice.gateway.connect();
      await alice.gateway.loginToken(alice.token);
      await alice.repository.start(alice.user);
      await _drain(alice);
      for (final id in offlineIds) {
        final row = await alice.database.messageById(alice.scope, id);
        expect(row!.seq, greaterThan(0));
        await _eventually(
          () async =>
              (await bob.repository.getMessage(alice.user, row.seq)) != null,
        );
      }

      // A history larger than 160 messages exercises both ends of the 120-message window.
      for (var index = 0; index < 205; index++) {
        await alice.repository.send(
          bob.user,
          DraftyCodec.text('E2E history $index'),
        );
      }
      await _drain(alice);
      final beforeLive = (await alice.repository.getTopic(bob.user))!.serverSeq;
      await _eventually(
        () async =>
            ((await bob.repository.getTopic(alice.user))?.serverSeq ?? 0) >=
            beforeLive,
      );
      final coldGateway = TinodeGateway(endpoint: endpoint, apiKey: apiKey);
      final cold = _Client(coldGateway, null)
        ..user = bob.user
        ..token = bob.token;
      clients.add(cold);
      await coldGateway.connect();
      await coldGateway.loginToken(bob.token);
      await cold.openDatabase();
      await cold.chat.open(alice.user);
      expect(
        cold.chat.state.messages.length,
        lessThanOrEqualTo(WindowPolicy.pageSize),
      );
      expect(cold.chat.state.messages.last.seq, beforeLive);
      final coldInitialRead = (await cold.repository.getTopic(
        alice.user,
      ))!.readSeq;
      expect(
        (await cold.repository.getTopic(alice.user))!.readSeq,
        coldInitialRead,
        reason:
            'Fetching history must not send a read receipt before visibility.',
      );

      // The widget reports this viewport intent when the reader scrolls away
      // from the tail; a headless Cubit must report the same intent explicitly.
      cold.chat.setFollowingLive(false);
      final visited = <int>{};
      var iterations = 0;
      do {
        visited.addAll(cold.chat.state.messages.map((message) => message.seq));
        expect(
          cold.chat.state.messages.length,
          lessThanOrEqualTo(WindowPolicy.capacity),
        );
        await cold.chat.loadOlder();
        expect(cold.chat.state.error, isNull);
      } while (cold.chat.state.hasOlder && iterations++ < 20);
      visited.addAll(cold.chat.state.messages.map((message) => message.seq));
      expect(WindowPolicy.oldest(cold.chat.state.messages), 1);
      expect(
        visited,
        containsAll(List.generate(beforeLive, (index) => index + 1)),
      );
      expect(cold.chat.state.atLiveEdge, isFalse);
      final oldWindow = cold.chat.state.messages
          .map((message) => message.seq)
          .toList();
      await alice.repository.send(
        bob.user,
        DraftyCodec.text('E2E new while reading old history'),
      );
      await _drain(alice);
      final latest = (await alice.repository.getTopic(bob.user))!.serverSeq;
      await _eventually(
        () async =>
            cold.chat.state.unreadCount > 0 &&
            ((await cold.repository.getTopic(alice.user))?.serverSeq ?? 0) ==
                latest,
      );
      expect(
        cold.chat.state.messages.map((message) => message.seq),
        oldWindow,
        reason:
            'A live arrival must not jump the reader away from old history.',
      );
      iterations = 0;
      while (cold.chat.state.hasNewer && iterations++ < 20) {
        await cold.chat.loadNewer();
        expect(cold.chat.state.error, isNull);
        expect(
          cold.chat.state.messages.length,
          lessThanOrEqualTo(WindowPolicy.capacity),
        );
      }
      expect(WindowPolicy.newest(cold.chat.state.messages), latest);
      expect(cold.chat.state.atLiveEdge, isTrue);
      expect(
        cold.chat.state.unreadCount,
        (await cold.repository.getTopic(alice.user))!.unreadCount,
      );
      expect(cold.chat.state.unreadCount, greaterThan(0));
      expect(
        (await cold.repository.getTopic(alice.user))!.readSeq,
        coldInitialRead,
        reason: 'Neither paging direction implies that a message was visible.',
      );
      // Tinode read watermarks are cumulative; clamp explicit visibility to the server tail.
      await cold.chat.markVisible(latest + 1000);
      await _eventually(() async => cold.chat.state.unreadCount == 0);
      expect((await cold.repository.getTopic(alice.user))!.readSeq, latest);
      await cold.chat.markVisible(1);
      expect((await cold.repository.getTopic(alice.user))!.readSeq, latest);
      await _eventually(
        () async =>
            ((await alice.repository.getTopic(bob.user))?.peerReadSeq ?? 0) ==
            latest,
      );
      final durableHistory = await cold.database.page(
        cold.scope,
        alice.user,
        limit: 1000,
      );
      expect(durableHistory.length, latest);
      expect(
        durableHistory.map((message) => message.seq).toSet().length,
        latest,
      );

      // Exercise standard group membership through the actual profile repository.
      final group = await aliceProfile.createGroup('E2E group');
      await aliceProfile.addMember(group, bob.user);
      await alice.repository.ensureTopic(group);
      await _eventually(
        () async =>
            (await bob.repository.getTopic(group))?.title == 'E2E group',
      );
      expect(
        (await bob.repository.getTopic(group))!.lastPreview,
        isEmpty,
        reason: 'An access invitation must appear before any group messages.',
      );
      await alice.gateway.setMeta(group, {
        'desc': {
          'public': {'fn': 'E2E renamed group'},
        },
      });
      await _eventually(
        () async =>
            (await bob.repository.getTopic(group))?.title ==
            'E2E renamed group',
      );
      await alice.repository.send(group, DraftyCodec.text('E2E group message'));
      await _drain(alice);
      await _eventually(
        () async => (await bob.repository.getMessage(group, 1)) != null,
      );
      expect((await bob.repository.getTopic(group))!.isGroup, isTrue);

      final deleted = await cold.repository.getMessage(alice.user, latest);
      await cold.repository.deleteMessage(deleted!, forEveryone: true);
      await _eventually(
        () async =>
            (await alice.database.messageRow(
              alice.scope,
              bob.user,
              latest,
            ))?.deleted ==
            true,
      );
      expect(
        (await cold.repository.loadLatest(
          alice.user,
        )).any((message) => message.seq == latest),
        isFalse,
      );
    },
    skip: _configPath == null
        ? 'Set COLLAPSE_INTEGRATION_CONFIG for the isolated local Tinode server.'
        : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

class _HeldSnapshotDatabase extends AppDatabase {
  _HeldSnapshotDatabase(File file) : super.forTesting(NativeDatabase(file));
  bool hold = false;
  final entered = Completer<void>(), release = Completer<void>();

  @override
  Future<List<ChatMessage>> historyRows(
    String scope,
    String topic,
    HistorySpan span, {
    HistoryDirection retain = HistoryDirection.older,
    int limit = 121,
  }) async {
    final rows = await super.historyRows(
      scope,
      topic,
      span,
      retain: retain,
      limit: limit,
    );
    if (hold) {
      hold = false;
      entered.complete();
      await release.future;
    }
    return rows;
  }
}

class _FailFirstOriginsDatabase extends AppDatabase {
  _FailFirstOriginsDatabase() : super.forTesting(NativeDatabase.memory());
  int attempts = 0;

  @override
  Future<void> resetAcknowledgedOrigins(String scope) async {
    if (++attempts == 1) {
      throw StateError('Fixture local initialization failure');
    }
    await super.resetAcknowledgedOrigins(scope);
  }
}

class _HeldEventDatabase extends AppDatabase {
  _HeldEventDatabase() : super.forTesting(NativeDatabase.memory());
  final entered = Completer<void>(), release = Completer<void>();

  @override
  Future<MessageRow?> messageRow(String scope, String topicId, int seq) async {
    final row = await super.messageRow(scope, topicId, seq);
    entered.complete();
    await release.future;
    return row;
  }
}

class _Client {
  _Client(this.gateway, this.file);
  final TinodeGateway gateway;
  final File? file;
  late AppDatabase database;
  late ChatsRepository repository;
  late ChatCubit chat;
  String username = '';
  String user = '';
  String token = '';
  bool _databaseOpen = false;
  String get scope => '${gateway.serverUri.origin}|$user';

  Future<void> openDatabase() async {
    database = AppDatabase.forTesting(
      file == null ? NativeDatabase.memory() : NativeDatabase(file!),
    );
    repository = ChatsRepository(
      database: database,
      gateway: gateway,
      serverId: gateway.serverUri.origin,
    );
    chat = ChatCubit(repository);
    _databaseOpen = true;
    await repository.start(user);
  }

  Future<void> closeDatabase() async {
    if (!_databaseOpen) return;
    _databaseOpen = false;
    await chat.close();
    await repository.dispose();
    await database.close();
  }

  Future<void> dispose() async {
    await closeDatabase();
    await gateway.dispose();
  }
}

Future<void> _drain(_Client client) async {
  await _eventually(() async {
    await client.repository.flushOutbox();
    return (await client.database.pendingOutbox(client.scope)).isEmpty;
  });
}

Future<void> _eventually(Future<bool> Function() check) async {
  final caller = StackTrace.current.toString().split('\n').skip(1).first;
  final deadline = DateTime.now().add(const Duration(seconds: 25));
  while (!await check()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for local client/server state at $caller');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

Future<void> _deleteTestAccount(
  Uri endpoint,
  String apiKey,
  String user,
  String token,
) async {
  final ws = await WebSocket.connect(
    endpoint
        .replace(
          scheme: 'ws',
          path: '/v0/channels',
          queryParameters: {'apikey': apiKey},
        )
        .toString(),
  );
  final packets = ws
      .map((frame) => jsonDecode(frame as String) as Map)
      .asBroadcastStream();
  var id = 0;
  Future<void> request(String kind, Map<String, dynamic> body) async {
    final current = '${++id}';
    final pending = packets
        .firstWhere((packet) => (packet['ctrl'] as Map?)?['id'] == current)
        .timeout(const Duration(seconds: 10));
    ws.add(
      jsonEncode({
        kind: {...body, 'id': current},
      }),
    );
    final result = (await pending)['ctrl'] as Map;
    expect(
      result['code'] as int,
      lessThan(400),
      reason: 'Could not clean up this run\'s temporary account.',
    );
  }

  try {
    await request('hi', {'ver': '0.25.3', 'ua': 'collapse-client-e2e-cleanup'});
    await request('login', {'scheme': 'token', 'secret': token});
    await request('del', {'what': 'user', 'user': user, 'hard': true});
  } finally {
    await ws.close();
  }
}
