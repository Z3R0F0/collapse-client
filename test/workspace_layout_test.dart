import 'package:collapse/src/presentation/app/workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/workspace_fixture.dart';

void main() {
  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets(
      'divider preserves adjacent ${kind.name} taps and boundary drag',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var sidebar = 320.0, leftTaps = 0, rightTaps = 0;
        Widget button(String label, VoidCallback onTap) => SizedBox(
          width: 24,
          height: 48,
          child: TextButton(onPressed: onTap, child: Text(label)),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1120,
                height: 700,
                child: StatefulBuilder(
                  builder: (context, change) => WorkspaceLayout(
                    masterBuilder: (_, _) => Align(
                      alignment: Alignment.topRight,
                      child: button('L', () => leftTaps++),
                    ),
                    detail: Align(
                      alignment: Alignment.topLeft,
                      child: button('R', () => rightTaps++),
                    ),
                    hasDetail: true,
                    sidebarWidth: sidebar,
                    onSidebarWidthChanged: (value) =>
                        change(() => sidebar = value),
                    resizeLabel: 'Resize sidebar',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final left = find.widgetWithText(TextButton, 'L');
        final right = find.widgetWithText(TextButton, 'R');
        expect(tester.getCenter(left).dx, sidebar - 12);
        expect(tester.getCenter(right).dx, sidebar + 12);
        await tester.tapAt(tester.getCenter(left), kind: kind);
        await tester.tapAt(tester.getCenter(right), kind: kind);
        await tester.pumpAndSettle();
        expect((leftTaps, rightTaps), (1, 1));
        expect(sidebar, 320);
        await tester.dragFrom(
          Offset(sidebar, 24),
          const Offset(80, 0),
          kind: kind,
        );
        await tester.pumpAndSettle();
        expect(sidebar, greaterThan(320));
        expect((leftTaps, rightTaps), (1, 1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  Future<WorkspaceFixtureState> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey<WorkspaceFixtureState>();
    await tester.pumpWidget(WorkspaceFixture(key: key));
    await tester.pumpAndSettle();
    return key.currentState!;
  }

  testWidgets('resize and collapse retain each pane, draft and scroll owner', (
    tester,
  ) async {
    final state = await mount(tester);
    final detail = state.detailKey.currentState!;
    final master = state.masterKey.currentState!;
    final owner = detail.ownedState;
    detail.input.text = 'Unsent draft';
    detail.scroll.jumpTo(480);
    await tester.pump();

    for (final width in [360.0, 839.0, 840.0, 1120.0]) {
      state.change(() => state.width = width);
      await tester.pump();
      expect(state.detailKey.currentState, same(detail));
      expect(state.masterKey.currentState, same(master));
      expect(detail.ownedState, same(owner));
      expect(detail.input.text, 'Unsent draft');
      expect(detail.scroll.offset, 480);
      expect(detail.active, isTrue);
      expect(detail.size.width, greaterThanOrEqualTo(360));
      expect(master.size.width, greaterThan(0));
      expect(state.sidebar, 320);
      expect(state.changedWidths, isEmpty);
    }

    state.change(() => state.sidebar = WorkspaceLayout.compactWidth);
    await tester.pump();
    expect(state.compact, isTrue);
    expect(master.size.width, 72);
    expect(detail.size.width, 1048);
    expect(state.detailKey.currentState, same(detail));
    expect(detail.scroll.offset, 480);
    expect(detail.disposed || master.disposed, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden mobile pane has no focus or semantics but keeps layout', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final state = await mount(tester);
      final detail = state.detailKey.currentState!;
      final master = state.masterKey.currentState!;
      detail.focus.requestFocus();
      await tester.pump();
      expect(detail.focus.hasFocus, isTrue);

      state.change(() {
        state.width = 360;
        state.hasDetail = false;
      });
      await tester.pumpAndSettle();
      expect(detail.active || detail.ticking || detail.focus.hasFocus, isFalse);
      expect(detail.focus.canRequestFocus, isFalse);
      expect(detail.size.width, 360);
      expect(detail.size.height, greaterThan(0));
      expect(find.bySemanticsLabel('detail draft'), findsNothing);
      expect(master.active, isTrue);
      expect(find.bySemanticsLabel('master draft'), findsOneWidget);

      state.change(() => state.hasDetail = true);
      await tester.pumpAndSettle();
      expect(state.detailKey.currentState, same(detail));
      expect(detail.active && detail.ticking, isTrue);
      expect(master.active || master.ticking, isFalse);
      expect(master.size.width, 360);
      expect(find.bySemanticsLabel('master draft'), findsNothing);
      expect(find.bySemanticsLabel('detail draft'), findsOneWidget);

      state.change(() => state.active = false);
      await tester.pump();
      expect(detail.active || master.active, isFalse);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('divider drag snaps compact and respects detail minimum', (
    tester,
  ) async {
    final state = await mount(tester);
    final handle = find.byKey(const ValueKey('workspace-divider'));
    await tester.drag(handle, const Offset(-280, 0));
    await tester.pumpAndSettle();
    expect(state.sidebar, 72);
    expect(state.compact, isTrue);

    await tester.drag(handle, const Offset(230, 0));
    await tester.pumpAndSettle();
    expect(state.sidebar, inInclusiveRange(240, 420));
    expect(state.compact, isFalse);
    await tester.drag(handle, const Offset(1000, 0));
    await tester.pumpAndSettle();
    expect(state.sidebar, 420);

    state.change(() {
      state.width = 840;
      state.textScale = 2;
    });
    await tester.pumpAndSettle();
    expect(state.detailKey.currentState!.size.width, greaterThanOrEqualTo(400));
    expect(tester.getSize(handle).width, 8);
    expect(tester.takeException(), isNull);
  });

  testWidgets('divider supports keyboard and labelled slider semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final state = await mount(tester);
      final handle = find.byKey(const ValueKey('workspace-divider'));
      Focus.of(tester.element(handle)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(state.sidebar, 72);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(state.sidebar, 240);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(state.sidebar, 264);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(state.sidebar, 240);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(state.sidebar, 72);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(state.sidebar, 420);
      expect(find.bySemanticsLabel('Resize sidebar'), findsOneWidget);
      final data = tester
          .getSemantics(find.bySemanticsLabel('Resize sidebar'))
          .getSemanticsData();
      expect(data.value, '420');
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
