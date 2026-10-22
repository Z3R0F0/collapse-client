import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/message_list_fixture.dart';

Finder row(int id) => find.byKey(ValueKey('row-$id'), skipOffstage: false);

void main() {
  testWidgets('canonical rebase preserves partial first anchor and held drag', (
    tester,
  ) async {
    final key = GlobalKey<MessageListFixtureState>();
    await tester.pumpWidget(MessageListFixture(key: key));
    await tester.pumpAndSettle();
    final state = key.currentState!;
    final epoch = state.epoch;
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(0, -47));
    await tester.pump();
    final anchor = int.parse(state.visibleIds.first);
    final before = tester.getRect(row(anchor));
    expect(before.top, lessThan(0));
    expect(before.bottom, greaterThan(0));
    final retained = tester.state<MessageListProbeState>(row(anchor));
    retained.localCounter = 9;

    // Non-monotonic ACK chronology may replace/reorder every neighbor. Only
    // the first painted stable key is guaranteed by this explicit rebase.
    state.change(() {
      state.delivery = 'sent';
      state.rebaseAnchorId = '$anchor';
      state.ids = [...messagePage(5000, 27), anchor, ...messagePage(6000, 92)];
    });
    await tester.pump();
    expect(state.ids, hasLength(120));
    expect(state.epoch, epoch);
    expect(state.visibleIds.first, '$anchor');
    expect(tester.state(row(anchor)), same(retained));
    expect(tester.getTopLeft(row(anchor)).dy, closeTo(before.top, .5));
    expect(find.text('$anchor sent 9', skipOffstage: false), findsOneWidget);
    expect(state.controller.position.isScrollingNotifier.value, isTrue);

    await gesture.moveBy(const Offset(0, -29));
    await tester.pump();
    expect(tester.getTopLeft(row(anchor)).dy, closeTo(before.top - 29, .5));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.olderCalls + state.newerCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('followed rebase wins over arrival and same-frame resize only', (
    tester,
  ) async {
    final key = GlobalKey<MessageListFixtureState>();
    await tester.pumpWidget(MessageListFixture(key: key));
    await tester.pumpAndSettle();
    final state = key.currentState!;
    state.latest(messagePage(1000));
    await tester.pumpAndSettle();
    expect(state.following.last, isTrue);
    state.change(() {
      state.atLatest = false;
      state.newer = true;
    });
    await tester.pump();
    final anchor = int.parse(state.visibleIds.first);
    final before = tester.getTopLeft(row(anchor)).dy;
    final epoch = state.epoch;
    state.change(() {
      state.rebaseAnchorId = '$anchor';
      state.ids = [...messagePage(5000, 27), anchor, ...messagePage(6000, 92)];
      state.inset = 96;
    });
    await tester.pump();
    expect(state.epoch, epoch);
    expect(state.visibleIds.first, '$anchor');
    expect(tester.getTopLeft(row(anchor)).dy, closeTo(before, .5));

    // Returning to the tail restores normal keyboard/composer following even
    // though the rebase marker remains on this unchanged window snapshot.
    state.change(() {
      state.atLatest = true;
      state.newer = false;
    });
    state.controller.sliverController.jumpToIndex(
      state.ids.length - 1,
      offsetBasedOnBottom: true,
    );
    await tester.pumpAndSettle();
    expect(state.following.last, isTrue);
    state.change(() => state.inset = 144);
    await tester.pump();
    expect(tester.getBottomLeft(row(6091)).dy, closeTo(456, .5));
    expect(state.olderCalls + state.newerCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('same visible membership reports a changed first painted ID', (
    tester,
  ) async {
    final key = GlobalKey<MessageListFixtureState>();
    await tester.pumpWidget(MessageListFixture(key: key));
    await tester.pumpAndSettle();
    final state = key.currentState!;
    state.latest([1000, 1001]);
    await tester.pumpAndSettle();
    expect(state.controller.position.maxScrollExtent, 0);
    expect(state.visibleIds.toList(), ['1000', '1001']);
    state.replace([1001, 1000]);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(row(1001)).dy, 0);
    expect(state.visibleIds.toList(), ['1001', '1000']);
    expect(state.olderCalls + state.newerCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
