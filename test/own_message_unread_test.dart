import 'dart:async';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:collapse_tinode/collapse_tinode.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class _HeldCountDatabase extends AppDatabase {
  _HeldCountDatabase() : super.forTesting(NativeDatabase.memory());
  bool hold = false;
  final captured = Completer<void>(), release = Completer<void>();

  @override
  Future<int> countIncomingAfter(
    String scope,
    String id,
    String userId,
    int afterSeq,
  ) async {
    final result = await super.countIncomingAfter(scope, id, userId, afterSeq);
    if (hold) {
      hold = false;
      captured.complete();
      await release.future;
    }
    return result;
  }
}

ChatMessage _message(int seq, {String sender = 'me', String? id}) =>
    ChatMessage(
      id: id ?? 'message:$seq',
      topicId: 'usrPeer',
      seq: seq,
      localSeq: 0,
      senderId: sender,
      createdAt: DateTime.utc(2026),
      content: 'message $seq',
    );

void main() {
  late AppDatabase db;
  late FakeGateway gateway;
  late ChatsRepository repo;
  setUp(() async {
    db = _HeldCountDatabase();
    gateway = FakeGateway();
    repo = ChatsRepository(database: db, gateway: gateway, serverId: 'local');
    await repo.start('me');
    await db.mergeTopic('local|me', 'usrPeer', const {});
  });
  tearDown(() async {
    await repo.dispose();
    await gateway.dispose();
    await db.close();
  });

  test(
    'rapid own ACKs and echoes do not create unread or read receipts',
    () async {
      for (var i = 0; i < 6; i++) {
        await repo.send('usrPeer', 'own $i');
      }
      expect((await repo.getTopic('usrPeer'))!.unreadCount, 0);
      gateway.ready = true;
      await repo.flushOutbox();
      expect((await repo.getTopic('usrPeer'))!.unreadCount, 0);
      expect((await repo.getTopic('usrPeer'))!.readSeq, 0);
      final drained = repo.changesFor('usrPeer').firstWhere((e) => e.reset);
      for (final row in gateway.rows.reversed) {
        gateway.controller.add(TinodeEvent('data', row));
        gateway.controller.add(
          TinodeEvent('pres', {
            'topic': 'me',
            'src': 'usrPeer',
            'what': 'msg',
            'seq': row['seq'],
          }),
        );
      }
      await drained.timeout(const Duration(seconds: 3));
      expect((await repo.watchTopic('usrPeer').first)!.unreadCount, 0);
      expect((await repo.watchTopics().first).single.unreadCount, 0);
      expect(gateway.notes.where((n) => n.what == 'read'), isEmpty);
    },
  );

  test(
    'own ACK keeps older incoming unread; server read is still cumulative',
    () async {
      gateway.seed(2);
      for (var seq = 1; seq <= 2; seq++) {
        await db.mergeMessage('local|me', _message(seq, sender: 'peer'), 'me');
      }
      await repo.send('usrPeer', 'reply without reading');
      gateway.ready = true;
      await repo.flushOutbox();
      expect((await repo.getTopic('usrPeer'))!.unreadCount, 2);
      expect((await repo.getTopic('usrPeer'))!.readSeq, 0);
      expect(gateway.notes.where((n) => n.what == 'read'), isEmpty);
      await db.receipts('local|me', 'usrPeer', 'me', read: 1);
      expect((await repo.getTopic('usrPeer'))!.unreadCount, 1);
      final seen = repo
          .watchTopic('usrPeer')
          .firstWhere((t) => t?.readSeq == 3);
      gateway.controller.add(
        const TinodeEvent('pres', {
          'topic': 'me',
          'src': 'usrPeer',
          'what': 'read',
          'seq': 3,
        }),
      );
      expect((await seen.timeout(const Duration(seconds: 3)))!.unreadCount, 0);
    },
  );

  test(
    'unknown holes stay unread while late own bodies update both watches',
    () async {
      await db.mergeTopic('local|me', 'usrPeer', {'seq': 4, 'read': 1});
      expect((await repo.getTopic('usrPeer'))!.unreadCount, 3);
      final topicCounts = <int>[], listCounts = <int>[];
      final topicWatch = repo
          .watchTopic('usrPeer')
          .listen((t) => topicCounts.add(t!.unreadCount));
      final listWatch = repo.watchTopics().listen(
        (ts) => listCounts.add(ts.single.unreadCount),
      );
      addTearDown(topicWatch.cancel);
      addTearDown(listWatch.cancel);
      await db.mergeMessage('local|me', _message(4), 'me');
      expect((await repo.watchTopic('usrPeer').first)!.unreadCount, 2);
      expect((await repo.watchTopics().first).single.unreadCount, 2);
      await db.hide('local|me', 'usrPeer', 4);
      await db.applyDeletions('local|me', 'usrPeer', [
        {'low': 4},
      ], 1);
      expect((await repo.getTopic('usrPeer'))!.unreadCount, 2);
      expect((await db.topicRow('local|me', 'usrPeer'))!.readSeq, 1);
      await Future<void>.delayed(Duration.zero);
      expect(topicCounts, contains(2));
      expect(listCounts, contains(2));
    },
  );

  test(
    'same topic on another account does not borrow own exclusions',
    () async {
      await db.mergeMessage('local|me', _message(1), 'me');
      await repo.stop();
      gateway.userId = 'other';
      await repo.start('other');
      await db.mergeTopic('local|other', 'usrPeer', {'seq': 1});
      await db.mergeMessage('local|other', _message(1), 'other');
      expect((await repo.getTopic('usrPeer'))!.unreadCount, 1);
      await repo.stop();
      gateway.userId = 'me';
      await repo.start('me');
      expect((await repo.getTopic('usrPeer'))!.unreadCount, 0);
    },
  );

  test(
    'incoming range count excludes own, not unknown gaps or incoming',
    () async {
      await db.mergeTopic('local|me', 'usrPeer', {'seq': 7, 'read': 6});
      await db.mergeMessage('local|me', _message(3), 'me');
      await db.mergeMessage('local|me', _message(5, sender: 'peer'), 'me');
      await db.mergeMessage('local|me', _message(7), 'me');
      await repo.send('usrPeer', 'still pending');
      expect(await repo.countIncomingAfter('usrPeer', 2), 3);
      expect(await repo.countIncomingAfter('usrPeer', 5), 1);
      expect(await repo.countIncomingAfter('usrPeer', 6), 0);
      expect(await repo.countIncomingAfter('usrPeer', 100), 0);
      expect(await repo.countIncomingAfter('missing', 0), 0);
      expect((await repo.getTopic('usrPeer'))!.unreadCount, 0);
    },
  );

  test(
    'echo before ACK counts own sequence once without reading incoming',
    () async {
      gateway.seed(1);
      await db.mergeMessage('local|me', _message(1, sender: 'peer'), 'me');
      await repo.send('usrPeer', 'own');
      final id = (await db.pendingOutbox('local|me')).single.clientId;
      gateway.afterPublish = (_) async {
        final echoStored = repo
            .changesFor('usrPeer')
            .firstWhere((e) => e.message?.id == id && e.message?.seq == 2);
        gateway.controller.add(TinodeEvent('data', gateway.rows.last));
        await echoStored.timeout(const Duration(seconds: 3));
        expect((await repo.getTopic('usrPeer'))!.unreadCount, 1);
      };
      gateway.ready = true;
      await repo.flushOutbox();
      expect((await repo.getTopic('usrPeer'))!.unreadCount, 1);
      expect(await repo.countIncomingAfter('usrPeer', 1), 0);
      expect((await db.messageById('local|me', id))!.seq, 2);
      expect(await db.page('local|me', 'usrPeer'), hasLength(2));
      expect(gateway.notes.where((n) => n.what == 'read'), isEmpty);
    },
  );

  for (final sameAccount in [false, true]) {
    test(
      'held count does not cross ${sameAccount ? 'same-account generation' : 'account'}',
      () async {
        await db.mergeTopic('local|me', 'usrPeer', {'seq': 4});
        final held = db as _HeldCountDatabase;
        held.hold = true;
        final oldCount = repo.countIncomingAfter('usrPeer', 0);
        await held.captured.future.timeout(const Duration(seconds: 3));
        await repo.stop();
        gateway.userId = sameAccount ? 'me' : 'other';
        await repo.start(gateway.userId!);
        held.release.complete();
        expect(await oldCount, 0);
        expect(
          await repo.countIncomingAfter('usrPeer', 0),
          sameAccount ? 4 : 0,
        );
      },
    );
  }
}
