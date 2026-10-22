import 'package:collapse/widgets/view_activity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('active child cannot escape an inactive retained parent', (
    tester,
  ) async {
    final active = ValueNotifier(true);
    final focus = FocusNode();
    addTearDown(active.dispose);
    addTearDown(focus.dispose);
    bool? childActive, ticking;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: active,
            builder: (_, value, _) => ViewActivity(
              active: value,
              child: ViewActivity(
                active: true,
                child: Builder(
                  builder: (context) {
                    childActive = ViewActivity.isActiveOf(context);
                    ticking = TickerMode.valuesOf(context).enabled;
                    return TextField(focusNode: focus);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(childActive, isTrue);
    expect(ticking, isTrue);
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    active.value = false;
    await tester.pump();
    expect(childActive, isFalse);
    expect(ticking, isFalse);
    expect(focus.canRequestFocus, isFalse);
    expect(focus.hasFocus, isFalse);
    active.value = true;
    await tester.pump();
    expect(childActive, isTrue);
    expect(ticking, isTrue);
  });
}
