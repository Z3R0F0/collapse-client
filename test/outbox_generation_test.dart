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

  Future<void> restartSameAccount() async {
    gateway.ready = false;
    await repo.stop();
    await repo.start('me');
    gateway.ready = true;
  }

  test(
    'old upload cannot publish after the same account starts a new session',
    () async {
      final started = [Completer<void>(), Completer<void>()];
      final uploads = [Completer<String>(), Completer<String>()];
      gateway.uploadHook = (call) {
        started[call - 1].complete();
        return uploads[call - 1].future;
      };
      await repo.send(
        'usrPeer',
        {
          'ent': [
            {
              'tp': 'IM',
              'data': {'ref': ''},
            },
          ],
        },
        uploads: [
          PendingUpload(
            entityIndex: 0,
            bytes: Uint8List.fromList([1, 2, 3]),
            name: 'photo.png',
            mime: 'image/png',
          ),
        ],
      );
      gateway.ready = true;
      final oldFlush = repo.flushOutbox();
      await started[0].future.timeout(const Duration(seconds: 5));
      await restartSameAccount();
      final currentFlush = repo.flushOutbox();
      await started[1].future.timeout(const Duration(seconds: 5));
      uploads[0].complete('/v0/file/s/old-session');
      await oldFlush;
      try {
        expect(gateway.publishes, 0);
        expect(
          (await db.uploads(
            'local|me',
            (await db.pendingOutbox('local|me')).single.clientId,
          )).single.remoteRef,
          isNull,
        );
      } finally {
        uploads[1].complete('/v0/file/s/current-session');
        await currentFlush;
      }
      expect(gateway.publishes, 1);
      expect(gateway.lastHead!['attachments'], ['/v0/file/s/current-session']);
      expect(await db.pendingOutbox('local|me'), isEmpty);
    },
  );

  test(
    'old failed publish cannot overwrite the replacement session attempt',
    () async {
      final started = [Completer<void>(), Completer<void>()];
      final releases = [Completer<void>(), Completer<void>()];
      gateway.beforePublish = (call) async {
        started[call - 1].complete();
        await releases[call - 1].future;
        if (call == 1) throw const TinodeException(0, 'Old connection closed');
      };
      await repo.send('usrPeer', {'txt': 'one message'});
      final id = (await db.pendingOutbox('local|me')).single.clientId;
      gateway.ready = true;
      final oldFlush = repo.flushOutbox();
      await started[0].future.timeout(const Duration(seconds: 5));
      await restartSameAccount();
      final currentFlush = repo.flushOutbox();
      await started[1].future.timeout(const Duration(seconds: 5));
      releases[0].complete();
      await oldFlush;
      try {
        expect(
          (await db.messageById('local|me', id))!.delivery,
          Delivery.sending.index,
        );
        final pending = (await db.pendingOutbox('local|me')).single;
        expect(pending.attempts, 0);
        expect(pending.nextRetryAt, 0);
      } finally {
        releases[1].complete();
        await currentFlush;
      }
      expect(gateway.rows, hasLength(1));
      expect(await db.pendingOutbox('local|me'), isEmpty);
    },
  );

  test(
    'late ACK merges its original account without notifying a new account',
    () async {
      final accepted = Completer<void>();
      final releaseAck = Completer<void>();
      gateway.afterPublish = (_) {
        accepted.complete();
        return releaseAck.future;
      };
      await repo.send('usrPeer', {'txt': 'accepted before logout'});
      final id = (await db.pendingOutbox('local|me')).single.clientId;
      gateway.ready = true;
      final flush = repo.flushOutbox();
      await accepted.future.timeout(const Duration(seconds: 5));
      gateway.ready = false;
      await repo.stop();
      gateway.userId = 'other';
      await repo.start('other');
      final changes = <ChatChange>[];
      final subscription = repo.changesFor('usrPeer').listen(changes.add);
      releaseAck.complete();
      await flush;
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(changes, isEmpty);
      expect(await db.pendingOutbox('local|me'), isEmpty);
      expect((await db.messageById('local|me', id))!.seq, 1);
      expect(await db.page('local|other', 'usrPeer'), isEmpty);
      expect(await db.pendingOutbox('local|other'), isEmpty);
    },
  );
}
