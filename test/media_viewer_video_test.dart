import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/attachment_fixture.dart';
import 'support/fake_video_platform.dart';
import 'support/media_viewer_fixture.dart';

void main() {
  late FakeVideoPlatform video;
  late VideoPlayerPlatform original;
  late ViewerCubit gallery;
  late ViewerMedia media;

  setUp(() {
    original = VideoPlayerPlatform.instance;
    video = FakeVideoPlatform();
    VideoPlayerPlatform.instance = video;
    gallery = ViewerCubit([viewerItem(2, type: 'VD'), viewerItem(3)]);
    media = ViewerMedia();
  });
  tearDown(() {
    VideoPlayerPlatform.instance = original;
  });

  testWidgets('video pauses on page change and does not auto-resume', (
    tester,
  ) async {
    await mountViewer(tester, gallery, media, width: 1100);
    await tester.tap(find.byTooltip('Play'));
    await settleAttachment(tester);
    expect(video.plays, 1);
    final pauses = video.pauses;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settleAttachment(tester);
    expect(gallery.state.currentId, viewerItem(3).id);
    expect(video.pauses, greaterThan(pauses));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settleAttachment(tester);
    expect(video.plays, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settleAttachment(tester);
    expect(video.plays, 2);
    await closeViewer(tester, gallery, media);
  });

  testWidgets(
    'background during initialization releases loading and permits retry',
    (tester) async {
      video.delayLoad = true;
      await mountViewer(tester, gallery, media);
      await tester.tap(find.byTooltip('Play'));
      await flushAttachment(tester);
      expect(video.streams, hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleAttachment(tester);
      expect(video.plays, 0);
      expect(video.disposed, [0]);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      video.delayLoad = false;
      await tester.tap(find.byTooltip('Play'));
      await settleAttachment(tester);
      expect(video.plays, 1);
      final pauses = video.pauses;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleAttachment(tester);
      expect(video.pauses, greaterThan(pauses));
      expect(video.plays, 1);
      await closeViewer(tester, gallery, media);
      await tester.pump(const Duration(seconds: 31));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('video decoder failure can be retried with a new controller', (
    tester,
  ) async {
    await mountViewer(tester, gallery, media);
    await tester.tap(find.byTooltip('Play'));
    await settleAttachment(tester);
    video.streams[0]!.addError(
      PlatformException(code: 'decode', message: 'Invalid video'),
    );
    await settleAttachment(tester);
    expect(find.byTooltip('Retry'), findsOneWidget);
    await tester.tap(find.byTooltip('Retry'));
    await settleAttachment(tester);
    expect(video.disposed, [0]);
    expect(video.streams, hasLength(2));
    expect(video.plays, 2);
    await closeViewer(tester, gallery, media);
    expect(tester.takeException(), isNull);
  });
}
