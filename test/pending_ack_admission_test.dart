import 'dart:async';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/presentation/chat/chat_cubit.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  for (final following in [true, false]) {
    test(
      'evicted ACK is older than a pure pending tail (following=$following)',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final gateway = FakeGateway();
        final repo = ChatsRepository(
          database: db,
          gateway: gateway,
          serverId: 'local',
        );
        final cubit = ChatCubit(repo);
        final paused = Completer<void>(), release = Completer<void>();
        Future<void>? flush;
        try {
          await repo.start('me');
          for (var i = 1; i <= 165; i++) {
            await repo.send('usrPeer', 'queued $i');
          }
          await cubit.open('usrPeer');
          cubit.setFollowingLive(following);
          final ids = cubit.state.messages.map((m) => m.id).toList();
          expect(cubit.state.messages.first.text, 'queued 126');
          expect(cubit.state.atLiveEdge, isTrue);
          final states = <ChatState>[];
          final events = cubit.stream.listen(states.add);
          gateway.beforePublish = (call) async {
            if (call == 2) {
              paused.complete();
              await release.future;
            }
          };
          gateway.ready = true;
          flush = repo.flushOutbox();
          await paused.future.timeout(const Duration(seconds: 3));
          // Await the second attempt's reset: it is serialized after ACK1.
          await pumpEventQueue();
          expect(
            cubit.state.messages.map((m) => m.id),
            ids,
            reason:
                'ACK1 sorts before retained pending126, not after pending165',
          );
          expect(cubit.state.hasNewer, isFalse);
          expect(cubit.state.atLiveEdge, isTrue);
          expect(cubit.state.unreadCount, 0);
          expect(states.every((state) => state.arrivalIds.isEmpty), isTrue);
          await cubit.loadOlder();
          expect(
            cubit.state.messages.first.text,
            'queued 86',
            reason: 'older paging must remain on the pending localSeq cursor',
          );
          expect(await db.pendingOutbox('local|me'), hasLength(164));
          await events.cancel();
        } finally {
          if (!release.isCompleted) release.complete();
          await flush;
          await cubit.close();
          await repo.dispose();
          await gateway.dispose();
          await db.close();
        }
      },
    );
  }

  test(
    'retained pending ACK updates its ID without a gap or entry effect',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final gateway = FakeGateway();
      final repo = ChatsRepository(
        database: db,
        gateway: gateway,
        serverId: 'local',
      );
      final cubit = ChatCubit(repo);
      try {
        await repo.start('me');
        for (var i = 1; i <= 4; i++) {
          await repo.send('usrPeer', 'queued $i');
        }
        await cubit.open('usrPeer');
        cubit.setFollowingLive(false);
        final ids = cubit.state.messages.map((m) => m.id).toList();
        final states = <ChatState>[];
        final events = cubit.stream.listen(states.add);
        gateway.ready = true;
        await repo.flushOutbox();
        await pumpEventQueue();
        expect(cubit.state.messages.map((m) => m.id), ids);
        expect(cubit.state.messages.map((m) => m.seq), [1, 2, 3, 4]);
        expect(cubit.state.atLiveEdge, isTrue);
        expect(cubit.state.hasNewer, isFalse);
        expect(states.every((state) => state.arrivalIds.isEmpty), isTrue);
        await events.cancel();
      } finally {
        await cubit.close();
        await repo.dispose();
        await gateway.dispose();
        await db.close();
      }
    },
  );
}
