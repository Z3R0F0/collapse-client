import 'package:collapse/src/presentation/chat/attachment_view.dart';
import 'package:collapse/src/presentation/media/media_gallery_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import 'support/attachment_fixture.dart';
import 'support/fake_audio_platform.dart';
import 'support/media_viewer_fixture.dart';

void main() {
  for (final type in ['AU', 'EX']) {
    testWidgets('confirmed inline $type opens through original-message bytes', (
      tester,
    ) async {
      final item = MediaItem(
        topicId: 'usrPeer',
        messageId: 'm2',
        seq: 2,
        entityIndex: 0,
        type: type,
        senderId: 'peer',
        createdAt: DateTime.utc(2026),
        inline: true,
        data: {
          'name': 'inline',
          'mime': type == 'AU' ? 'audio/wav' : 'text/plain',
        },
      );
      final gallery = ViewerCubit([item]);
      final media = ViewerMedia();
      final originalAudio = JustAudioPlatform.instance;
      final audio = FakeAudioPlatform();
      JustAudioPlatform.instance = audio;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const session = MethodChannel('com.ryanheise.audio_session');
      const picker = MethodChannel('miguelruivo.flutter.plugins.filepicker');
      final saved = <Object?>[];
      messenger.setMockMethodCallHandler(session, (_) async => null);
      messenger.setMockMethodCallHandler(picker, (call) async {
        saved.add(call.arguments['bytes']);
        return 'saved';
      });
      try {
        await mountViewer(tester, gallery, media);
        expect(gallery.loads, 0);
        await tester.tap(
          find.descendant(
            of: find.byType(AttachmentView),
            matching: find.byType(InkWell),
          ),
        );
        await settleAttachment(tester);
        expect(gallery.loads, 1);
        if (type == 'AU') {
          expect(audio.players.single.plays, 1);
        } else {
          expect(saved, [viewerPixel]);
        }
        expect(tester.takeException(), isNull);
      } finally {
        await closeViewer(tester, gallery, media);
        JustAudioPlatform.instance = originalAudio;
        messenger.setMockMethodCallHandler(session, null);
        messenger.setMockMethodCallHandler(picker, null);
      }
    });
  }
}
