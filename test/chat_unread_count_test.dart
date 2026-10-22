import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:collapse/src/presentation/chat/chat_cubit.dart';
import 'package:collapse_tinode/collapse_tinode.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/window_race_fixture.dart';

void main() {
  late AppDatabase db;
  late FakeGateway gateway;
  late PausedWindowRepository repo;
  late ChatCubit chat;

  Future<void> seed(String topic, int count, int read) async {
    await db.mergeTopic('local|me', topic, {'seq': count, 'read': read});
    await db.batch(
      (batch) => batch.insertAll(db.messages, [
        for (var seq = 1; seq <= count; seq++)
          MessagesCompanion.insert(
            scope: 'local|me',
            topicId: topic,
            seq: seq,
            clientId: '$topic:$seq',
            senderId: 'peer',
            createdAtMs: seq,
            content: '"cached message"',
          ),
      ]),
    );
    await db.recordCoverage('local|me', topic, 1, count + 1);
  }

  Future<void> expectUnread(int count) async {
    if (chat.state.unreadCount != count) {
      await chat.stream
          .firstWhere((s) => s.unreadCount == count)
          .timeout(const Duration(seconds: 2));
    }
    expect(chat.state.unreadCount, count);
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = FakeGateway();
    repo = PausedWindowRepository(db, gateway);
    await repo.start('me');
    await seed('usrPeer', 200, 197);
    chat = ChatCubit(repo);
  });
  tearDown(() async {
    await chat.close();
    await repo.dispose();
    await gateway.dispose();
    await db.close();
  });

  test(
    'scrolling into read history never turns old rows into new messages',
    () async {
      await db.receipts('local|me', 'usrPeer', 'me', read: 200);
      await chat.open('usrPeer');
      chat.setFollowingLive(false);
      for (var i = 0; i < 3; i++) {
        await chat.loadOlder();
      }
      expect(chat.state.atLiveEdge, isFalse);
      final changed = chat.stream.first;
      gateway.controller.add(
        const TinodeEvent('info', {
          'topic': 'usrPeer',
          'from': 'peer',
          'what': 'recv',
          'seq': 200,
        }),
      );
      await changed.timeout(const Duration(seconds: 2));
      expect((await repo.getTopic('usrPeer'))!.unreadCount, 0);
      expect(chat.state.unreadCount, 0);
    },
  );

  test(
    'history open, both page directions and latest keep the Home unread',
    () async {
      expect((await repo.getTopic('usrPeer'))!.unreadCount, 3);
      await chat.open('usrPeer', aroundSeq: 100);
      expect(chat.state.unreadCount, 3);
      final firstSpan = chat.state.window!.span;
      await chat.loadOlder();
      expect(chat.state.window!.span, isNot(firstSpan));
      expect(chat.state.unreadCount, 3);
      await chat.loadNewer();
      expect(chat.state.unreadCount, 3);
      await chat.jumpToLatest();
      expect(chat.state.atLiveEdge, isTrue);
      expect(chat.state.unreadCount, 3);
      expect(gateway.notes.where((n) => n.what == 'read'), isEmpty);
    },
  );

  test(
    'visible read and me read presence update count without ChatChange',
    () async {
      await chat.open('usrPeer');
      await expectUnread(3);
      final changes = <ChatChange>[];
      final subscription = repo.changesFor('usrPeer').listen(changes.add);
      addTearDown(subscription.cancel);
      await chat.markVisible(198);
      await expectUnread(2);
      gateway.controller.add(
        const TinodeEvent('pres', {
          'topic': 'me',
          'src': 'usrPeer',
          'what': 'read',
          'seq': 200,
        }),
      );
      await expectUnread(0);
      expect(changes, isEmpty);
      expect((await repo.watchTopics().first).single.unreadCount, 0);
    },
  );

  test(
    'history count grows for peer arrival, not own ACK or duplicate echo',
    () async {
      await chat.open('usrPeer', aroundSeq: 1);
      await expectUnread(3);
      gateway.controller.add(
        const TinodeEvent('data', {
          'topic': 'usrPeer',
          'seq': 201,
          'from': 'peer',
          'content': 'incoming',
        }),
      );
      await expectUnread(4);
      await repo.send('usrPeer', 'own queued');
      final queued = (await db.pendingOutbox('local|me')).single;
      final own = <String, dynamic>{
        'topic': 'usrPeer',
        'seq': 202,
        'from': 'me',
        'content': 'own queued',
        'head': {'x-client-id': queued.clientId},
      };
      final stored = repo
          .changesFor('usrPeer')
          .firstWhere((e) => e.message?.seq == 202);
      gateway.controller.add(TinodeEvent('data', own));
      await stored.timeout(const Duration(seconds: 2));
      final drained = repo.changesFor('usrPeer').firstWhere((e) => e.reset);
      gateway.controller.add(TinodeEvent('data', own));
      gateway.controller.add(
        const TinodeEvent('pres', {
          'topic': 'me',
          'src': 'usrPeer',
          'what': 'msg',
          'seq': 202,
        }),
      );
      await drained.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);
      expect(chat.state.unreadCount, 4);
      expect((await repo.getTopic('usrPeer'))!.unreadCount, 4);
      expect(chat.state.messages.last.seq, 40);
    },
  );

  test(
    'read update during held navigation survives the ready snapshot',
    () async {
      await chat.open('usrPeer');
      await expectUnread(3);
      final gate = ReadGate<HistoryWindow?>();
      repo.openGate = gate;
      final opening = chat.open('usrPeer', aroundSeq: 100);
      await gate.captured.future.timeout(const Duration(seconds: 2));
      try {
        await db.receipts('local|me', 'usrPeer', 'me', read: 200);
        await expectUnread(0);
        expect(chat.state.loading, isTrue);
      } finally {
        gate.release.complete();
        await opening;
      }
      expect(chat.state.loading, isFalse);
      expect(chat.state.unreadCount, 0);
    },
  );

  test(
    'old topic watcher and late open cannot overwrite the new topic count',
    () async {
      await chat.open('usrPeer');
      await expectUnread(3);
      await seed('usrOther', 10, 8);
      final gate = ReadGate<HistoryWindow?>();
      repo.openGate = gate;
      final oldOpen = chat.open('usrPeer', aroundSeq: 100);
      await gate.captured.future.timeout(const Duration(seconds: 2));
      try {
        await chat.open('usrOther');
        await expectUnread(2);
        await db.receipts('local|me', 'usrPeer', 'me', read: 200);
        await repo.watchTopic('usrPeer').firstWhere((t) => t?.unreadCount == 0);
        await Future<void>.delayed(Duration.zero);
        expect(chat.state.unreadCount, 2);
      } finally {
        gate.release.complete();
        await oldOpen;
      }
      expect(chat.state.messages.every((m) => m.topicId == 'usrOther'), isTrue);
      expect(chat.state.unreadCount, 2);
    },
  );

  test(
    'old same-account session watcher cannot change the retired Cubit',
    () async {
      await chat.open('usrPeer');
      await expectUnread(3);
      await repo.stop();
      await repo.start('me');
      await db.receipts('local|me', 'usrPeer', 'me', read: 200);
      await repo.watchTopic('usrPeer').firstWhere((t) => t?.unreadCount == 0);
      await Future<void>.delayed(Duration.zero);
      expect(chat.state.unreadCount, 3);
      await chat.open('usrPeer');
      await expectUnread(0);
    },
  );
}
