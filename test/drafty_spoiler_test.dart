import 'package:collapse/core/theme.dart';
import 'package:collapse/l10n/app_localizations.dart';
import 'package:collapse/src/presentation/chat/drafty_spoiler.dart';
import 'package:collapse/src/presentation/chat/drafty_text.dart';
import 'package:collapse_tinode/tinode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> show(WidgetTester tester, Object content, {double width = 220}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: DraftyText(content: content),
          ),
        ),
      ),
    );

void main() {
  for (final secret in [
    'hidden',
    '**hidden 👨‍👩‍👧‍👦 é**',
    'a very long secret which wraps onto several lines without moving the row',
    '[hidden](https://secret.example)',
    'скрытый текст עברית',
  ]) {
    testWidgets('reveal keeps geometry and excludes semantics: $secret', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await show(tester, DraftyCodec.markdown('before ||$secret|| after'));
      final spoiler = find.byType(DraftySpoiler);
      final size = tester.getSize(find.byType(DraftyText).first);
      final rect = tester.getRect(spoiler);
      expect(spoiler, findsOneWidget);
      expect(find.bySemanticsLabel('Reveal spoiler'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('hidden|secret.example|скрытый')),
        findsNothing,
      );
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0,
      );
      await tester.tap(find.bySemanticsLabel('Reveal spoiler'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Reveal spoiler'), findsNothing);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );
      expect(tester.getRect(spoiler), rect);
      expect(tester.getSize(find.byType(DraftyText).first), size);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('generic HD stays hidden, even overlapping a revealable range', (
    tester,
  ) async {
    final doc = DraftyCodec.markdown('||secret||');
    (doc['fmt'] as List).add({'tp': 'HD', 'at': 2, 'len': 1});
    await show(tester, doc);
    expect(find.byType(DraftySpoiler), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'receipt-style rebuild does not close an already revealed spoiler',
    (tester) async {
      await show(tester, DraftyCodec.markdown('||secret||'));
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      await show(tester, DraftyCodec.markdown('||secret||'), width: 360);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
