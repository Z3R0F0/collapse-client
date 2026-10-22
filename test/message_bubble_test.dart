import 'package:collapse/core/theme.dart';
import 'package:collapse/l10n/app_localizations.dart';
import 'package:collapse/src/data/media/media_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:collapse/src/presentation/chat/drafty_content.dart';
import 'package:collapse/src/presentation/chat/drafty_spoiler.dart';
import 'package:collapse/src/presentation/chat/message_footer.dart';
import 'package:collapse_tinode/tinode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/attachment_fixture.dart';

const _pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jR1cAAAAASUVORK5CYII=';

void main() {
  late AttachmentMedia media;
  setUp(() => media = AttachmentMedia());
  tearDown(() => media.dispose());

  Future<void> show(
    WidgetTester tester,
    Object content, {
    double width = 280,
    double scale = 1,
    Delivery delivery = Delivery.sent,
    Map<String, dynamic> head = const {},
    VoidCallback? onReply,
    TextDirection direction = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      RepositoryProvider<MediaRepository>.value(
        value: media,
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  alwaysUse24HourFormat: true,
                ),
                child: Directionality(
                  textDirection: direction,
                  child: SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: width,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: DraftyContent(
                            message: ChatMessage(
                              id: 'stable',
                              topicId: 'usrPeer',
                              seq: 10,
                              localSeq: 1,
                              senderId: 'me',
                              createdAt: DateTime(2026, 9, 22, 13, 45),
                              content: content,
                              head: head,
                              delivery: delivery,
                            ),
                            isMe: true,
                            onReply: onReply,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<Rect> boxes(WidgetTester tester, String text) {
    final rich = find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == text,
    );
    expect(rich, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(rich);
    return paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.length),
        )
        .map((box) => box.toRect().shift(paragraph.localToGlobal(Offset.zero)))
        .toList();
  }

  Rect footer(WidgetTester tester) =>
      tester.getRect(find.byType(MessageFooter));

  void bounded(WidgetTester tester, double width) {
    final bubble = tester.getRect(find.byType(DraftyContent));
    final metadata = footer(tester);
    expect(bubble.width, lessThanOrEqualTo(width + .01));
    expect(metadata.left, greaterThanOrEqualTo(bubble.left));
    expect(metadata.right, lessThanOrEqualTo(bubble.right));
    expect(metadata.bottom, lessThanOrEqualTo(bubble.bottom));
    expect(tester.takeException(), isNull);
  }

  testWidgets('short text and real timestamp/status share the last line', (
    tester,
  ) async {
    await show(tester, 'Hi');
    final line = boxes(tester, 'Hi').single;
    final metadata = footer(tester);
    expect(metadata.top, lessThan(line.bottom));
    expect(metadata.bottom, greaterThan(line.top));
    expect(metadata.left, greaterThan(line.right));
    bounded(tester, 280);
  });

  testWidgets(
    'a full final text line puts metadata below without overlapping',
    (tester) async {
      const text = 'WWWWWWWWWWWW';
      await show(tester, text);
      final lines = boxes(tester, text);
      expect(lines.map((box) => box.top).toSet(), hasLength(1));
      expect(footer(tester).top, greaterThanOrEqualTo(lines.last.bottom));
      bounded(tester, 280);
    },
  );

  for (final scale in [1.0, 2.0, 3.0]) {
    for (final direction in TextDirection.values) {
      testWidgets(
        'formatted emoji/bidi stays inside local bounds at $scale/$direction',
        (tester) async {
          final doc = DraftyCodec.markdown(
            '**Hello** 👨‍👩‍👧‍👦 é שלום مرحبا',
          );
          await show(
            tester,
            doc,
            width: 240,
            scale: scale,
            direction: direction,
          );
          final text = DraftyCodec.plainText(doc);
          for (final glyph in boxes(tester, text)) {
            expect(glyph.overlaps(footer(tester)), isFalse);
          }
          bounded(tester, 240);
        },
      );
    }
  }

  testWidgets(
    'reply and forward headers stay inside the bubble and keep footer right aligned',
    (tester) async {
      var replies = 0;
      await show(
        tester,
        'Hi',
        head: {'reply': 7, 'forwarded': true},
        onReply: () => replies++,
      );
      final metadata = footer(tester);
      final bubble = tester.getRect(find.byType(DraftyContent));
      expect(metadata.right, closeTo(bubble.right - 14, 1));
      final replying = find.text('Replying to a message');
      expect(replying, findsOneWidget);
      expect(
        find.descendant(of: find.byType(DraftyContent), matching: replying),
        findsOneWidget,
      );
      await tester.tap(replying);
      expect(replies, 1);
      expect(
        tester.getRect(find.text('Forwarded message')).bottom,
        lessThanOrEqualTo(boxes(tester, 'Hi').single.top),
      );
      bounded(tester, 280);
    },
  );

  for (final type in ['IM', 'EX']) {
    testWidgets('$type has a separate footer below its attachment', (
      tester,
    ) async {
      await show(tester, {
        'txt': ' ',
        'fmt': [
          {'at': 0, 'len': 1, 'key': 0},
        ],
        'ent': [
          {
            'tp': type,
            'data': {
              'val': type == 'IM' ? _pixel : 'AQID',
              'mime': type == 'IM' ? 'image/png' : 'application/octet-stream',
              'name': type == 'IM' ? 'photo.png' : 'document.pdf',
            },
          },
        ],
      });
      expect(
        footer(tester).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byType(AttachmentView)).bottom,
        ),
      );
      if (type == 'IM') expect(find.byType(Image), findsOneWidget);
      bounded(tester, 280);
    });
  }

  testWidgets(
    'same-ID queued to read keeps size and an already revealed spoiler',
    (tester) async {
      final doc = DraftyCodec.markdown(
        'before ||**secret** 👨‍👩‍👧‍👦|| after',
      );
      await show(tester, doc, delivery: Delivery.queued);
      final size = tester.getSize(find.byType(DraftyContent));
      final metadata = footer(tester);
      final spoiler = tester.getRect(find.byType(DraftySpoiler));
      await tester.tap(find.byType(DraftySpoiler));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(DraftyContent)), size);
      await show(tester, doc, delivery: Delivery.read);
      expect(tester.getSize(find.byType(DraftyContent)), size);
      expect(footer(tester), metadata);
      expect(tester.getRect(find.byType(DraftySpoiler)), spoiler);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );
      expect(find.byTooltip('Read'), findsOneWidget);
      bounded(tester, 280);
    },
  );
}
