import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:collapse/src/domain/chat/history_models.dart';
import 'package:collapse/src/presentation/chat/chat_cubit.dart';
import 'package:collapse_tinode/collapse_tinode.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_gateway.dart';
import 'support/window_race_fixture.dart';

void main() {
  late AppDatabase database;
  late FakeGateway gateway;
  late PausedWindowRepository repository;
  late ChatCubit cubit;
  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = FakeGateway();
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
  Future<void> queue(int count) async {
    for (var i = 1; i <= count; i++) {
      await repository.send('usrPeer', 'queued $i');
    }
  }

  for (final deleteTail in [false, true]) {
    test(
      'older prefetch ${deleteTail ? 'with a deleted tail' : 'retaining its tail'} preserves follow intent',
      () async {
        gateway.seed(120);
        gateway.ready = true;
        await cubit.open('usrPeer');
        final gate = repository.olderGate = ReadGate<HistoryWindow?>();
        final paging = cubit.loadOlder();
        await gate.captured.future;
        if (deleteTail) {
          await database.applyDeletions('local|me', 'usrPeer', [
            {'low': 120},
          ], 0);
        }
        gate.release.complete();
        await paging;
        expect(cubit.state.messages, hasLength(deleteTail ? 79 : 80));
        expect(cubit.state.messages.first.seq, 41);
        final epoch = cubit.state.navigationEpoch;
        gateway.ready = false;
        final queued = cubit.stream.firstWhere(
          (state) => state.messages.lastOrNull?.text == 'after prefetch',
        );
        await cubit.send('after prefetch');
        await queued.timeout(const Duration(seconds: 3));
        await pumpEventQueue();
        expect(
          cubit.state.navigationEpoch,
          epoch,
          reason: 'No implicit latest navigation after a non-evicting prefetch',
        );
        expect(cubit.state.messages.first.seq, 41);
      },
    );
  }

  test(
    'a late older page cannot evict the viewport after a reversal',
    () async {
      gateway.seed(240);
      gateway.ready = true;
      await cubit.open('usrPeer');
      await cubit.loadOlder();
      await cubit.loadOlder();
      final current = cubit.state.window!;
      cubit.setFollowingLive(false);
      cubit.setVisibleMessages({
        current.messages.singleWhere((m) => m.seq == 125).id,
      });
      final gate = repository.olderGate = ReadGate<HistoryWindow?>();
      final paging = cubit.loadOlder();
      await gate.captured.future;
      final visible = current.messages.singleWhere((m) => m.seq == 230).id;
      cubit.setVisibleMessages({visible});
      gate.release.complete();
      await paging;
      expect(cubit.state.window!.span, current.span);
      expect(cubit.state.messages.any((m) => m.id == visible), isTrue);
      expect(cubit.state.loadingOlder, isFalse);

      // Returning to the older edge can consume the cached page normally.
      cubit.setVisibleMessages({
        current.messages.singleWhere((m) => m.seq == 130).id,
      });
      await cubit.loadOlder();
      expect(cubit.state.messages.first.seq, 81);
      expect(cubit.state.messages.last.seq, 200);
    },
  );

  test('latest navigation invalidates an in-flight older page', () async {
    gateway.seed(600);
    gateway.ready = true;
    await cubit.open('usrPeer', aroundSeq: 240);
    final gate = repository.olderGate = ReadGate<HistoryWindow?>();
    final paging = cubit.loadOlder();
    await gate.captured.future;
    final epoch = cubit.state.navigationEpoch;
    await cubit.jumpToLatest();
    expect(cubit.state.navigationEpoch, epoch + 1);
    expect(cubit.state.targetId, isNull);
    if (cubit.state.messages.last.seq != 600) {
      // Cached latest opens immediately; its owned reconciliation supplies the
      // authoritative tail without a second navigation or another open.
      await cubit.stream
          .firstWhere((state) => state.messages.last.seq == 600)
          .timeout(const Duration(seconds: 3));
    }
    expect(cubit.state.messages.last.seq, 600);
    final latest = cubit.state.window!;
    gate.release.complete();
    await paging;
    expect(cubit.state.window!.span, latest.span);
    expect(cubit.state.messages, latest.messages);
    expect(cubit.state.navigationEpoch, epoch + 1);
    expect(cubit.state.loadingOlder, isFalse);
  });

  test(
    'incremental offline tail retains access to evicted server history',
    () async {
      gateway.seed(1);
      gateway.ready = true;
      await cubit.open('usrPeer');
      expect(cubit.state.hasOlder, isFalse);
      gateway.ready = false;
      final filled = cubit.stream.firstWhere(
        (state) =>
            state.messages.length == 120 &&
            state.messages.last.text == 'queued 120',
      );
      await queue(120);
      await filled.timeout(const Duration(seconds: 2));
      expect(cubit.state.messages.every((message) => message.pending), isTrue);
      expect(cubit.state.hasOlder, isTrue);
      await cubit.loadOlder();
      expect(cubit.state.messages.first.seq, 1);
      expect(cubit.state.messages, hasLength(120));
      await cubit.loadNewer();
      expect(cubit.state.messages.last.text, 'queued 120');
      expect(cubit.state.messages, hasLength(120));
    },
  );

  test('ACK while initial window is loading is replayed after open', () async {
    await queue(1);
    final gate = repository.openGate = ReadGate<HistoryWindow?>();
    final opened = cubit.open('usrPeer');
    await gate.captured.future;
    gateway.ready = true;
    await repository.flushOutbox();
    final sent = cubit.stream.firstWhere(
      (state) => state.messages.length == 1 && state.messages.single.seq > 0,
    );
    gate.release.complete();
    await opened;
    await sent.timeout(const Duration(seconds: 2));
    expect(cubit.state.messages.single.delivery, Delivery.sent);
  });

  test(
    'reply open invalidates an older page even when target was retained',
    () async {
      gateway.seed(240);
      gateway.ready = true;
      await cubit.open('usrPeer');
      await cubit.loadOlder();
      await cubit.loadOlder();
      expect(cubit.state.messages.first.seq, 121);
      expect(cubit.state.messages.last.seq, 240);
      expect(cubit.state.messages, hasLength(120));
      final target = cubit.state.messages.singleWhere(
        (message) => message.seq == 230,
      );

      final gate = repository.olderGate = ReadGate<HistoryWindow?>();
      final older = cubit.loadOlder();
      final stale = (await gate.captured.future)!;
      expect(cubit.state.loadingOlder, isTrue);
      expect(stale.messages.first.seq, 81);
      await repository.deleteMessage(stale.messages.first);

      await cubit.open('usrPeer', aroundSeq: target.seq);
      final replyWindow = cubit.state.messages;
      final revision = cubit.state.revision;
      expect(replyWindow.first.seq, 210);
      expect(replyWindow.last.seq, 240);
      expect(replyWindow.any((message) => message.id == target.id), isTrue);

      gate.release.complete();
      await older;
      expect(cubit.state.messages, replyWindow);
      expect(cubit.state.revision, revision);
      expect(cubit.state.messages.any((message) => message.seq == 81), isFalse);
      expect(cubit.state.loadingOlder, isFalse);
      expect(cubit.state.arrivalIds, isEmpty);
    },
  );

  test(
    'older page cannot resurrect deleted or acknowledged queued rows',
    () async {
      await queue(85);
      await cubit.open('usrPeer');
      final gate = repository.olderGate = ReadGate<HistoryWindow?>();
      final loaded = cubit.loadOlder();
      final snapshot = (await gate.captured.future)!;
      final deleted = snapshot.messages.first;
      await repository.deleteMessage(deleted);
      gateway.ready = true;
      await repository.flushOutbox();
      gate.release.complete();
      await loaded;
      expect(cubit.state.messages.any((m) => m.id == deleted.id), isFalse);
      expect(cubit.state.messages.every((m) => m.seq > 0), isTrue);
      expect(cubit.state.messages, hasLength(79));
    },
  );

  test('delete during page rehydration is applied after its commit', () async {
    await queue(85);
    await cubit.open('usrPeer');
    final gate = repository.inspectGate = ReadGate<HistoryWindow?>();
    final loaded = cubit.loadOlder();
    final snapshot = (await gate.captured.future.timeout(
      const Duration(seconds: 2),
    ))!;
    expect(snapshot.messages.length, 80);
    final deleted = snapshot.messages.first;
    await repository.deleteMessage(deleted);
    final removed = cubit.stream.firstWhere(
      (state) =>
          !state.loadingOlder &&
          state.messages.length == 79 &&
          !state.messages.any((m) => m.id == deleted.id),
    );
    gate.release.complete();
    await loaded;
    await removed.timeout(const Duration(seconds: 2));
    expect(cubit.state.messages.any((m) => m.id == deleted.id), isFalse);
  });

  for (final deleted in [false, true]) {
    test(
      'newer commit sees ${deleted ? 'deleted' : 'visible'} arrival beyond its snapshot',
      () async {
        gateway.seed(85);
        gateway.ready = true;
        gateway.descriptions['usrPeer'] = {'seq': 85, 'read': 80};
        await cubit.open('usrPeer', aroundSeq: 1);
        await cubit.loadNewer();
        expect(cubit.state.messages.last.seq, 80);
        final gate = repository.newerGate = ReadGate<HistoryWindow?>();
        final loaded = cubit.loadNewer();
        final snapshot = (await gate.captured.future)!;
        expect(snapshot.newer.isExhausted, isTrue);
        final incoming = {
          'topic': 'usrPeer',
          'seq': 86,
          'from': 'peer',
          'ts': DateTime.now().toUtc().toIso8601String(),
          'content': 'new arrival',
        };
        gateway.rows.add(incoming);
        final noticed = cubit.stream.firstWhere(
          (state) => state.unreadCount == 6,
        );
        gateway.controller.add(TinodeEvent('data', incoming));
        await noticed.timeout(const Duration(seconds: 2));
        if (deleted) {
          await repository.deleteMessage(
            (await repository.getMessage('usrPeer', 86))!,
          );
        }
        gate.release.complete();
        await loaded;
        expect(cubit.state.hasNewer, !deleted);
        expect(cubit.state.atLiveEdge, deleted);
        if (!deleted) {
          await cubit.loadNewer();
          expect(cubit.state.messages.last.seq, 86);
        }
      },
    );
  }
}
