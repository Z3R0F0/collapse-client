import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/presentation/chat/chat_cubit.dart';
import 'package:collapse/src/presentation/chat/window_policy.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  test(
    'evicted offline message sends without displacing the history window',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final gateway = FakeGateway()..seed(500);
      gateway.descriptions['usrPeer'] = {'seq': 500, 'read': 500};
      final repo = ChatsRepository(
        database: db,
        gateway: gateway,
        serverId: 'local',
      );
      final cubit = ChatCubit(repo);
      try {
        await repo.start('me');
        gateway.ready = true;
        await cubit.open('usrPeer');
        for (var page = 0; page < 4; page++) {
          await cubit.loadOlder();
        }
        await cubit.jumpToLatest();
        gateway.ready = false;
        final queuedState = cubit.stream.firstWhere(
          (state) => state.messages.any((message) => message.pending),
        );
        await cubit.send({'txt': 'queued outside the window'});
        final queued = (await queuedState).messages.last;
        for (var page = 0; page < 3; page++) {
          await cubit.loadOlder();
        }
        expect(cubit.state.messages, hasLength(WindowPolicy.capacity));
        final historyIds = cubit.state.messages.map((m) => m.id).toList();
        expect(historyIds, isNot(contains(queued.id)));
        expect(await db.pendingOutbox('local|me'), hasLength(1));
        expect(
          (await db.messageById('local|me', queued.id))?.localSeq,
          queued.localSeq,
        );

        final acknowledged = cubit.stream.firstWhere(
          // Read history and the own ACK at 501 are not unread incoming.
          (state) => state.unreadCount == 0,
        );
        gateway.ready = true;
        await repo.start('me');
        await repo.flushOutbox();
        await acknowledged.timeout(const Duration(seconds: 3));
        expect(cubit.state.messages.map((m) => m.id), historyIds);
        expect(cubit.state.atLiveEdge, isFalse);
        expect(gateway.publishes, 1);
        expect(await db.pendingOutbox('local|me'), isEmpty);
        final stored = (await db.messageById('local|me', queued.id))!;
        expect(stored.seq, 501);
        expect(stored.localSeq, queued.localSeq);

        await cubit.jumpToLatest();
        expect(cubit.state.messages.last.id, queued.id);
        expect(cubit.state.messages.last.pending, isFalse);
        expect(
          cubit.state.messages.where((m) => m.id == queued.id),
          hasLength(1),
        );
      } finally {
        await cubit.close();
        await repo.dispose();
        await gateway.dispose();
        await db.close();
      }
    },
  );
}
