import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/presentation/chat/chat_cubit.dart';
import 'package:collapse_tinode/collapse_tinode.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/arrival_gateway.dart';

class _CountingRepository extends ChatsRepository {
  _CountingRepository(AppDatabase db, FakeGateway gateway)
    : super(database: db, gateway: gateway, serverId: 'local');

  int opens = 0;

  @override
  Future<HistoryWindow?> openHistory(
    String topicId, {
    int? aroundSeq,
    String? aroundId,
    int limit = 40,
  }) {
    opens++;
    return super.openHistory(
      topicId,
      aroundSeq: aroundSeq,
      aroundId: aroundId,
      limit: limit,
    );
  }
}

class _LaggingCubit extends ChatCubit {
  _LaggingCubit(super.repository);
  int latestCalls = 0;

  @override
  Future<void> jumpToLatest() {
    latestCalls++;
    return super.jumpToLatest();
  }

  void showQueuedSuccessor() {
    final window = state.window!;
    emit(
      state.copyWith(
        window: HistoryWindow(
          window.messages,
          span: window.span,
          older: window.older,
          newer: const HistoryEdge(HistoryAvailability.available),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sending while following a lagging window never opens another snapshot',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final gateway = FakeGateway();
      final repository = _CountingRepository(database, gateway);
      final cubit = _LaggingCubit(repository);
      addTearDown(() async {
        await cubit.close();
        await repository.dispose();
        await gateway.dispose();
        await database.close();
      });
      await repository.start('me');
      await cubit.open('usrPeer');
      final epoch = cubit.state.navigationEpoch;
      cubit.setFollowingLive(true);
      cubit.showQueuedSuccessor();
      expect(cubit.state.atLiveEdge, isFalse);

      await cubit.send('next rapid send');

      expect(cubit.latestCalls, 0);
      expect(repository.opens, 1);
      expect(cubit.state.navigationEpoch, epoch);
      expect(cubit.state.loading, isFalse);
    },
  );

  test(
    'history notice excludes own echo but retains unseen incoming',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final gateway = FakeGateway()..seed(85);
      final repository = _CountingRepository(database, gateway);
      final cubit = ChatCubit(repository);
      addTearDown(() async {
        await cubit.close();
        await repository.dispose();
        await gateway.dispose();
        await database.close();
      });
      await repository.start('me');
      gateway.ready = true;
      gateway.descriptions['usrPeer'] = {'seq': 85, 'read': 40};
      await cubit.open('usrPeer', aroundSeq: 1);
      expect(cubit.state.window!.span.server.end, 41);

      final ownState = cubit.stream.firstWhere(
        (state) => state.unreadCount > 0,
      );
      final own = {...arrivalPacket(86), 'from': 'me'};
      gateway.rows.add(own);
      gateway.controller.add(TinodeEvent('data', own));
      expect(
        (await ownState.timeout(const Duration(seconds: 3))).unreadCount,
        45,
      );

      final peerState = cubit.stream.firstWhere(
        (state) => state.unreadCount == 46,
      );
      final peer = arrivalPacket(87);
      gateway.rows.add(peer);
      gateway.controller.add(TinodeEvent('data', peer));
      expect(
        (await peerState.timeout(const Duration(seconds: 3))).unreadCount,
        46,
      );
      expect(gateway.notes.where((note) => note.what == 'read'), isEmpty);
      expect(cubit.state.messages.last.seq, 40);
    },
  );
}
