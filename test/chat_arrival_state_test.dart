import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:collapse/src/domain/chat/history_models.dart';
import 'package:collapse/src/presentation/chat/chat_cubit.dart';
import 'package:collapse_tinode/collapse_tinode.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/arrival_gateway.dart';
import 'support/window_race_fixture.dart';

void main() {
  late AppDatabase database;
  late ArrivalGateway gateway;
  late PausedWindowRepository repository;
  late ChatCubit cubit;
  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = ArrivalGateway();
    repository = PausedWindowRepository(database, gateway);
    await repository.start('me');
    cubit = ChatCubit(repository);
  });
  tearDown(() async {
    await cubit.close();
    await repository.dispose();
    await gateway.dispose();
    await database.close();
  });

  test(
    'arrival IDs belong to one emission, not delivery updates or reloads',
    () async {
      await cubit.open('usrPeer');
      final arrival = cubit.stream.firstWhere(
        (state) => state.arrivalIds.isNotEmpty,
      );
      await cubit.send('local');
      final queued = await arrival.timeout(const Duration(seconds: 3));
      final id = queued.messages.single.id;
      expect(queued.arrivalIds, {id});
      expect(
        queued.copyWith(paging: HistoryDirection.older).arrivalIds,
        isEmpty,
      );
      final sent = cubit.stream.firstWhere(
        (state) => state.messages.singleOrNull?.seq == 1,
      );
      gateway.ready = true;
      await repository.flushOutbox();
      expect((await sent).arrivalIds, isEmpty);
      final read = cubit.stream.firstWhere(
        (state) => state.messages.singleOrNull?.delivery == Delivery.read,
      );
      gateway.controller.add(
        const TinodeEvent('info', {
          'topic': 'usrPeer',
          'from': 'peer',
          'what': 'read',
          'seq': 1,
        }),
      );
      expect(
        (await read.timeout(const Duration(seconds: 3))).arrivalIds,
        isEmpty,
      );
      await cubit.open('usrPeer');
      expect(cubit.state.messages.single.id, id);
      expect(cubit.state.arrivalIds, isEmpty);
    },
  );

  test(
    'live event captured during initial load is replayed without entry effect',
    () async {
      final gate = repository.openGate = ReadGate<HistoryWindow?>();
      final opened = cubit.open('usrPeer');
      await gate.captured.future;
      await repository.send('usrPeer', 'arrived while opening');
      await Future<void>.delayed(Duration.zero);
      final replayed = cubit.stream.firstWhere(
        (state) => state.messages.length == 1,
      );
      gate.release.complete();
      await opened;
      expect(
        (await replayed.timeout(const Duration(seconds: 3))).arrivalIds,
        isEmpty,
      );
    },
  );

  test(
    'arrival outside the historical window does not acquire an effect when paged in',
    () async {
      gateway.seed(85);
      gateway.ready = true;
      gateway.descriptions['usrPeer'] = {'seq': 85, 'read': 40};
      await cubit.open('usrPeer', aroundSeq: 1);
      final noticed = cubit.stream.firstWhere(
        (state) => state.unreadCount == 46,
      );
      gateway.rows.add(arrivalPacket(86));
      gateway.controller.add(TinodeEvent('data', gateway.rows.last));
      expect(
        (await noticed.timeout(const Duration(seconds: 3))).arrivalIds,
        isEmpty,
      );
      while (cubit.state.hasNewer) {
        await cubit.loadNewer();
        expect(cubit.state.arrivalIds, isEmpty);
      }
      expect(cubit.state.messages.last.seq, 86);
    },
  );

  test(
    'incremental arrivals stay bounded; eviction and return do not requalify',
    () async {
      await cubit.open('usrPeer');
      final snapshots = <ChatState>[];
      final subscription = cubit.stream.listen(snapshots.add);
      addTearDown(subscription.cancel);
      final filled = cubit.stream.firstWhere(
        (state) => state.messages.lastOrNull?.text == 'local 125',
      );
      for (var i = 1; i <= 125; i++) {
        await repository.send('usrPeer', 'local $i');
      }
      await filled.timeout(const Duration(seconds: 3));
      expect(
        snapshots.where((state) => state.arrivalIds.isNotEmpty),
        hasLength(125),
      );
      expect(
        snapshots.every(
          (state) =>
              state.messages.length <= 120 &&
              state.arrivalIds.length <= 1 &&
              state.arrivalIds.every(
                (id) => state.messages.any((message) => message.id == id),
              ),
        ),
        isTrue,
      );
      await cubit.loadOlder();
      expect(cubit.state.messages.first.text, 'local 1');
      expect(cubit.state.arrivalIds, isEmpty);
      await cubit.loadNewer();
      expect(cubit.state.messages.last.text, 'local 125');
      expect(cubit.state.arrivalIds, isEmpty);
    },
  );

  test('sending from history jumps to a quiet latest snapshot', () async {
    gateway.seed(85);
    gateway.ready = true;
    await cubit.open('usrPeer', aroundSeq: 1);
    gateway.ready = false;
    final snapshots = <ChatState>[];
    final subscription = cubit.stream.listen(snapshots.add);
    addTearDown(subscription.cancel);
    final opened = cubit.stream.firstWhere(
      (state) =>
          !state.loading && state.messages.lastOrNull?.text == 'from history',
    );
    await cubit.send('from history');
    await opened.timeout(const Duration(seconds: 3));
    expect(cubit.state.messages.last.text, 'from history');
    expect(cubit.state.messages.last.pending, isTrue);
    expect(snapshots.every((state) => state.arrivalIds.isEmpty), isTrue);
  });
}
