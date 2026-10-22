import 'dart:async';
import 'dart:io';

import 'package:collapse/core/theme.dart';
import 'package:collapse/l10n/app_localizations.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/data/media/media_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:collapse/src/presentation/chat/chat_cubit.dart';
import 'package:collapse/src/presentation/chat/chat_screen.dart';
import 'package:collapse/src/presentation/chat/video_metadata.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/attachment_fixture.dart';
import 'support/fake_video_platform.dart';

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  final observers = <WidgetsBindingObserver>{};
  @override
  void addObserver(WidgetsBindingObserver observer) {
    observers.add(observer);
    super.addObserver(observer);
  }

  @override
  bool removeObserver(WidgetsBindingObserver observer) {
    observers.remove(observer);
    return super.removeObserver(observer);
  }
}

class _Media extends AttachmentMedia {
  Completer<Uri>? source;
  String? mime;
  @override
  Future<Uri> playableBytes(Uint8List bytes, String mime) async {
    this.mime = mime;
    return source?.future ?? Uri.parse('file:///metadata.mp4');
  }
}

class _Video extends FakeVideoPlatform {
  Completer<void>? creating, releasing;
  bool failCreate = false;
  Size size = const Size(1080, 1920);
  Duration duration = const Duration(milliseconds: 1234);
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    await creating?.future;
    if (failCreate) throw PlatformException(code: 'create', message: 'Failed');
    return super.createWithOptions(options);
  }

  @override
  void ready(int id) => streams[id]!.add(
    VideoEvent(
      eventType: VideoEventType.initialized,
      size: size,
      duration: duration,
    ),
  );

  @override
  Future<void> dispose(int playerId) async {
    await super.dispose(playerId);
    await releasing?.future;
  }
}

