import 'package:flutter/material.dart';
import 'package:collapse/src/presentation/chat/attachment_view.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'support/attachment_fixture.dart';
import 'support/fake_video_platform.dart';

void main() {
  late AttachmentMedia media;
  late FakeVideoPlatform video;
  late VideoPlayerPlatform original;
  setUp(() {
    original = VideoPlayerPlatform.instance;
    video = FakeVideoPlatform();
    VideoPlayerPlatform.instance = video;
    media = AttachmentMedia();
  });
  tearDown(() async {
    VideoPlayerPlatform.instance = original;
    await media.dispose();
  });

  testWidgets('retained inactive pane pauses video without resuming it', (
    tester,
  ) async {
    final activity = ValueNotifier(true);
    addTearDown(activity.dispose);
    await mountAttachment(tester, media, 'VD', activity: activity);
    await tapAttachment(tester);
    expect(video.plays, 1);
    final pauses = video.pauses;
    activity.value = false;
    await settleAttachment(tester);
    expect(video.pauses, greaterThan(pauses));
    activity.value = true;
    await settleAttachment(tester);
    expect(video.plays, 1);
    expect(video.streams, hasLength(1));
    await unmountAttachment(tester);
  });

  testWidgets(
    'video reuses source/controller and stays paused across background',
    (tester) async {
      await mountAttachment(tester, media, 'VD');
      final extent = tester.getSize(find.byType(AttachmentView));
      await tapAttachment(tester);
      expect(video.plays, 1);
      expect(tester.getSize(find.byType(AttachmentView)), extent);
      expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);
      final pauses = video.pauses;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await settleAttachment(tester);
      expect(video.pauses, greaterThan(pauses));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleAttachment(tester);
      expect(video.plays, 1);
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
      await tapAttachment(tester);
      expect(video.plays, 2);
      await tapAttachment(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleAttachment(tester);
      expect(
        video.plays,
        2,
        reason: 'Manual pause must survive the plugin resume observer',
      );
      expect(media.resolutions, 1);
      expect(video.streams, hasLength(1));
      await unmountAttachment(tester);
      expect(video.disposed, [0]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late video initialization cannot auto-play after hidden and resumed',
    (tester) async {
      video.delayLoad = true;
      await mountAttachment(tester, media, 'VD');
      await tapAttachment(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      video.ready(0);
      await settleAttachment(tester);
      expect(video.plays, 0);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      video.delayLoad = false;
      await tapAttachment(tester);
      expect(video.plays, 1);
      expect(video.disposed, [0]);
      await unmountAttachment(tester);
      await tester.pump(const Duration(seconds: 31));
    },
  );

  testWidgets('video decoder error releases controller and can be retried', (
    tester,
  ) async {
    await mountAttachment(tester, media, 'VD');
    await tapAttachment(tester);
    video.streams[0]!.addError(
      PlatformException(code: 'decode', message: 'Invalid media'),
    );
    await settleAttachment(tester);
    expect(find.byTooltip('Retry: sample'), findsOneWidget);
    expect(video.disposed, [0]);
    expect(tester.takeException(), isNull);
    await tapAttachment(tester);
    expect(video.streams, hasLength(2));
    expect(video.plays, 2);
    await unmountAttachment(tester);
  });

  testWidgets(
    'video initialization timeout releases the spinner and native controller',
    (tester) async {
      video.delayLoad = true;
      await mountAttachment(tester, media, 'VD');
      await tapAttachment(tester);
      await tester.pump(const Duration(seconds: 31));
      await settleAttachment(tester);
      expect(find.byTooltip('Retry: sample'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(video.disposed, [0]);
      video.delayLoad = false;
      await tapAttachment(tester);
      expect(video.plays, 1);
      await unmountAttachment(tester);
    },
  );

  testWidgets(
    'removing a video while initializing never starts late playback',
    (tester) async {
      video.delayLoad = true;
      await mountAttachment(tester, media, 'VD');
      await tapAttachment(tester);
      await unmountAttachment(tester);
      expect(video.disposed, [0]);
      video.ready(0);
      await tester.pump(const Duration(seconds: 31));
      expect(video.plays, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
