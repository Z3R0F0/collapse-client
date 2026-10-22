import 'package:collapse/core/theme.dart';
import 'package:collapse/l10n/app_localizations.dart';
import 'package:collapse/src/presentation/media/media_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/media_viewer_fixture.dart';

void main() {
  testWidgets('atlas tile has one accessible name and tap action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final item = viewerItem(2);
    final gallery = ViewerCubit([item]);
    var opened = 0;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.dark),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox.square(
              dimension: 160,
              child: MediaTile(
                item: item,
                gallery: gallery,
                onOpen: () => opened++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.byType(MediaTile));
      expect(node.getSemanticsData().label, 'item 2');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(find.bySemanticsLabel('item 2'), findsOneWidget);
      await tester.tap(find.byType(MediaTile));
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
      await gallery.close();
    }
  });
}
