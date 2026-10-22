import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/cached_tail_fixture.dart';

void main() {
  test(
    'ordinary reconciliation does not shrink a paged 120-row window',
    () async {
      final fixture = CachedTailFixture();
      addTearDown(fixture.dispose);
      await fixture.prepare(120, cached: 120);
      await fixture.cubit.loadOlder();
      await fixture.cubit.loadOlder();
      expect(fixture.cubit.state.messages, hasLength(120));
      final span = fixture.cubit.state.window!.span;
      await fixture.repo.refreshTopics();
      await pumpEventQueue(times: 100);
      expect(fixture.cubit.state.window!.span, span);
      expect(fixture.cubit.state.messages, hasLength(120));
      expect(fixture.gateway.requests, isEmpty);
    },
  );

  for (final (head, staleHead) in [(60, false), (200, false), (200, true)]) {
    testWidgets(
      'cached latest follows an atomic reconciled tail $head stale=$staleHead',
      (tester) async {
        final fixture = (await tester.runAsync(
          () async => CachedTailFixture(),
        ))!;
        addTearDown(() => tester.runAsync(fixture.dispose));
        await tester.runAsync(
          () => fixture.prepare(head, staleHead: staleHead),
        );
        await tester.pumpWidget(fixture.build());
        await tester.pumpAndSettle();
        expect(fixture.cubit.state.messages.last.seq, 20);
        expect(fixture.cubit.state.atLiveEdge, staleHead);
        final epoch = fixture.cubit.state.navigationEpoch;

        await tester.runAsync(fixture.reconcile);
        await tester.pumpAndSettle();
        expect(fixture.cubit.state.messages.last.seq, head);
        expect(fixture.cubit.state.messages.first.seq, head - 39);
        expect(fixture.cubit.state.navigationEpoch, epoch);
        expect(fixture.following.last, isTrue);
        expect(fixture.controller.position.extentAfter, closeTo(0, .5));
        expect(fixture.gateway.requests, hasLength(1));
        expect(fixture.gateway.requests.single.limit, lessThanOrEqualTo(40));
        expect(
          fixture.states.every((state) => state.arrivalIds.isEmpty),
          isTrue,
        );
        expect(
          fixture.states
              .where((state) => state.messages.isNotEmpty)
              .map((state) => state.messages.last.seq)
              .toSet(),
          {20, head},
          reason: 'History packets are not partial visible tail snapshots',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('scrolling away cancels cached-tail following', (tester) async {
    final fixture = (await tester.runAsync(() async => CachedTailFixture()))!;
    addTearDown(() => tester.runAsync(fixture.dispose));
    await tester.runAsync(() => fixture.prepare(200));
    await tester.pumpWidget(fixture.build());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable), const Offset(0, 240));
    await tester.pumpAndSettle();
    expect(fixture.following.last, isFalse);
    final before = fixture.controller.offset;
    final span = fixture.cubit.state.window!.span;

    await tester.runAsync(fixture.reconcile);
    await tester.pumpAndSettle();
    expect(fixture.cubit.state.window!.span, span);
    expect(fixture.cubit.state.messages.last.seq, 20);
    expect(fixture.controller.offset, closeTo(before, .5));
    expect(fixture.following.last, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cached open joins a reconciliation started before subscribing', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(() async => CachedTailFixture()))!;
    addTearDown(() => tester.runAsync(fixture.dispose));
    late Future<void> refresh;
    await tester.runAsync(() async {
      await fixture.prepare(200, open: false);
      refresh = fixture.repo.refreshTopics();
      await fixture.gateway.entered.future.timeout(const Duration(seconds: 2));
      await fixture.cubit.open('usrPeer');
    });
    await tester.pumpWidget(fixture.build());
    await tester.pumpAndSettle();
    expect(fixture.cubit.state.messages.last.seq, 20);
    await tester.runAsync(() async {
      await fixture.reconcile();
      await refresh;
    });
    await tester.pumpAndSettle();
    expect(fixture.cubit.state.messages.first.seq, 161);
    expect(fixture.cubit.state.messages.last.seq, 200);
    expect(fixture.gateway.requests, hasLength(1));
    expect(fixture.following.last, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed tail reconciliation preserves cache and can retry', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(() async => CachedTailFixture()))!;
    addTearDown(() => tester.runAsync(fixture.dispose));
    await tester.runAsync(() async {
      await fixture.prepare(200, staleHead: true);
      fixture.gateway.failHistory = true;
    });
    await tester.pumpWidget(fixture.build());
    await tester.pumpAndSettle();
    await tester.runAsync(fixture.reconcile);
    await tester.pumpAndSettle();
    expect(fixture.cubit.state.messages, hasLength(20));
    expect(fixture.cubit.state.messages.last.seq, 20);
    expect(fixture.cubit.state.atLiveEdge, isFalse);
    expect(fixture.following.last, isTrue);
    await tester.runAsync(() async {
      fixture.gateway.failHistory = false;
      await fixture.repo.refreshTopics();
      await pumpEventQueue(times: 100);
    });
    await tester.pumpAndSettle();
    expect(fixture.cubit.state.messages.first.seq, 161);
    expect(fixture.cubit.state.messages.last.seq, 200);
    expect(fixture.gateway.requests, hasLength(2));
    expect(fixture.following.last, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('explicit cached target wins over old tail reconciliation', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(() async => CachedTailFixture()))!;
    addTearDown(() => tester.runAsync(fixture.dispose));
    await tester.runAsync(() => fixture.prepare(200));
    await tester.pumpWidget(fixture.build());
    await tester.pumpAndSettle();
    await tester.runAsync(() => fixture.cubit.open('usrPeer', aroundSeq: 5));
    await tester.pumpAndSettle();
    final epoch = fixture.cubit.state.navigationEpoch;
    final span = fixture.cubit.state.window!.span;
    final row = find.byKey(
      const ValueKey('row-usrPeer:5'),
      skipOffstage: false,
    );
    final anchor = tester.getTopLeft(row);
    expect(anchor.dy, inInclusiveRange(0, 600));

    await tester.runAsync(fixture.reconcile);
    await tester.pumpAndSettle();
    expect(fixture.cubit.state.navigationEpoch, epoch);
    expect(fixture.cubit.state.targetId, 'usrPeer:5');
    expect(fixture.cubit.state.window!.span, span);
    expect(tester.getTopLeft(row), anchor);
    expect(fixture.following.last, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final target in [false, true]) {
    testWidgets(
      'late cached tail respects ${target ? 'navigation' : 'scroll-away'} during DB read',
      (tester) async {
        final fixture = (await tester.runAsync(
          () async => CachedTailFixture(),
        ))!;
        addTearDown(() => tester.runAsync(fixture.dispose));
        await tester.runAsync(() async {
          await fixture.prepare(200);
          fixture.repo.cachedReadGate = Completer<void>();
        });
        await tester.pumpWidget(fixture.build());
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await fixture.reconcile();
          await fixture.repo.cachedReadEntered.future.timeout(
            const Duration(seconds: 2),
          );
        });
        expect(fixture.cubit.state.messages.last.seq, 20);
        if (target) {
          await tester.runAsync(
            () => fixture.cubit.open('usrPeer', aroundSeq: 5),
          );
        } else {
          await tester.drag(find.byType(Scrollable), const Offset(0, 240));
        }
        await tester.pumpAndSettle();
        final epoch = fixture.cubit.state.navigationEpoch;
        final span = fixture.cubit.state.window!.span;
        final offset = fixture.controller.offset;
        expect(fixture.following.last, isFalse);
        await tester.runAsync(() async {
          fixture.repo.cachedReadGate!.complete();
          await pumpEventQueue(times: 100);
        });
        await tester.pumpAndSettle();
        expect(fixture.cubit.state.navigationEpoch, epoch);
        expect(fixture.cubit.state.window!.span, span);
        expect(fixture.cubit.state.messages.last.seq, 20);
        expect(fixture.controller.offset, closeTo(offset, .5));
        expect(fixture.following.last, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
