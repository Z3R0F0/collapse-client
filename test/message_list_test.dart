import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/message_list_fixture.dart';

// Upstream's debugVisitOnstageChildren is empty. Traverse all built children,
// then verify real viewport intersection instead of weakening geometry checks.
Finder row(int id) => find.byKey(ValueKey('row-$id'), skipOffstage: false);
double top(WidgetTester tester, int id) => tester.getTopLeft(row(id)).dy;
(int, double) anchor(WidgetTester tester) {
  for (final element
      in find.byType(MessageListProbe, skipOffstage: false).evaluate()) {
    final id = (element.widget as MessageListProbe).id;
    final rect = tester.getRect(row(id));
    if (rect.bottom > 0 && rect.top < 500) return (id, rect.top);
  }
  throw StateError('No visible row');
}

void main() {
  for (final older in [true, false]) {
    testWidgets(
      'bounded ${older ? 'older' : 'newer'} page preserves an active fling',
      (tester) async {
        final key = GlobalKey<MessageListFixtureState>();
        await tester.pumpWidget(MessageListFixture(key: key));
        await tester.pumpAndSettle();
        await tester.fling(
          find.byType(Scrollable),
          Offset(0, older ? 100 : -100),
          900,
        );
        await tester.pump(const Duration(milliseconds: 16));
        final state = key.currentState!;
        final saved = anchor(tester);
        expect(state.controller.position.isScrollingNotifier.value, isTrue);
        state.replace(messagePage(older ? 200 : 280));
        await tester.pump();
        expect(top(tester, saved.$1), closeTo(saved.$2, .5));
        expect(state.controller.position.isScrollingNotifier.value, isTrue);
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          top(tester, saved.$1),
          older ? greaterThan(saved.$2 + 1) : lessThan(saved.$2 - 1),
        );
        await tester.pumpAndSettle();
        expect(state.olderCalls + state.newerCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'bounded ${older ? 'older' : 'newer'} page preserves active drag and ACK identity',
      (tester) async {
        final key = GlobalKey<MessageListFixtureState>();
        await tester.pumpWidget(MessageListFixture(key: key));
        await tester.pumpAndSettle();
        final state = key.currentState!;
        final gesture = await tester.startGesture(const Offset(400, 300));
        await gesture.moveBy(Offset(0, older ? 32 : -32));
        await tester.pump();
        final saved = anchor(tester);
        final rowState = tester.state<MessageListProbeState>(row(saved.$1));
        rowState.localCounter = 5;
        state.replace(messagePage(older ? 200 : 280));
        await tester.pump();
        expect(top(tester, saved.$1), closeTo(saved.$2, .5));
        expect(tester.state(row(saved.$1)), same(rowState));
        expect(state.visibleIds, contains('${saved.$1}'));
        expect(
          state.visibleIds.every((id) => state.ids.contains(int.parse(id))),
          isTrue,
        );
        state.change(() => state.delivery = 'sent');
        await tester.pump();
        expect(top(tester, saved.$1), closeTo(saved.$2, .5));
        expect(
          find.text('${saved.$1} sent 5', skipOffstage: false),
          findsOneWidget,
        );
        await gesture.moveBy(Offset(0, older ? 29 : -29));
        await tester.pump();
        expect(
          top(tester, saved.$1),
          closeTo(saved.$2 + (older ? 29 : -29), .5),
        );
        await gesture.up();
        expect(state.olderCalls + state.newerCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('snapshot latest and geometry updates never invoke paging', (
    tester,
  ) async {
    final key = GlobalKey<MessageListFixtureState>();
    await tester.pumpWidget(MessageListFixture(key: key));
    await tester.pumpAndSettle();
    final state = key.currentState!;
    state.latest(messagePage(1000), bottomInset: 96);
    await tester.pump();
    expect(tester.getBottomLeft(row(1119)).dy, closeTo(504, .5));
    state.latest(messagePage(2000), bottomInset: 96);
    await tester.pump();
    expect(tester.getBottomLeft(row(2119)).dy, closeTo(504, .5));
    state.change(() => state.inset = 144);
    await tester.pump();
    expect(tester.getBottomLeft(row(2119)).dy, closeTo(456, .5));
    expect(state.olderCalls + state.newerCalls, 0);
    expect(state.following.last, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'followed arrival sticks to latest; history updates preserve anchor',
    (tester) async {
      final key = GlobalKey<MessageListFixtureState>();
      await tester.pumpWidget(MessageListFixture(key: key));
      await tester.pumpAndSettle();
      final state = key.currentState!;
      state.latest(messagePage(1000), bottomInset: 96);
      await tester.pump();
      state.replace(messagePage(1001));
      await tester.pump();
      expect(tester.getBottomLeft(row(1120)).dy, closeTo(504, .5));
      state.controller.jumpTo(state.controller.offset - 500);
      await tester.pumpAndSettle();
      final saved = anchor(tester);
      state.change(() => state.delivery = 'read');
      await tester.pump();
      expect(top(tester, saved.$1), closeTo(saved.$2, .5));
      expect(state.following.last, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('only a user gesture requests a page, once per unchanged edge', (
    tester,
  ) async {
    final key = GlobalKey<MessageListFixtureState>();
    await tester.pumpWidget(MessageListFixture(key: key));
    await tester.pumpAndSettle();
    final state = key.currentState!;
    state.controller.jumpTo(50);
    await tester.pumpAndSettle();
    expect(state.olderCalls, 0);
    final pending = Completer<void>();
    state.olderAction = () => pending.future;
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(0, 32));
    await tester.pump();
    expect(state.olderCalls, 1);
    pending.complete();
    await tester.pump();
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(state.olderCalls, 1);
    await gesture.up();
    expect(state.newerCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short latest has no automatic pagination or hidden last row', (
    tester,
  ) async {
    final key = GlobalKey<MessageListFixtureState>();
    await tester.pumpWidget(MessageListFixture(key: key));
    await tester.pumpAndSettle();
    final state = key.currentState!;
    state.latest(messagePage(1000, 1), bottomInset: 96);
    await tester.pump();
    final rect = tester.getRect(row(1000));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(504));
    expect(state.controller.position.maxScrollExtent, 0);
    expect(state.olderCalls + state.newerCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cursor progress through deleted rows re-arms paging, not layout',
    (tester) async {
      final key = GlobalKey<MessageListFixtureState>();
      await tester.pumpWidget(MessageListFixture(key: key));
      await tester.pumpAndSettle();
      final state = key.currentState!;
      state.change(() => state.olderPageKey = (240, 0));
      state.controller.jumpTo(40);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(400, 300));
      await gesture.moveBy(const Offset(0, 32));
      await tester.pump();
      expect(state.olderCalls, 1);
      await gesture.moveBy(const Offset(0, 32));
      await tester.pump();
      expect(state.olderCalls, 1);
      state.change(() => state.olderPageKey = (200, 0));
      await tester.pump();
      expect(state.olderCalls, 1);
      await gesture.moveBy(const Offset(0, 32));
      await tester.pump();
      expect(state.olderCalls, 2);
      await gesture.up();
      expect(state.newerCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('offline paging availability is not the global latest boundary', (
    tester,
  ) async {
    final key = GlobalKey<MessageListFixtureState>();
    await tester.pumpWidget(MessageListFixture(key: key));
    await tester.pumpAndSettle();
    final state = key.currentState!;
    state.change(() {
      state.newer = false;
      state.target = '350';
      state.epoch++;
    });
    await tester.pump();
    // Reaching the local end of a targeted offline island is not Latest.
    state.controller.sliverController.jumpToIndex(
      state.ids.length - 1,
      offsetBasedOnBottom: true,
    );
    await tester.pump();
    expect(tester.getBottomLeft(row(359)).dy, closeTo(600, .5));
    expect(state.following, isNot(contains(true)));
    expect(state.newerCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
