import 'dart:async';
import 'dart:typed_data';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
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

  test('receipt reload orders late ACK before later server messages', () async {
    await repo.send('usrPeer', {'txt': 'accepted before the peer reply'});
    final queued = (await repo.loadLatest('usrPeer')).single;
    ChatMessage message(String id, int seq, String sender) => ChatMessage(
      id: id,
      topicId: 'usrPeer',
      seq: seq,
      localSeq: 0,
      senderId: sender,
      createdAt: DateTime.utc(2026),
      content: {'txt': id},
    );
    final reply = await db.mergeMessage(
      'local|me',
      message('peer-reply', 2, 'peer'),
      'me',
    );
    final previous = [reply, queued];
    await db.mergeMessage('local|me', message(queued.id, 1, 'me'), 'me');
    final reloaded = await repo.reloadWindow('usrPeer', previous);
    expect(reloaded.map((message) => message.seq), [1, 2]);
    expect(reloaded.first.id, queued.id);
    expect(reloaded.first.localSeq, queued.localSeq);
  });

  test(
    'retry keeps completed upload refs and sends unfinished bytes once',
    () async {
      await repo.send(
        'usrPeer',
        {
          'txt': 'both attachments',
          'ent': List.generate(
            2,
            (_) => {
              'tp': 'EX',
              'data': {'ref': ''},
            },
          ),
        },
        uploads: List.generate(
          2,
          (index) => PendingUpload(
            entityIndex: index,
            bytes: Uint8List.fromList([index + 1]),
            name: 'file-$index.bin',
            mime: 'application/octet-stream',
          ),
        ),
      );
      final id = (await db.pendingOutbox('local|me')).single.clientId;
      gateway.uploadHook = (call) async {
        if (call == 2) {
          gateway.ready = false;
          throw const TinodeException(0, 'Network interrupted');
        }
        return '/v0/file/s/upload-$call';
      };
      gateway.ready = true;
      await repo.flushOutbox();
      final uploads = await db.uploads('local|me', id);
      expect(uploads.where((upload) => upload.remoteRef != null), hasLength(1));
      expect(
        uploads.map((upload) => upload.bytes.single),
        unorderedEquals([1, 2]),
      );
      expect(
        (await db.messageById('local|me', id))!.delivery,
        Delivery.queued.index,
      );
      gateway.ready = true;
      await repo.retry(id);
      expect(gateway.uploads, 3);
      expect(gateway.publishes, 1);
      expect(
        gateway.lastHead!['attachments'],
        unorderedEquals(['/v0/file/s/upload-1', '/v0/file/s/upload-3']),
      );
      expect(await db.pendingOutbox('local|me'), isEmpty);
    },
  );

  test(
    'cancellation during upload prevents publishing and preserves hidden state',
    () async {
      final started = Completer<void>();
      final release = Completer<String>();
      gateway.uploadHook = (_) {
        started.complete();
        return release.future;
      };
      await repo.send(
        'usrPeer',
        {
          'ent': [
            {
              'tp': 'EX',
              'data': {'ref': ''},
            },
          ],
        },
        uploads: [
          PendingUpload(
            entityIndex: 0,
            bytes: Uint8List.fromList([1]),
            name: 'file.bin',
            mime: 'application/octet-stream',
          ),
        ],
      );
      final pending = (await repo.loadLatest('usrPeer')).single;
      gateway.ready = true;
      final flush = repo.flushOutbox();
      await started.future.timeout(const Duration(seconds: 5));
      await repo.deleteMessage(pending);
      release.complete('/v0/file/s/cancelled');
      await flush;
      expect(gateway.publishes, 0);
      expect(await db.pendingOutbox('local|me'), isEmpty);
      expect(await db.uploads('local|me', pending.id), isEmpty);
      expect((await db.messageById('local|me', pending.id))!.hidden, isTrue);
    },
  );

  test('cancellation after server acceptance survives a late ACK', () async {
    final accepted = Completer<void>();
    final releaseAck = Completer<void>();
    gateway.afterPublish = (_) {
      accepted.complete();
      return releaseAck.future;
    };
    await repo.send('usrPeer', {'txt': 'cancel before ACK'});
    final pending = (await repo.loadLatest('usrPeer')).single;
    gateway.ready = true;
    final flush = repo.flushOutbox();
    await accepted.future.timeout(const Duration(seconds: 5));
    await repo.deleteMessage(pending);
    releaseAck.complete();
    await flush;
    expect(gateway.rows, hasLength(1));
    expect(await db.pendingOutbox('local|me'), isEmpty);
    expect(await db.page('local|me', 'usrPeer'), isEmpty);
    final merged = (await db.messageById('local|me', pending.id))!;
    expect(merged.seq, 1);
    expect(merged.hidden, isTrue);
  });

  test(
    'offline queue keeps enqueue order through a paused first publish',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      gateway.beforePublish = (call) async {
        if (call == 1) {
          started.complete();
          await release.future;
        }
      };
      await repo.send('usrPeer', {'txt': 'first'});
      await repo.send('usrPeer', {'txt': 'second'});
      expect(gateway.publishes, 0);
      gateway.ready = true;
      final flush = repo.flushOutbox();
      await started.future.timeout(const Duration(seconds: 5));
      expect(gateway.publishes, 1);
      expect(gateway.rows, isEmpty);
      release.complete();
      await flush;
      expect(gateway.rows.map((row) => (row['content'] as Map)['txt']), [
        'first',
        'second',
      ]);
      expect(await db.pendingOutbox('local|me'), isEmpty);
    },
  );
}