class _Repository implements ChatsRepository {
  @override
  String currentUserId = 'me';
  @override
  int sessionGeneration = 0;
  @override
  Future<ChatTopic?> getTopic(String id) async =>
      ChatTopic(id: id, title: 'Peer');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cubit extends ChatCubit {
  _Cubit(super.repository) {
    emit(const ChatState());
  }
  Object? sent;
  List<PendingUpload>? uploads;
  @override
  Future<void> send(
    Object content, {
    Map<String, dynamic> head = const {},
    List<PendingUpload> uploads = const [],
    bool clearDraft = false,
  }) async {
    sent = content;
    this.uploads = uploads;
  }
}

void main() {
  final binding = _Binding();
  late VideoPlayerPlatform previous;
  late _Video video;
  late _Media media;
  final bytes = Uint8List.fromList([0x1a, 0x45, 0xdf, 0xa3]);
  setUp(() {
    previous = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = video = _Video();
    media = _Media();
  });
  tearDown(() async {
    VideoPlayerPlatform.instance = previous;
    await media.dispose();
  });

  Future<({int width, int height, int duration})?> read() =>
      videoMetadata(bytes, 'video/mp4', media);

  testWidgets('portrait dimensions and milliseconds without playback', (
    tester,
  ) async {
    final result = read();
    await tester.pump();
    expect(await result, (width: 1080, height: 1920, duration: 1234));
    await flushAttachment(tester);
    expect(video.disposed, [0]);
    expect(video.plays, 0);
  });

  testWidgets('decoder failure falls back and releases controller', (
    tester,
  ) async {
    video.delayLoad = true;
    final result = read();
    await tester.pump();
    video.streams[0]!.addError(
      PlatformException(code: 'decode', message: 'Unsupported video'),
    );
    await tester.pump();
    expect(await result, isNull);
    await flushAttachment(tester);
    expect(video.disposed, [0]);
  });

  testWidgets('unknown web duration keeps dimensions with zero duration', (
    tester,
  ) async {
    video.duration = const Duration(milliseconds: -9007199254740990);
    final result = read();
    await tester.pump();
    expect(await result, (width: 1080, height: 1920, duration: 0));
    await flushAttachment(tester);
    expect(video.disposed, [0]);
  });

  testWidgets('native creation error leaves no lifecycle observer behind', (
    tester,
  ) async {
    await tester.pump();
    final observers = Set.of(binding.observers);
    video.failCreate = true;
    final result = read();
    await flushAttachment(tester);
    expect(await result, isNull);
    expect(binding.observers, observers);
    expect(video.streams, isEmpty);
    expect(video.plays, 0);
  });

  testWidgets('initialization timeout is bounded and disposes the player', (
    tester,
  ) async {
    video.delayLoad = true;
    final result = read();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(await result, isNull);
    await flushAttachment(tester);
    expect(video.disposed, [0]);
    expect(video.plays, 0);
  });

  testWidgets('late native creation is disposed without delaying fallback', (
    tester,
  ) async {
    video.creating = Completer<void>();
    final result = read();
    await tester.pump(const Duration(seconds: 3));
    expect(await result, isNull);
    expect(video.streams, isEmpty);
    video.creating!.complete();
    await flushAttachment(tester);
    expect(video.disposed, [0]);
    expect(video.plays, 0);
  });

  testWidgets('late cache source never creates an expired player', (
    tester,
  ) async {
    media.source = Completer<Uri>();
    final result = read();
    await tester.pump(const Duration(seconds: 3));
    expect(await result, isNull);
    media.source!.complete(Uri.parse('file:///late.mp4'));
    await tester.pump();
    expect(video.streams, isEmpty);
  });

  testWidgets('slow native disposal cannot hold the metadata result', (
    tester,
  ) async {
    video.releasing = Completer<void>();
    final result = read();
    await tester.pump();
    expect(await result, isNotNull);
    await flushAttachment(tester);
    expect(video.disposed, [0]);
    video.releasing!.complete();
    await flushAttachment(tester);
  });

  testWidgets('invalid dimensions use fallback and dispose', (tester) async {
    video.size = const Size(double.nan, 0);
    final result = read();
    await tester.pump();
    expect(await result, isNull);
    await flushAttachment(tester);
    expect(video.disposed, [0]);
  });

  for (final changeSession in [false, true]) {
    testWidgets(
      changeSession
          ? 'video metadata completed in a replaced session cannot enqueue'
          : 'video picker stores metadata in canonical durable upload content',
      (tester) async {
        tester.view.physicalSize = const Size(600, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _Repository();
        final cubit = _Cubit(repository);
        final directory = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('collapse-video-metadata-'),
        ))!;
        final file = File('${directory.path}/portrait.webm');
        await tester.runAsync(() => file.writeAsBytes(bytes));
        const picker = MethodChannel('miguelruivo.flutter.plugins.filepicker');
        const recorder = MethodChannel('com.llfbandit.record/messages');
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(recorder, (_) async => null);
        messenger.setMockMethodCallHandler(
          picker,
          (_) async => [
            {'name': 'portrait.webm', 'path': file.path, 'size': bytes.length},
          ],
        );
        video.delayLoad = true;
        try {
          await tester.pumpWidget(
            MultiRepositoryProvider(
              providers: [
                RepositoryProvider<ChatsRepository>.value(value: repository),
                RepositoryProvider<MediaRepository>.value(value: media),
              ],
              child: BlocProvider<ChatCubit>.value(
                value: cubit,
                child: MaterialApp(
                  theme: appTheme(Brightness.light),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: ChatScreen(
                    topicId: 'peer',
                    userId: 'me',
                    title: 'Peer',
                    onProfile: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.attach_file));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Video'));
          await flushAttachment(tester);
          expect(video.streams, hasLength(1));
          expect(media.mime, 'video/webm');
          expect(cubit.sent, isNull);
          if (changeSession) repository.sessionGeneration++;
          video.ready(0);
          await flushAttachment(tester);
          if (changeSession) {
            expect(cubit.sent, isNull);
          } else {
            final entity = ((cubit.sent as Map)['ent'] as List).single as Map;
            expect(entity['tp'], 'VD');
            expect(entity['data'], containsPair('width', 1080));
            expect(entity['data'], containsPair('height', 1920));
            expect(entity['data'], containsPair('duration', 1234));
            expect(entity['data'], containsPair('mime', 'video/webm'));
            expect(cubit.uploads!.single.bytes, bytes);
            expect(cubit.uploads!.single.mime, 'video/webm');
          }
          expect(video.disposed, [0]);
          expect(video.plays, 0);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await cubit.close();
          messenger.setMockMethodCallHandler(picker, null);
          messenger.setMockMethodCallHandler(recorder, null);
          await tester.runAsync(() => directory.delete(recursive: true));
        }
      },
    );
  }
}
