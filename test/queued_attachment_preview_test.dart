import 'dart:convert';

import 'package:collapse/core/theme.dart';
import 'package:collapse/l10n/app_localizations.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/data/media/media_repository.dart';
import 'package:collapse/src/presentation/chat/drafty_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'support/attachment_fixture.dart';
import 'support/fake_audio_platform.dart';
import 'support/fake_video_platform.dart';
import 'support/pending_attachment_fixture.dart';

const _pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jR1cAAAAASUVORK5CYII=';

void main() {
  late PreviewFixture fixture;
  late FakeAudioPlatform audio;
  late FakeVideoPlatform video;
  late JustAudioPlatform oldAudio;
  late VideoPlayerPlatform oldVideo;
  Uint8List? saved;

  setUp(() {
    fixture = PreviewFixture();
    oldAudio = JustAudioPlatform.instance;
    oldVideo = VideoPlayerPlatform.instance;
    JustAudioPlatform.instance = audio = FakeAudioPlatform();
    VideoPlayerPlatform.instance = video = FakeVideoPlatform();
    saved = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('miguelruivo.flutter.plugins.filepicker'),
      (call) async {
        if (call.method == 'save') {
          saved = (call.arguments as Map)['bytes'] as Uint8List?;
        }
        return null;
      },
    );
  });
  tearDown(() async {
    JustAudioPlatform.instance = oldAudio;
    VideoPlayerPlatform.instance = oldVideo;
    await fixture.dispose();
  });

  Future<void> mount(WidgetTester tester, ChatMessage message) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ChatsRepository>.value(value: fixture.repo),
          RepositoryProvider<MediaRepository>.value(value: fixture.media),
        ],
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(child: DraftyContent(message: message, isMe: true)),
          ),
        ),
      ),
    );
    await settleAttachment(tester);
  }

  Future<ChatMessage> queue(
    WidgetTester tester,
    String type, {
    int count = 1,
    bool thumbnail = false,
  }) async {
    final bytes = type == 'IM'
        ? base64Decode(_pixel)
        : Uint8List.fromList([1, 2, 3]);
    final mime = {
      'IM': 'image/png',
      'AU': 'audio/wav',
      'VD': 'video/mp4',
      'EX': 'application/octet-stream',
    }[type]!;
    final entities = [
      null,
      for (var i = 0; i < count; i++)
        {
          'tp': type,
          'data': {
            'ref': '',
            'mime': mime,
            'name': 'queued',
            if (thumbnail) 'val': _pixel,
          },
        },
    ];
    return (await tester.runAsync(
      () => fixture.queue(
        {'txt': '', 'ent': entities},
        [
          for (var i = 0; i < count; i++)
            PendingUpload(
              entityIndex: i + 1,
              bytes: bytes,
              name: 'queued',
              mime: mime,
            ),
        ],
      ),
    ))!;
  }

  testWidgets(
    'offline SQLite image preview uses original entity index and survives ACK',
    (tester) async {
      final message = await queue(tester, 'IM');
      await mount(tester, message);
      expect(find.byType(Image), findsOneWidget);
      expect(fixture.db.reads, 1);
      expect(fixture.cache.networkReads, 0);
      final state = tester.state(find.byType(AttachmentView));
      final uploaded = {
        'txt': '',
        'ent': [
          null,
          {
            'tp': 'IM',
            'data': {
              'name': 'queued',
              'mime': 'image/png',
              'ref': '/v0/file/s/accepted',
            },
          },
        ],
      };
      final acknowledged = (await tester.runAsync(
        () => fixture.db.mergeMessage(
          'test|me',
          previewMessage(message, seq: 1, content: uploaded),
          'me',
        ),
      ))!;
      await mount(tester, acknowledged);
      expect(
        identical(tester.state(find.byType(AttachmentView)), state),
        isTrue,
      );
      expect(find.byType(Image), findsOneWidget);
      expect(fixture.db.reads, 1);
      expect(fixture.cache.networkReads, 0);
      expect(tester.takeException(), isNull);
      await unmountAttachment(tester);
    },
  );

  testWidgets('thumbnail plus original queued bytes survive ACK offline', (
    tester,
  ) async {
    final message = await queue(tester, 'IM', thumbnail: true);
    await mount(tester, message);
    final original = tester.state(find.byType(AttachmentView));
    final uploaded = {
      'txt': '',
      'ent': [
        null,
        {
          'tp': 'IM',
          'data': {
            'ref': '/v0/file/s/accepted',
            'mime': 'image/png',
            'name': 'queued',
            'val': _pixel,
          },
        },
      ],
    };
    final acknowledged = (await tester.runAsync(
      () => fixture.db.mergeMessage(
        'test|me',
        previewMessage(message, seq: 1, content: uploaded),
        'me',
      ),
    ))!;
    await mount(tester, acknowledged);
    expect(tester.state(find.byType(AttachmentView)), same(original));
    expect(fixture.db.reads, 1);
    expect(fixture.cache.networkReads, 0);
    expect(find.byType(Image), findsOneWidget);
    await unmountAttachment(tester);
  });

  for (final type in ['AU', 'VD']) {
    testWidgets(
      'offline $type playback survives field reorder and upload ACK without restart',
      (tester) async {
        final message = await queue(tester, type);
        await mount(tester, message);
        await tapAttachment(tester);
        expect(type == 'AU' ? audio.players.single.plays : video.plays, 1);
        expect(fixture.cache.writes.single, [1, 2, 3]);
        final state = tester.state(find.byType(AttachmentView));
        final data =
            ((message.content as Map)['ent'] as List)[1]['data'] as Map;
        final reordered = {
          'txt': '',
          'ent': [
            null,
            {
              'tp': type,
              'data': {'name': data['name'], 'mime': data['mime'], 'ref': ''},
            },
          ],
        };
        await mount(tester, previewMessage(message, content: reordered));
        expect(
          identical(tester.state(find.byType(AttachmentView)), state),
          isTrue,
        );
        final uploaded = {
          'txt': '',
          'ent': [
            null,
            {
              'tp': type,
              'data': {
                'name': data['name'],
                'mime': data['mime'],
                'ref': '/v0/file/s/accepted',
              },
            },
          ],
        };
        final acknowledged = (await tester.runAsync(
          () => fixture.db.mergeMessage(
            'test|me',
            previewMessage(message, seq: 1, content: uploaded),
            'me',
          ),
        ))!;
        await mount(tester, acknowledged);
        expect(
          identical(tester.state(find.byType(AttachmentView)), state),
          isTrue,
        );
        expect(type == 'AU' ? audio.players.length : video.streams.length, 1);
        expect(
          type == 'AU'
              ? audio.players.single.disposed
              : video.disposed.isNotEmpty,
          isFalse,
        );
        expect(fixture.db.reads, 1);
        expect(fixture.cache.networkReads, 0);
        await unmountAttachment(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'offline file preview passes durable bytes to normal save dialog',
    (tester) async {
      final message = await queue(tester, 'EX');
      await mount(tester, message);
      await tapAttachment(tester);
      expect(saved, [1, 2, 3]);
      expect(fixture.db.reads, 1);
      expect(fixture.cache.networkReads, 0);
      await unmountAttachment(tester);
    },
  );

  testWidgets('identical entities have distinct stable widget keys', (
    tester,
  ) async {
    final message = await queue(tester, 'IM', count: 2);
    await mount(tester, message);
    expect(find.byType(AttachmentView), findsNWidgets(2));
    expect(find.byType(Image), findsNWidgets(2));
    final keys = tester
        .widgetList<AttachmentView>(find.byType(AttachmentView))
        .map((view) => view.key)
        .toSet();
    expect(keys, hasLength(2));
    expect(fixture.db.reads, 2);
    expect(tester.takeException(), isNull);
    await unmountAttachment(tester);
  });

  testWidgets('non-list malformed entities do not crash the content widget', (
    tester,
  ) async {
    final message = await queue(tester, 'EX');
    await mount(
      tester,
      previewMessage(
        message,
        content: {
          'txt': 'safe',
          'ent': {'bad': true},
        },
      ),
    );
    expect(find.text('safe'), findsOneWidget);
    expect(find.byType(AttachmentView), findsNothing);
    expect(tester.takeException(), isNull);
    await unmountAttachment(tester);
  });
}
