import 'dart:async';

import 'package:collapse/src/presentation/media/media_gallery_cubit.dart';
import 'package:collapse/src/presentation/media/media_viewer_image.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/media_viewer_fixture.dart';

void main() {
  void viewerTest(
    String name,
    Future<void> Function(WidgetTester, ViewerCubit, ViewerMedia) body,
  ) {
    testWidgets(name, (tester) async {
      final gallery = ViewerCubit([viewerItem(2), viewerItem(3)]);
      final media = ViewerMedia();
      try {
        await body(tester, gallery, media);
      } finally {
        await closeViewer(tester, gallery, media);
      }
    });
  }

  ExtendedImageGestureState gesture(WidgetTester tester) =>
      tester.state<ExtendedImageGestureState>(
        find.byType(ExtendedImageGesture).first,
      );

  viewerTest('desktop keyboard changes media, zooms and closes once', (
    tester,
    gallery,
    media,
  ) async {
    var closes = 0;
    await mountViewer(
      tester,
      gallery,
      media,
      width: 1100,
      onClose: () => closes++,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.pumpAndSettle();
    expect(gesture(tester).gestureDetails!.totalScale, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.pumpAndSettle();
    expect(gesture(tester).gestureDetails!.totalScale, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(gallery.state.currentId, viewerItem(3).id);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closes, 1);
    expect(tester.takeException(), isNull);
  });

  viewerTest('mobile horizontal swipe changes page, not the dismiss route', (
    tester,
    gallery,
    media,
  ) async {
    var closes = 0;
    await mountViewer(tester, gallery, media, onClose: () => closes++);
    await tester.drag(find.byType(ExtendedImage).first, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(gallery.state.currentId, viewerItem(3).id);
    expect(closes, 0);
    expect(tester.takeException(), isNull);
  });

  viewerTest(
    'toolbar click changes the painted image and keeps controls legible',
    (tester, gallery, media) async {
      await mountViewer(tester, gallery, media, width: 1100);
      final before = gesture(tester).gestureDetails!.destinationRect!;
      final button = find.byTooltip('Zoom in');
      await tester.tap(button);
      await tester.pumpAndSettle();
      final after = gesture(tester).gestureDetails!.destinationRect!;
      expect(after.width, greaterThan(before.width));
      expect(after.height, greaterThan(before.height));
      expect(gesture(tester).gestureDetails!.totalScale, 2);
      final icon = find.descendant(
        of: button,
        matching: find.byIcon(Icons.add),
      );
      expect(IconTheme.of(tester.element(icon)).color, Colors.white);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is AnnotatedRegion<SystemUiOverlayStyle> &&
              widget.value == SystemUiOverlayStyle.light,
        ),
        findsOneWidget,
      );
      final buttonTheme = IconButtonTheme.of(tester.element(button));
      expect(
        buttonTheme.style!.foregroundColor!.resolve({WidgetState.disabled}),
        Colors.white38,
      );
      await tester.tap(find.byTooltip('Reset zoom'));
      await tester.pumpAndSettle();
      expect(gesture(tester).gestureDetails!.destinationRect, before);
    },
  );

  viewerTest('double-tap zoom blocks vertical dismissal until reset', (
    tester,
    gallery,
    media,
  ) async {
    var closes = 0;
    await mountViewer(tester, gallery, media, onClose: () => closes++);
    final image = find.byType(ExtendedImage).first;
    await tester.tap(image);
    await tester.pump(const Duration(milliseconds: 90));
    await tester.tap(image);
    await tester.pumpAndSettle();
    expect(gesture(tester).gestureDetails!.totalScale, 3);
    await tester.timedDrag(
      image,
      const Offset(0, 240),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(closes, 0);
    tester
        .state<MediaViewerImageState>(find.byType(MediaViewerImage).first)
        .zoom(0);
    await tester.pumpAndSettle();
    expect(gesture(tester).gestureDetails!.totalScale, 1);
    await tester.timedDrag(
      image,
      const Offset(0, 260),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(closes, 1);
    expect(gallery.state.currentId, viewerItem(2).id);
    expect(tester.takeException(), isNull);
  });

  viewerTest('pinch zoom is not gallery navigation or dismissal', (
    tester,
    gallery,
    media,
  ) async {
    var closes = 0;
    await mountViewer(tester, gallery, media, onClose: () => closes++);
    final center = tester.getCenter(find.byType(ExtendedImage).first);
    final a = await tester.startGesture(
      center - const Offset(30, 0),
      pointer: 1,
    );
    final b = await tester.startGesture(
      center + const Offset(30, 0),
      pointer: 2,
    );
    await tester.pump();
    await a.moveTo(center - const Offset(80, 0));
    await b.moveTo(center + const Offset(80, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(gesture(tester).gestureDetails!.totalScale, greaterThan(1));
    expect(gallery.state.currentId, viewerItem(2).id);
    expect(closes, 0);
  });

  viewerTest(
    'prepend retains selected stable media and zoom in the first frame',
    (tester, gallery, media) async {
      await mountViewer(tester, gallery, media);
      final image = tester.state<MediaViewerImageState>(
        find.byType(MediaViewerImage).first,
      );
      image.zoom(2);
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byType(MediaViewerImage).first);
      gallery.show([viewerItem(1), ...gallery.state.items]);
      await tester.pump();
      final retained = find.byWidgetPredicate(
        (widget) =>
            widget is MediaViewerImage && widget.item.id == viewerItem(2).id,
      );
      expect(tester.state(retained), same(image));
      expect(tester.getRect(retained), before);
      expect(gesture(tester).gestureDetails!.totalScale, 2);
      expect(gallery.state.currentId, viewerItem(2).id);
      await tester.pumpAndSettle();
      expect(tester.getRect(retained), before);
      expect(tester.takeException(), isNull);
    },
  );

  viewerTest('failure retries; cached same-ID data updates do not reload', (
    tester,
    gallery,
    media,
  ) async {
    gallery.failBytes = true;
    await mountViewer(tester, gallery, media);
    expect(find.text('Retry'), findsOneWidget);
    gallery.failBytes = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(ExtendedImage), findsOneWidget);
    final loads = gallery.loads;
    gallery.show([viewerItem(2), viewerItem(3)]);
    await tester.pumpAndSettle();
    expect(gallery.loads, loads);
    expect(tester.takeException(), isNull);
  });

  viewerTest('singleton probes once; another explicit edge drag can retry', (
    tester,
    gallery,
    media,
  ) async {
    gallery.show([viewerItem(2)]);
    gallery.setEdges(older: true);
    await mountViewer(tester, gallery, media);
    expect(gallery.olderCalls, 1);
    await tester.pumpAndSettle();
    expect(gallery.olderCalls, 1, reason: 'No empty-page auto-fetch loop');
    await tester.timedDrag(
      find.byType(ExtendedImage),
      const Offset(250, 0),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    expect(gallery.olderCalls, 2);
    tester.state<MediaViewerImageState>(find.byType(MediaViewerImage)).zoom(3);
    await tester.pumpAndSettle();
    await tester.timedDrag(
      find.byType(ExtendedImage),
      const Offset(250, 0),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    expect(
      gallery.olderCalls,
      2,
      reason: 'Zoomed image pan is not history paging',
    );
  });

  viewerTest('ACK cursor and deleted selection each notify the route once', (
    tester,
    gallery,
    media,
  ) async {
    final changes = <MediaItem>[];
    await mountViewer(tester, gallery, media, onCurrentChanged: changes.add);
    final old = gallery.state.current!;
    final ack = MediaItem(
      topicId: old.topicId,
      messageId: old.messageId,
      seq: 200,
      entityIndex: old.entityIndex,
      type: old.type,
      data: old.data,
      senderId: old.senderId,
      createdAt: old.createdAt,
    );
    gallery.show([viewerItem(3), ack]);
    await tester.pumpAndSettle();
    expect(changes.map((item) => item.seq), [200]);
    gallery.show([viewerItem(3), ack]);
    await tester.pumpAndSettle();
    expect(changes, hasLength(1));
    gallery.show([viewerItem(3)], current: viewerItem(3).id);
    await tester.pumpAndSettle();
    expect(changes.map((item) => item.seq), [200, 3]);
  });

  viewerTest(
    'Hero exists on the first frame while selected bytes are delayed',
    (tester, gallery, media) async {
      final bytes = Completer<Uint8List>();
      gallery.delayed = bytes.future;
      await mountViewer(tester, gallery, media, settle: false);
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Hero && widget.tag == viewerItem(2).heroTag('chat'),
        ),
        findsOneWidget,
      );
      bytes.complete(viewerPixel);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
