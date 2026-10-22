import 'package:collapse/core/theme.dart';
import 'package:collapse/l10n/app_localizations.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:collapse/src/presentation/chat/message_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final theme = appTheme(Brightness.dark);
  Future<void> mount(
    WidgetTester tester,
    Delivery delivery, {
    bool reduced = false,
    bool covered = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: TickerMode(
            enabled: !covered,
            child: Scaffold(
              body: Center(child: MessageStatus(delivery: delivery)),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('delivery fade keeps size and same-value rebuild is quiet', (
    tester,
  ) async {
    await mount(tester, Delivery.queued);
    final size = tester.getSize(find.byType(MessageStatus));
    expect(size, const Size(20, 20));
    expect(tester.hasRunningAnimations, isFalse);
    await mount(tester, Delivery.sent);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.getSize(find.byType(MessageStatus)), size);
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.schedule), findsNothing);
    expect(find.byIcon(Icons.done), findsOneWidget);
    await mount(tester, Delivery.sent);
    expect(tester.hasRunningAnimations, isFalse);
  });

  for (final covered in [false, true]) {
    testWidgets(
      'delivery change is immediate when ${covered ? 'covered' : 'reduced'}',
      (tester) async {
        await mount(
          tester,
          Delivery.queued,
          covered: covered,
          reduced: !covered,
        );
        await mount(tester, Delivery.read, covered: covered, reduced: !covered);
        await tester.pump();
        expect(tester.hasRunningAnimations, isFalse);
        expect(find.byIcon(Icons.done_all), findsOneWidget);
        expect(find.byIcon(Icons.schedule), findsNothing);
        await mount(tester, Delivery.read);
        expect(tester.hasRunningAnimations, isFalse);
      },
    );
  }

  testWidgets('covering an active fade cannot resume it on return', (
    tester,
  ) async {
    await mount(tester, Delivery.queued);
    await mount(tester, Delivery.sent);
    await tester.pump(const Duration(milliseconds: 40));
    await mount(tester, Delivery.sent, covered: true);
    await tester.pump();
    await mount(tester, Delivery.sent);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byIcon(Icons.schedule), findsNothing);
    expect(find.byIcon(Icons.done), findsOneWidget);
  });
}
