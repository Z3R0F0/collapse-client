import 'dart:async';
import 'package:flutter/material.dart';
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

  for (final oldFails in [false, true]) {
    testWidgets(
      'suspended load cannot ${oldFails ? 'fail' : 'clear'} a newer operation',
      (tester) async {
        final oldSource = media.delayedSource = Completer<Uri>();
        await mountAttachment(tester, media, 'VD');
        await tapAttachment(tester);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        final newSource = media.delayedSource = Completer<Uri>();
        await tapAttachment(tester);
        expect(media.resolutions, 2);
        if (oldFails) {
          newSource.complete(Uri.parse('file:///new'));
          await settleAttachment(tester);
          expect(video.plays, 1);
          oldSource.completeError(StateError('Old download failed'));
          await settleAttachment(tester);
          expect(find.byTooltip('Pause: sample'), findsOneWidget);
          expect(video.disposed, isEmpty);
        } else {
          oldSource.complete(Uri.parse('file:///old'));
          await tester.pump();
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(video.streams, isEmpty);
          newSource.complete(Uri.parse('file:///new'));
          await settleAttachment(tester);
          expect(video.plays, 1);
        }
        expect(tester.takeException(), isNull);
        await unmountAttachment(tester);
      },
    );
  }
}
