import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/media_viewer_fixture.dart';

void main() {
  for (final closeEarly in [false, true]) {
    testWidgets(
      closeEarly
          ? 'closing cancels a delayed save dialog'
          : 'download saves the displayed photo once with its name and bytes',
      (tester) async {
        final gallery = ViewerCubit([viewerItem(2)]);
        final media = ViewerMedia();
        final saves = <MethodCall>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
        messenger.setMockMethodCallHandler(channel, (call) async {
          saves.add(call);
          return 'saved.png';
        });
        try {
          await mountViewer(tester, gallery, media);
          final bytes = Completer<Uint8List>();
          gallery.delayed = bytes.future;
          final loads = gallery.loads;
          await tester.tap(find.byTooltip('Save'));
          await tester.pump();
          await tester.tap(find.byTooltip('Save'));
          await tester.pump();
          expect(gallery.loads, loads + 1);
          if (closeEarly) {
            await tester.tap(find.byTooltip('Close'));
            await tester.pump();
          }
          bytes.complete(viewerPixel);
          await tester.pumpAndSettle();
          if (closeEarly) {
            expect(saves, isEmpty);
          } else {
            expect(saves, hasLength(1));
            expect(saves.single.method, 'save');
            expect(saves.single.arguments['fileName'], 'item 2');
            expect(saves.single.arguments['bytes'], viewerPixel);
          }
          expect(tester.takeException(), isNull);
        } finally {
          await closeViewer(tester, gallery, media);
          messenger.setMockMethodCallHandler(channel, null);
        }
      },
    );
  }
}
