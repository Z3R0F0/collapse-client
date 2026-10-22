import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:collapse/src/domain/chat/history_models.dart';
import 'package:collapse/src/presentation/chat/chat_cubit.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/window_race_fixture.dart';

class _SearchNavigationRepository extends PausedWindowRepository {
  _SearchNavigationRepository(super.database, super.gateway);
  ReadGate<HistoryWindow?>? aroundGate;

  @override
  Future<HistoryWindow?> openHistory(
    String topicId, {
    int? aroundSeq,
    String? aroundId,
    int limit = 40,
  }) async {
    final gate = aroundGate;
    aroundGate = null;
    final rows = await super.openHistory(
      topicId,
      aroundSeq: aroundSeq,
      aroundId: aroundId,
      limit: limit,
    );
    return gate == null ? rows : gate.pause(rows);
  }
}

void main() {
  const scope = 'local|me', topic = 'usrPeer';
  late AppDatabase database;
  late FakeGateway gateway;
  late _SearchNavigationRepository repository;
  late ChatCubit cubit;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = FakeGateway();
    repository = _SearchNavigationRepository(database, gateway);
    await repository.start('me');
    cubit = ChatCubit(repository);
  });

  tearDown(() async {
    await cubit.close();
    await repository.dispose();
    await gateway.dispose();
    await database.close();
  });

  for (final deletedTarget in [false, true]) {
    test(
      '${deletedTarget ? 'deleted' : 'missing'} search hit retains and freshens the current window quietly',
      () async {
        gateway.seed(80);
        gateway.ready = true;
        await repository.loadAround(topic, 5);
        final oldTarget = (await repository.getMessage(topic, 5))!;
        if (deletedTarget) {
          await database.applyDeletions(scope, topic, [
            {'low': 5},
          ], 0);
        }
        await cubit.open(topic);
        if (cubit.state.messages.lastOrNull?.seq != 80) {
          // A cached island opens immediately. Establish the completed latest
          // baseline before testing the independent failed-target navigation.
          await cubit.stream
              .firstWhere((state) => state.messages.lastOrNull?.seq == 80)
              .timeout(const Duration(seconds: 3));
        }
        final before = cubit.state;
        expect(before.messages, hasLength(40));
        expect(before.messages.any((m) => m.id == oldTarget.id), isFalse);
        final states = <ChatState>[];
        final subscription = cubit.stream.listen(states.add);
        addTearDown(subscription.cancel);
        final gate = repository.aroundGate = ReadGate<HistoryWindow?>();
        addTearDown(() {
          if (!gate.release.isCompleted) gate.release.complete();
        });
        final opened = cubit.open(
          topic,
          aroundId: deletedTarget ? oldTarget.id : 'no-such-client-id',
        );
        expect(
          await gate.captured.future.timeout(const Duration(seconds: 2)),
          isNull,
        );
        expect(cubit.state.loading, isTrue);
        expect(cubit.state.messages, before.messages);

        // Persist a deletion without a repository event: failed navigation must
        // rehydrate retained IDs rather than restore its stale state snapshot.
        final removed = before.messages.first;
        await database.applyDeletions(scope, topic, [
          {'low': removed.seq},
        ], 0);
        gate.release.complete();
        await opened;
        expect(
          cubit.state.messages.map((m) => m.id),
          before.messages.skip(1).map((m) => m.id),
        );
        expect(cubit.state.loading, isFalse);
        expect(cubit.state.error, isNull);
        expect(cubit.state.hasOlder, before.hasOlder);
        expect(cubit.state.hasNewer, before.hasNewer);
        expect(cubit.state.atLiveEdge, before.atLiveEdge);
        expect(cubit.state.unreadCount, before.unreadCount);
        expect(states.every((s) => s.messages.isNotEmpty), isTrue);
        expect(states.every((s) => s.arrivalIds.isEmpty), isTrue);
        expect(gateway.notes.where((n) => n.what == 'read'), isEmpty);
      },
    );
  }

  test(
    'search target outside 120 rows survives ACK during stable-ID navigation',
    () async {
      for (var i = 1; i <= 165; i++) {
        await repository.send(topic, 'queued $i');
      }
      final target = (await database.pendingMessages(
        scope,
        topic,
        limit: 200,
      )).singleWhere((m) => m.text == 'queued 10');
      await cubit.open(topic);
      await cubit.loadOlder();
      await cubit.loadOlder();
      expect(cubit.state.messages, hasLength(120));
      expect(cubit.state.messages.any((m) => m.id == target.id), isFalse);
      final states = <ChatState>[];
      final subscription = cubit.stream.listen(states.add);
      addTearDown(subscription.cancel);
      final gate = repository.aroundGate = ReadGate<HistoryWindow?>();
      addTearDown(() {
        if (!gate.release.isCompleted) gate.release.complete();
      });
      final opened = cubit.open(topic, aroundId: target.id);
      await gate.captured.future.timeout(const Duration(seconds: 2));
      gateway.ready = true;
      await repository.flushOutbox();
      gate.release.complete();
      await opened;
      final found = cubit.state.messages.singleWhere((m) => m.id == target.id);
      expect(found.seq, 10);
      expect(found.delivery, Delivery.sent);
      expect(found.text, 'queued 10');
      expect(cubit.state.messages.length, lessThanOrEqualTo(40));
      expect(cubit.state.hasNewer, isTrue);
      expect(cubit.state.atLiveEdge, isFalse);
      expect(states.every((s) => s.arrivalIds.isEmpty), isTrue);
      expect(await database.pendingOutbox(scope), isEmpty);
      expect(gateway.notes.where((n) => n.what == 'read'), isEmpty);
    },
  );
}
