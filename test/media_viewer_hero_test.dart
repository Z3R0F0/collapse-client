import 'package:collapse/core/theme.dart';
import 'package:collapse/l10n/app_localizations.dart';
import 'package:collapse/src/data/media/media_repository.dart';
import 'package:collapse/src/presentation/media/media_gallery_cubit.dart';
import 'package:collapse/src/presentation/media/media_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/media_viewer_fixture.dart';

void main() {
  for (final width in [390.0, 1100.0]) {
    testWidgets('selected Hero flies back after viewer close at width $width', (
      tester,
    ) async {
      final item = viewerItem(2);
      final gallery = ViewerCubit([item]);
      final media = ViewerMedia();
      final navigator = GlobalKey<NavigatorState>();
      final flights = <HeroFlightDirection>[];
      const shuttle = ValueKey('actual-return-flight');
      const thumbnail = ValueKey('source-thumbnail');
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      try {
        await tester.pumpWidget(
          RepositoryProvider<MediaRepository>.value(
            value: media,
            child: MaterialApp(
              navigatorKey: navigator,
              theme: appTheme(Brightness.dark),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Center(
                  child: Hero(
                    tag: item.heroTag('chat'),
                    flightShuttleBuilder: (_, _, direction, _, _) {
                      flights.add(direction);
                      return const ColoredBox(
                        key: shuttle,
                        color: Colors.white,
                      );
                    },
                    child: const SizedBox(
                      key: thumbnail,
                      width: 160,
                      height: 100,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final targetRect = tester.getRect(find.byKey(thumbnail));
        navigator.currentState!
            .push<void>(
              PageRouteBuilder(
                opaque: false,
                transitionDuration: const Duration(milliseconds: 300),
                reverseTransitionDuration: const Duration(milliseconds: 300),
                pageBuilder: (_, _, _) => BlocProvider<MediaGalleryCubit>.value(
                  value: gallery,
                  child: MediaViewer(
                    heroSurface: 'chat',
                    onClose: () => navigator.currentState!.pop(),
                  ),
                ),
              ),
            )
            .ignore();
        await tester.pump();
        await settleViewer(tester);
        expect(find.byType(MediaViewer), findsOneWidget);
        await tester.tap(find.byTooltip('Close'));
        await tester
            .pump(); // Closing rebuild and HeroController post-frame lookup.
        await tester.pump(const Duration(milliseconds: 100));
        expect(flights, [HeroFlightDirection.pop]);
        expect(find.byKey(shuttle), findsOneWidget);
        final flyingRect = tester.getRect(find.byKey(shuttle));
        expect(flyingRect.width, greaterThan(targetRect.width));
        expect(flyingRect.height, greaterThan(targetRect.height));
        await tester.pumpAndSettle();
        expect(find.byType(MediaViewer), findsNothing);
        expect(find.byKey(shuttle), findsNothing);
        expect(tester.getRect(find.byKey(thumbnail)), targetRect);
        expect(tester.takeException(), isNull);
      } finally {
        await closeViewer(tester, gallery, media);
      }
    });
  }
}
