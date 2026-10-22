import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'support/attachment_fixture.dart';
import 'support/fake_audio_platform.dart';

void main() {
  late AttachmentMedia media;
  late FakeAudioPlatform audio;
  late JustAudioPlatform original;
  setUp(() {
    original = JustAudioPlatform.instance;
    audio = FakeAudioPlatform();
    JustAudioPlatform.instance = audio;
    media = AttachmentMedia();
  });
  tearDown(() async {
    JustAudioPlatform.instance = original;
    await media.dispose();
  });

  testWidgets('retained inactive pane pauses audio and never auto-resumes', (
    tester,
  ) async {
    final activity = ValueNotifier(true);
    addTearDown(activity.dispose);
    await mountAttachment(tester, media, 'AU', activity: activity);
    await tapAttachment(tester);
    final player = audio.players.single;
    activity.value = false;
    await settleAttachment(tester);
    expect(player.pauses, 1);
    activity.value = true;
    await settleAttachment(tester);
    expect(player.plays, 1);
    await tapAttachment(tester);
    expect(player.plays, 2);
    expect(audio.players.single, same(player));
    await unmountAttachment(tester);
  });

  testWidgets('late audio load cannot play after its pane was hidden', (
    tester,
  ) async {
    final activity = ValueNotifier(true);
    addTearDown(activity.dispose);
    audio.delayLoad = true;
    await mountAttachment(tester, media, 'AU', activity: activity);
    await tapAttachment(tester);
    final player = audio.players.single;
    activity.value = false;
    await flushAttachment(tester);
    activity.value = true;
    player.loaded.complete();
    await settleAttachment(tester);
    expect(player.plays, 0);
    expect(player.disposed, isTrue);
    await unmountAttachment(tester);
  });

  testWidgets('audio pauses when hidden and resumes only after another tap', (
    tester,
  ) async {
    await mountAttachment(tester, media, 'AU');
    await tapAttachment(tester);
    expect(audio.players.single.plays, 1);
    expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);
    expect(find.byTooltip('Pause: sample'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await settleAttachment(tester);
    expect(audio.players.single.pauses, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleAttachment(tester);
    expect(audio.players.single.plays, 1);
    // Hidden apps do not paint frames. The resumed control must reflect pause
    // before the user taps it; resume itself must never restart playback.
    expect(find.byTooltip('Play: sample'), findsOneWidget);
    await tapAttachment(tester);
    expect(audio.players.single.plays, 2);
    expect(media.resolutions, 1);
    await unmountAttachment(tester);
    expect(audio.players.single.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed audio replays with one tap, without resolving again', (
    tester,
  ) async {
    await mountAttachment(tester, media, 'AU');
    await tapAttachment(tester);
    audio.players.single.complete();
    await settleAttachment(tester);
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    await tapAttachment(tester);
    expect(audio.players.single.seeks, 1);
    expect(audio.players.single.plays, 2);
    expect(media.resolutions, 1);
    await unmountAttachment(tester);
  });

  testWidgets(
    'audio playback rejection shows Retry and releases broken player',
    (tester) async {
      audio.rejectPlay = true;
      await mountAttachment(tester, media, 'AU');
      await tapAttachment(tester);
      await settleAttachment(tester);
      expect(audio.players.single.disposed, isTrue);
      expect(find.byTooltip('Retry: sample'), findsOneWidget);
      expect(tester.takeException(), isNull);
      audio.rejectPlay = false;
      await tapAttachment(tester);
      expect(audio.players, hasLength(2));
      expect(audio.players.last.plays, 1);
      expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);
      await unmountAttachment(tester);
    },
  );

  testWidgets(
    'late audio initialization cannot auto-play after hidden and resumed',
    (tester) async {
      audio.delayLoad = true;
      await mountAttachment(tester, media, 'AU');
      await tapAttachment(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      audio.players.single.loaded.complete();
      await settleAttachment(tester);
      expect(audio.players.single.plays, 0);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      audio.delayLoad = false;
      await tapAttachment(tester);
      expect(audio.players.last.plays, 1);
      expect(audio.players.first.disposed, isTrue);
      await unmountAttachment(tester);
    },
  );

  testWidgets(
    'audio initialization timeout leaves a retryable, non-loading control',
    (tester) async {
      audio.delayLoad = true;
      await mountAttachment(tester, media, 'AU');
      await tapAttachment(tester);
      await tester.pump(const Duration(seconds: 31));
      await settleAttachment(tester);
      expect(find.byTooltip('Retry: sample'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      audio.players.single.loaded.complete();
      await settleAttachment(tester);
      expect(audio.players.single.plays, 0);
      expect(tester.takeException(), isNull);
      audio.delayLoad = false;
      await tapAttachment(tester);
      expect(audio.players.last.plays, 1);
      await unmountAttachment(tester);
    },
  );

  testWidgets(
    'opening another route pauses audio without auto-playing on return',
    (tester) async {
      await mountAttachment(tester, media, 'AU');
      await tapAttachment(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final route = MaterialPageRoute<void>(builder: (_) => const Scaffold());
      navigator.push(route);
      await settleAttachment(tester);
      expect(audio.players.single.pauses, 1);
      navigator.pop();
      await settleAttachment(tester);
      expect(audio.players.single.plays, 1);
      await unmountAttachment(tester);
    },
  );

  testWidgets('audio stream error releases a pending load immediately', (
    tester,
  ) async {
    audio.delayLoad = true;
    await mountAttachment(tester, media, 'AU');
    await tapAttachment(tester);
    final old = audio.players.single;
    old.event(ProcessingStateMessage.loading, errorCode: 1);
    await flushAttachment(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byTooltip('Retry: sample'), findsOneWidget);
    audio.delayLoad = false;
    await tapAttachment(tester);
    expect(audio.players.last.plays, 1);
    old.loaded.complete();
    await settleAttachment(tester);
    expect(find.byTooltip('Pause: sample'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmountAttachment(tester);
  });
}
