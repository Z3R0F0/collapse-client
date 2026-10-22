import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collapse/core/theme.dart';
import 'package:collapse/l10n/app_localizations.dart';
import 'package:collapse/src/data/media/media_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:collapse/src/presentation/chat/drafty_content.dart';
import 'package:collapse/src/presentation/chat/image_dimensions.dart';
import 'package:collapse/src/presentation/chat/message_header.dart';
import 'package:collapse/src/presentation/chat/message_footer.dart';
import 'package:collapse_tinode/tinode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/attachment_fixture.dart';

const _pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jR1cAAAAASUVORK5CYII=';

JsonMap _photo(String name, {int? width, int? height}) {
  final doc = DraftyCodec.media(
    type: 'IM',
    ref: '',
    name: name,
    mime: 'image/png',
    size: 68,
    width: width,
    height: height,
  );
  (doc['ent'] as List).first['data']['val'] = _pixel;
  return doc;
}

void main() {
  late AttachmentMedia media;
  setUp(() => media = AttachmentMedia());
  tearDown(() => media.dispose());

  Future<void> mount(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      RepositoryProvider<MediaRepository>.value(
        value: media,
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 390,
                child: Align(alignment: Alignment.topLeft, child: child),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Widget content(
    Object doc, {
    Map<String, dynamic> head = const {},
    VoidCallback? onReply,
    ValueChanged<int>? onPreview,
  }) => DraftyContent(
    message: ChatMessage(
      id: 'stable',
      topicId: 'usrPeer',
      seq: 5,
      localSeq: 0,
      senderId: 'usrPeer',
      createdAt: DateTime(2026, 9, 22),
      content: doc,
      head: head,
      delivery: Delivery.sent,
    ),
    isMe: false,
    onReply: onReply,
    onPreview: onPreview,
    heroTagFor: (index) => 'media:$index',
  );

  testWidgets('reply renders quoted photo as excerpt, only body photo opens', (
    tester,
  ) async {
    var replied = 0;
    int? opened;
    final doc = DraftyCodec.reply(
      content: _photo('body.png'),
      quote: _photo('quoted.png'),
      authorId: 'usrAlice',
      authorName: 'Alice',
    );
    await mount(
      tester,
      content(
        doc,
        head: {'reply': '1'},
        onReply: () => replied++,
        onPreview: (index) => opened = index,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('quoted.png'), findsOneWidget);
    expect(find.byType(AttachmentView), findsOneWidget);
    final attachment = tester.widget<AttachmentView>(
      find.byType(AttachmentView),
    );
    expect(attachment.key, const ValueKey(('stable', 2)));
    expect(attachment.heroTag, 'media:2');
    await tester.tap(find.byType(MessageHeader));
    expect(replied, 1);
    await tester.tap(find.byType(Image));
    expect(opened, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('text reply does not expand quoted media or leak hidden text', (
    tester,
  ) async {
    final quote = DraftyCodec.markdown('visible ||secret👩🏽‍💻||');
    await mount(
      tester,
      content(
        DraftyCodec.reply(
          content: 'answer',
          quote: quote,
          authorId: 'usrAlice',
          authorName: 'Alice',
        ),
        head: {'reply': 1},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('visible'), findsOneWidget);
    expect(find.textContaining('secret', findRichText: true), findsNothing);
    expect(find.text('answer', findRichText: true), findsOneWidget);
    expect(find.byType(AttachmentView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forward keeps actual message and does not invent an author', (
    tester,
  ) async {
    await mount(
      tester,
      content('forwarded body', head: {'forwarded': 'grpOrigin:5'}),
    );
    await tester.pumpAndSettle();
    expect(find.text('Forwarded message'), findsOneWidget);
    expect(find.text('forwarded body', findRichText: true), findsOneWidget);
    expect(find.textContaining('grpOrigin'), findsNothing);
  });

  for (final dimensions in [(100, 400), (400, 100), (null, null)]) {
    testWidgets(
      'media bubble fits metadata $dimensions without decoder shift',
      (tester) async {
        final delayed = Completer<Uint8List?>();
        await mount(
          tester,
          AttachmentView(
            type: 'IM',
            data: {
              'name': 'pending.png',
              'mime': 'image/png',
              if (dimensions.$1 != null) 'width': dimensions.$1,
              if (dimensions.$2 != null) 'height': dimensions.$2,
            },
            pendingBytes: () => delayed.future,
            heroTag: 'pending-photo',
          ),
        );
        final before = tester.getSize(find.byType(AttachmentView));
        expect(find.byType(Hero), findsOneWidget);
        expect(before, switch (dimensions) {
          (100, 400) => const Size(80, 320),
          (400, 100) => const Size(320, 80),
          _ => const Size(240, 180),
        });
        delayed.complete(base64Decode(_pixel));
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(AttachmentView)), before);
        expect(find.byType(Image), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('portrait media-only bubble has no large horizontal blank band', (
    tester,
  ) async {
    await mount(tester, content(_photo('portrait', width: 100, height: 400)));
    await tester.pumpAndSettle();
    final bubble = tester.getSize(find.byType(DraftyContent));
    final image = tester.getSize(find.byType(Image));
    expect(image, const Size(80, 320));
    final footer = tester.getSize(find.byType(MessageFooter));
    expect(bubble.width, closeTo(math.max(image.width, footer.width) + 14, .1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('video preview tap is separate from inline playback control', (
    tester,
  ) async {
    var opened = 0;
    await mount(
      tester,
      AttachmentView(
        type: 'VD',
        data: {'name': 'clip', 'ref': '/v0/file/s/clip'},
        onPreview: () => opened++,
        heroTag: 'video',
      ),
    );
    await tester.tap(find.byIcon(Icons.videocam_outlined));
    expect(opened, 1);
    expect(find.byTooltip('Play: clip'), findsOneWidget);
    expect(media.resolutions, 0);
    expect(find.byType(Hero), findsOneWidget);
  });

  testWidgets(
    'image metadata uses encoded header and unsupported bytes fall back',
    (tester) async {
      final dimensions = await tester.runAsync(
        () => imageDimensions(base64Decode(_pixel)),
      );
      expect(dimensions, (width: 1, height: 1));
      final invalid = await tester.runAsync(
        () => imageDimensions(Uint8List.fromList([1, 2, 3])),
      );
      expect(invalid, isNull);
    },
  );
}
