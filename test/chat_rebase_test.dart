import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/presentation/chat/chat_cubit.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/window_race_fixture.dart';

void main() {
  for (final moved in [false, true]) {
    test(
      'ACK rebase ${moved ? 'rejects a moved' : 'retains the painted'} anchor',
      () async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final gateway = FakeGateway();
        final repository = PausedWindowRepository(database, gateway);
        final cubit = ChatCubit(repository);
        addTearDown(() async {
          await cubit.close();
          await repository.dispose();
          await gateway.dispose();
          await database.close();
        });
        await repository.start('me');
        for (var i = 1; i <= 165; i++) {
          await repository.send('usrPeer', 'queued $i');
        }
        await cubit.open('usrPeer');
        cubit.setFollowingLive(false);
        final acknowledged = cubit.stream.firstWhere(
          (state) =>
              state.messages.length == 40 &&
              state.messages.every((message) => message.seq > 0),
        );
        gateway.ready = true;
        await repository.flushOutbox();
        await acknowledged.timeout(const Duration(seconds: 3));
        final before = cubit.state;
        final anchor = before.messages.singleWhere((m) => m.seq == 130).id;
        final neighbor = before.messages.singleWhere((m) => m.seq == 131).id;
        cubit.setVisibleMessages({anchor, neighbor});
        final requestCount = gateway.requests.length;
        final gate = repository.olderGate = ReadGate<HistoryWindow?>();
        final loaded = cubit.loadOlder();
        final proposed = (await gate.captured.future.timeout(
          const Duration(seconds: 3),
        ))!;
        expect(proposed.rebaseAnchorId, anchor);
        expect(proposed.messages.any((m) => m.id == anchor), isTrue);
        if (moved) cubit.setVisibleMessages({neighbor});
        gate.release.complete();
        await loaded;
        expect(cubit.state.navigationEpoch, before.navigationEpoch);
        expect(cubit.state.loadingOlder, isFalse);
        expect(cubit.state.arrivalIds, isEmpty);
        expect(
          gateway.requests.length,
          requestCount,
          reason: 'ACK order normalization is cache-only',
        );
        if (moved) {
          expect(cubit.state.window!.span, before.window!.span);
          expect(cubit.state.messages, before.messages);
        } else {
          expect(cubit.state.window!.span.local, isNull);
          expect(cubit.state.messages.any((m) => m.id == anchor), isTrue);
          expect(cubit.state.messages.length, lessThanOrEqualTo(120));
        }
      },
    );
  }
}
