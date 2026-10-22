import 'dart:async';
import 'dart:typed_data';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:collapse/src/presentation/chat/chat_cubit.dart';
import 'package:collapse/src/presentation/chat/window_policy.dart';
import 'package:collapse_tinode/collapse_tinode.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  late AppDatabase db;
  late FakeGateway gateway;
  late ChatsRepository repo;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = FakeGateway();
    repo = ChatsRepository(database: db, gateway: gateway, serverId: 'local');
    await repo.start('me');
  });
  tearDown(() async {
    await repo.dispose();
    await gateway.dispose();
    await db.close();
  });

  test(
    'first me message presence populates a new chat without subscription churn',
    () async {
      gateway.seed(1);
      gateway.ready = true;
      final populated = repo
          .watchTopic('usrPeer')
          .firstWhere((topic) => topic?.lastPreview == 'message 1');
      gateway.controller.add(
        TinodeEvent('pres', {
          'topic': 'me',
          'src': 'usrPeer',
          'what': 'msg',
          'seq': 1,
        }),
      );
      final topic = await populated.timeout(const Duration(seconds: 5));
      expect(topic?.title, 'Peer');
      expect(topic?.unreadCount, 1);
      expect(gateway.attachments, ['usrPeer']);
      expect(gateway.requests, hasLength(1));

      final second = {...gateway.rows.single, 'seq': 2, 'content': 'message 2'};
      gateway.rows.add(second);
      final updated = repo
          .watchTopic('usrPeer')
          .firstWhere((topic) => topic?.lastPreview == 'message 2');
      for (final what in ['msg', 'read', 'recv']) {
        gateway.controller.add(
          TinodeEvent('pres', {
            'topic': 'me',
            'src': 'usrPeer',
            'what': what,
            'seq': 2,
          }),
        );
      }
      gateway.controller.add(TinodeEvent('data', second));
      await updated.timeout(const Duration(seconds: 5));
      expect(gateway.attachments, ['usrPeer']);
      expect(gateway.requests, hasLength(1));
    },
  );

  test(
    'access invite appears before messages and update refreshes metadata once',
    () async {
      gateway.ready = true;
      gateway.descriptions['grpInvite'] = {
        'public': {'fn': 'Invited group'},
      };
      final invited = repo
          .watchTopic('grpInvite')
          .firstWhere((topic) => topic != null);
      gateway.controller.add(
        TinodeEvent('pres', {
          'topic': 'me',
          'src': 'grpInvite',
          'what': 'acs',
          'acs': {'given': '+JRWPS'},
        }),
      );
      final group = await invited.timeout(const Duration(seconds: 5));
      expect(group?.title, 'Invited group');
      expect(group?.isGroup, isTrue);
      expect(group?.lastPreview, isEmpty);

      gateway.descriptions['grpInvite'] = {
        'public': {
          'fn': 'Renamed group',
          'photo': {'ref': '/v0/file/s/new-avatar'},
        },
      };
      final updated = repo
          .watchTopic('grpInvite')
          .firstWhere((topic) => topic?.title == 'Renamed group');
      gateway.controller.add(
        TinodeEvent('pres', {'topic': 'me', 'src': 'grpInvite', 'what': 'upd'}),
      );
      expect(
        (await updated.timeout(const Duration(seconds: 5)))?.avatarRef,
        '/v0/file/s/new-avatar',
      );
      expect(gateway.attachments, ['grpInvite']);
      expect(
        gateway.requests,
        isEmpty,
        reason: 'Known empty history needs no data request',
      );
    },
  );

  test('revoked-topic metadata does not stop processing other chats', () async {
    gateway.ready = true;
    gateway.inaccessible.add('grpRevoked');
    final updated = repo
        .watchTopic('usrPeer')
        .firstWhere((topic) => topic?.title == 'Peer');
    for (final id in ['grpRevoked', 'usrPeer']) {
      gateway.controller.add(
        TinodeEvent('pres', {'topic': 'me', 'src': id, 'what': 'acs'}),
      );
    }
    await updated.timeout(const Duration(seconds: 5));
    expect(await repo.getTopic('grpRevoked'), isNull);
  });

  test('offline start and raw media enqueue require no connection', () async {
    final content = {
      'txt': ' ',
      'ent': [
        {
          'tp': 'AU',
          'data': {'ref': '', 'duration': 1200},
        },
      ],
    };
    await repo.send(
      'usrPeer',
      content,
      head: {'reply': '2', 'forwarded': 'usrOther:3'},
      uploads: [
        PendingUpload(
          entityIndex: 0,
          bytes: Uint8List.fromList([7, 8, 9]),
          name: 'voice.m4a',
          mime: 'audio/mp4',
        ),
      ],
    );
    expect(await db.pendingOutbox('local|me'), hasLength(1));
    expect(gateway.publishes, 0);
    gateway.ready = true;
    await repo.flushOutbox();
    expect(gateway.uploads, 1);
    expect(gateway.publishes, 1);
    expect(gateway.lastHead?['reply'], '2');
    expect(gateway.lastHead?['forwarded'], 'usrOther:3');
    expect(gateway.lastHead?['attachments'], ['/v0/file/s/file-1']);
    expect(
      ((gateway.lastContent as Map)['ent'] as List).single['data']['duration'],
      1200,
    );
    expect(
      ((gateway.lastContent as Map)['ent'] as List).single['data']['ref'],
      '/v0/file/s/file-1',
    );
    expect(await db.pendingOutbox('local|me'), isEmpty);
    expect((await repo.loadLatest('usrPeer')).single.pending, isFalse);
  });

  test(
    'lost publish ACK reconciles server identity before retry without duplication',
    () async {
      await repo.send('usrPeer', {'txt': 'retry me'});
      final id = (await db.pendingOutbox('local|me')).single.clientId;
      gateway.ready = true;
      gateway.loseAck = true;
      await repo.flushOutbox();
      expect(gateway.publishes, 1);
      expect((await db.pendingOutbox('local|me')).single.ambiguous, isTrue);
      await repo.retry(id);
      expect(gateway.publishes, 1);
      expect(await db.pendingOutbox('local|me'), isEmpty);
      expect((await db.page('local|me', 'usrPeer')).single.id, id);
    },
  );

  test(
    'forward pagination uses bounded intervals, never since-only latest data',
    () async {
      gateway.seed(200);
      gateway.ready = true;
      await repo.ensureTopic('usrPeer');
      final page = await repo.loadAfter('usrPeer', 40);
      expect(page.messages.map((m) => m.seq), List.generate(40, (i) => i + 41));
      expect(gateway.requests.last.since, 41);
      expect(gateway.requests.last.before, 81);
      expect(page.hasMore, isTrue);
    },
  );

  test(
    'sliding window caps at 120 and restores newer pages after trimming',
    () async {
      gateway.seed(500);
      gateway.ready = true;
      final cubit = ChatCubit(repo);
      await cubit.open('usrPeer');
      expect(cubit.state.messages, hasLength(40));
      for (var i = 0; i < 5; i++) {
        await cubit.loadOlder();
        expect(
          cubit.state.messages.length,
          lessThanOrEqualTo(WindowPolicy.capacity),
        );
      }
      expect(cubit.state.hasNewer, isTrue);
      expect(cubit.state.atLiveEdge, isFalse);
      expect(WindowPolicy.newest(cubit.state.messages), lessThan(500));
      for (var i = 0; i < 10 && cubit.state.hasNewer; i++) {
        await cubit.loadNewer();
        expect(cubit.state.messages.length, lessThanOrEqualTo(120));
      }
      expect(WindowPolicy.newest(cubit.state.messages), 500);
      expect(cubit.state.atLiveEdge, isTrue);
      expect(gateway.notes.where((n) => n.what == 'read'), isEmpty);
      await cubit.markVisible(500);
      expect(gateway.notes.where((n) => n.what == 'read').last.seq, 500);
      await cubit.close();
    },
  );

  test('oversized pending bytes are rejected before persistence', () async {
    await expectLater(
      repo.send(
        'usrPeer',
        {
          'ent': [{}],
        },
        uploads: [
          PendingUpload(
            entityIndex: 0,
            bytes: Uint8List(10 * 1024 * 1024 + 1),
            name: 'large',
            mime: 'application/octet-stream',
          ),
        ],
      ),
      throwsArgumentError,
    );
    expect(await db.pendingOutbox('local|me'), isEmpty);
  });

  test(
    'a late deletion response cannot delete the replacement account cache',
    () async {
      gateway.seed(1);
      gateway.ready = true;
      final original = (await repo.loadLatest('usrPeer')).single;
      final started = Completer<void>();
      final finish = Completer<void>();
      gateway.deleteHook = () {
        started.complete();
        return finish.future;
      };
      final deletion = repo.deleteMessage(original);
      await started.future;
      await repo.start('other');
      await db.mergeTopic('local|other', 'usrPeer', const {});
      await db.mergeMessage('local|other', original, 'other');
      finish.complete();
      await deletion;
      expect(
        (await db.messageRow('local|other', 'usrPeer', original.seq))!.deleted,
        isFalse,
      );
      expect(
        (await db.messageRow('local|me', 'usrPeer', original.seq))!.deleted,
        isTrue,
      );
    },
  );

  test(
    'deleting an offline pending attachment cancels its queue and bytes',
    () async {
      await repo.send(
        'usrPeer',
        {
          'ent': [
            {'tp': 'EX', 'data': {}},
          ],
        },
        uploads: [
          PendingUpload(
            entityIndex: 0,
            bytes: Uint8List.fromList([1, 2]),
            name: 'test.bin',
            mime: 'application/octet-stream',
          ),
        ],
      );
      final pending = (await repo.loadLatest('usrPeer')).single;
      await repo.deleteMessage(pending);
      expect(await db.pendingOutbox('local|me'), isEmpty);
      expect(await db.uploads('local|me', pending.id), isEmpty);
      expect(await repo.loadLatest('usrPeer'), isEmpty);
      gateway.ready = true;
      await repo.flushOutbox();
      expect(gateway.publishes, 0);
    },
  );

  test(
    'an old chat cannot send or mark read after account change or close',
    () async {
      final cubit = ChatCubit(repo);
      await cubit.open('usrPeer');
      await repo.start('other');
      await expectLater(cubit.send('late picker result'), throwsStateError);
      await cubit.markVisible(500);
      expect(await db.pendingOutbox('local|other'), isEmpty);
      expect(gateway.notes.where((note) => note.what == 'read'), isEmpty);
      await cubit.close();
      await repo.start('me');
      await expectLater(cubit.send('disposed picker result'), throwsStateError);
      expect(await db.pendingOutbox('local|me'), isEmpty);
    },
  );

  test(
    'reading within newest window freezes visible IDs during 150 live arrivals',
    () async {
      gateway.seed(200);
      gateway.ready = true;
      gateway.descriptions['usrPeer'] = {'seq': 200, 'read': 200};
      final cubit = ChatCubit(repo);
      await cubit.open('usrPeer');
      final originalIds = cubit.state.messages.map((m) => m.id).toList();
      cubit.setFollowingLive(false);
      final arrived = cubit.stream.firstWhere(
        (state) => state.unreadCount == 150,
      );
      for (var seq = 201; seq <= 350; seq++) {
        final row = <String, dynamic>{
          'topic': 'usrPeer',
          'seq': seq,
          'from': 'peer',
          'ts': DateTime(
            2026,
          ).add(Duration(seconds: seq)).toUtc().toIso8601String(),
          'content': 'live $seq',
        };
        gateway.rows.add(row);
        gateway.controller.add(TinodeEvent('data', row));
      }
      await arrived.timeout(const Duration(seconds: 10));
      expect(cubit.state.messages.map((m) => m.id), originalIds);
      expect(cubit.state.hasNewer, isTrue);
      expect(cubit.state.messages.length, lessThanOrEqualTo(120));
      await cubit.jumpToLatest();
      expect(WindowPolicy.newest(cubit.state.messages), 350);
      await cubit.close();
    },
  );
}
