import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/message_list_fixture.dart';

Finder row(int id) => find.byKey(ValueKey('row-$id'), skipOffstage: false);

void main() {
  testWidgets(
    'empty snapshot reports changed follow intent after a ready epoch',
    (tester) async {
      final key = GlobalKey<MessageListFixtureState>();
      await tester.pumpWidget(MessageListFixture(key: key));
      await tester.pumpAndSettle();
      final state = key.currentState!;
      state.latest([]);
      await tester.pump();
      expect(state.following.last, isTrue);
      state.change(() {
        state.ids = messagePage(240);
        state.target = '300';
        state.atLatest = false;
        state.epoch++;
      });
      await tester.pump();
      expect(state.controller.position.extentAfter, greaterThan(80));
      expect(state.following.last, isFalse);
      final reported = List<bool>.of(state.following);
      state.replace(messagePage(240));
      await tester.pump();
      expect(state.following, reported);
      expect(state.olderCalls + state.newerCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('follow intent survives lagging DB availability across arrivals', (
    tester,
  ) async {
    final key = GlobalKey<MessageListFixtureState>();
    await tester.pumpWidget(MessageListFixture(key: key));
    await tester.pumpAndSettle();
    final state = key.currentState!;
    state.latest(messagePage(1000));
    await tester.pump();
    expect(state.following.last, isTrue);

    // A queued DB successor is not a user request to stop following.
    state.change(() {
      state.atLatest = false;
      state.newer = true;
    });
    await tester.pump();
    expect(state.following.last, isTrue);
    for (final start in [1001, 1002]) {
      state.replace(messagePage(start));
      await tester.pump();
      expect(tester.getBottomLeft(row(start + 119)).dy, closeTo(600, .5));
      expect(state.following.last, isTrue);
    }

    // Explicit history navigation resets intent; availability cannot invent it.
    state.following.clear();
    state.change(() {
      state.target = '1090';
      state.epoch++;
    });
    await tester.pump();
    final anchor = tester.getTopLeft(row(1090)).dy;
    state.replace(messagePage(1003));
    await tester.pump();
    expect(tester.getTopLeft(row(1090)).dy, closeTo(anchor, .5));
    expect(state.following, isNot(contains(true)));
    expect(state.olderCalls + state.newerCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new gesture can retry an unchanged edge after no page commit', (
    tester,
  ) async {
    final key = GlobalKey<MessageListFixtureState>();
    await tester.pumpWidget(MessageListFixture(key: key));
    await tester.pumpAndSettle();
    final state = key.currentState!;
    state.change(() => state.olderPageKey = (240, 0));
    state.controller.jumpTo(50);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(0, 32));
    await tester.pump();
    expect(state.olderCalls, 1);
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(state.olderCalls, 1);
    await gesture.up();
    await tester.pumpAndSettle();

    // A failed/rejected commit leaves the same span. Retry needs a new gesture.
    state.change(() => state.older = false);
    await tester.pump();
    state.change(() => state.older = true);
    await tester.pump();
    expect(state.olderCalls, 1);
    await tester.drag(find.byType(Scrollable), const Offset(0, 32));
    await tester.pump();
    expect(state.olderCalls, 2);
    expect(state.newerCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reversal while a page is pending re-arms the same gesture', (
    tester,
  ) async {
    final key = GlobalKey<MessageListFixtureState>();
    await tester.pumpWidget(MessageListFixture(key: key));
    await tester.pumpAndSettle();
    final state = key.currentState!;
    state.controller.jumpTo(100);
    await tester.pumpAndSettle();
    final pending = Completer<void>();
    state.olderAction = () => pending.future;
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(0, 32));
    await tester.pump();
    expect(state.olderCalls, 1);
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 32));
    await tester.pump();
    expect(state.olderCalls, 1);
    state.olderAction = null;
    pending.complete();
    await tester.pump();
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    expect(state.olderCalls, 2);
    await gesture.up();
    expect(state.newerCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
