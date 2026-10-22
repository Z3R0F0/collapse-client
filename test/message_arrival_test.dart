import 'package:clock/clock.dart';
import 'package:collapse/src/presentation/chat/message_arrival.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var settled = 0;
  const childKey = ValueKey('body');
  Future<void> mount(
    WidgetTester tester,
    DateTime? entered, {
    String text = 'Queued',
    bool disabled = false,
    bool ticking = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disabled),
        child: TickerMode(
          enabled: ticking,
          child: Center(
            child: MessageArrival(
              enteredAt: entered,
              isMe: true,
              onSettled: () => settled++,
              child: SizedBox(
                key: childKey,
                width: 120,
                height: 48,
                child: Text(text),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  double opacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.descendant(
          of: find.byType(MessageArrival),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;

  setUp(() => settled = 0);

  testWidgets('history snapshots have no entry animation', (tester) async {
    await mount(tester, null);
    expect(opacity(tester), 1);
    await tester.pump(MessageArrival.duration);
    expect(settled, 0);
  });

  testWidgets('ACK during entry keeps child identity, progress and layout', (
    tester,
  ) async {
    final entered = clock.now();
    await mount(tester, entered);
    final element = tester.element(find.byKey(childKey));
    final extent = tester.getSize(find.byType(MessageArrival));
    expect(opacity(tester), lessThan(.3));
    await tester.pump(const Duration(milliseconds: 50));
    final beforeAck = opacity(tester);
    await mount(tester, entered, text: 'Sent');
    expect(tester.element(find.byKey(childKey)), same(element));
    expect(tester.getSize(find.byType(MessageArrival)), extent);
    expect(opacity(tester), greaterThanOrEqualTo(beforeAck));
    expect(opacity(tester), lessThan(1));
    await tester.pumpAndSettle();
    expect(opacity(tester), 1);
    expect(settled, 1);
    await mount(tester, entered, text: 'Read');
    expect(opacity(tester), 1);
    expect(settled, 1);
  });

  testWidgets('a late-mounted row does not replay an expired arrival', (
    tester,
  ) async {
    await mount(tester, clock.now().subtract(const Duration(seconds: 2)));
    expect(opacity(tester), 1);
    expect(settled, 1);
  });

  testWidgets('reduced motion completes entry immediately', (tester) async {
    await mount(tester, clock.now(), disabled: true);
    expect(opacity(tester), 1);
    expect(settled, 1);
  });

  testWidgets('covered route settles instead of replaying on return', (
    tester,
  ) async {
    final entered = clock.now();
    await mount(tester, entered);
    await tester.pump(const Duration(milliseconds: 30));
    await mount(tester, entered, ticking: false);
    expect(opacity(tester), 1);
    await mount(tester, entered);
    expect(opacity(tester), 1);
    expect(settled, 1);
  });

  testWidgets('eviction disposes motion without a completion or ticker leak', (
    tester,
  ) async {
    await mount(tester, clock.now());
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(settled, 0);
    expect(tester.takeException(), isNull);
    await mount(tester, null);
    expect(opacity(tester), 1);
  });
}
