import 'package:collapse/src/presentation/chat/message_layout.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _footer = ValueKey('footer');
const _paragraph = ValueKey('paragraph');

Future<void> show(
  WidgetTester tester,
  String text, {
  double width = 200,
  double fontSize = 20,
  Size footer = const Size(40, 20),
  Widget? header,
  InlineSpan? span,
}) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: MessageLayout(
          header: header,
          content: RichText(
            key: _paragraph,
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Ahem',
                fontSize: fontSize,
                height: 1,
              ),
              children: [span ?? TextSpan(text: text)],
            ),
            textWidthBasis: TextWidthBasis.longestLine,
          ),
          footer: SizedBox(
            key: _footer,
            width: footer.width,
            height: footer.height,
          ),
          inlineFooter: true,
        ),
      ),
    ),
  ),
);

void noOverlap(WidgetTester tester) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.byKey(_paragraph),
  );
  final rect = tester.getRect(find.byKey(_footer));
  final length = paragraph.text.toPlainText().length;
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: length),
  );
  for (final box in boxes) {
    expect(
      box.toRect().shift(paragraph.localToGlobal(Offset.zero)).overlaps(rect),
      isFalse,
    );
  }
  final bubble = tester.getRect(find.byType(MessageLayout));
  expect(rect.right, closeTo(bubble.right, .001));
  expect(rect.bottom, closeTo(bubble.bottom, .001));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('one short line grows only by the actual footer and gap', (
    tester,
  ) async {
    await show(tester, 'abc');
    expect(tester.getSize(find.byType(MessageLayout)), const Size(108, 20));
    expect(tester.getTopLeft(find.byKey(_footer)), const Offset(68, 0));
    noOverlap(tester);
  });

  testWidgets('exact fit is inline; fractionally narrower uses a new row', (
    tester,
  ) async {
    await show(tester, 'abcdefg', width: 188);
    expect(tester.getTopLeft(find.byKey(_footer)).dy, 0);
    await show(tester, 'abcdefg', width: 187.99);
    expect(tester.getTopLeft(find.byKey(_footer)).dy, 24);
    expect(tester.getSize(find.byKey(_paragraph)), const Size(140, 20));
    noOverlap(tester);
  });

  testWidgets('full last line never rewraps text to make room for metadata', (
    tester,
  ) async {
    await show(tester, 'abcdefghij');
    expect(tester.getSize(find.byKey(_paragraph)), const Size(200, 20));
    expect(tester.getSize(find.byType(MessageLayout)), const Size(200, 44));
    noOverlap(tester);
  });

  testWidgets(
    'short final line uses free space without narrowing earlier lines',
    (tester) async {
      await show(tester, 'abcdefghij\nab');
      expect(tester.getSize(find.byKey(_paragraph)), const Size(200, 40));
      expect(tester.getTopLeft(find.byKey(_footer)), const Offset(160, 20));
      noOverlap(tester);
    },
  );

  testWidgets('wide header sets bubble width but does not add a footer row', (
    tester,
  ) async {
    await show(tester, 'ab', header: const SizedBox(width: 180, height: 30));
    expect(tester.getSize(find.byType(MessageLayout)), const Size(180, 56));
    expect(tester.getTopLeft(find.byKey(_footer)), const Offset(140, 36));
    noOverlap(tester);
  });

  testWidgets('footer taller than one line also checks preceding visual runs', (
    tester,
  ) async {
    await show(
      tester,
      'abcdefghijklmnopqrst\na',
      fontSize: 10,
      footer: const Size(40, 35),
    );
    expect(tester.getTopLeft(find.byKey(_footer)).dy, 24);
    noOverlap(tester);
  });

  testWidgets('trailing newline provides a genuine empty last line', (
    tester,
  ) async {
    await show(tester, 'abcdefghij\n');
    expect(tester.getTopLeft(find.byKey(_footer)), const Offset(160, 20));
    noOverlap(tester);
  });

  for (final placeholderWidth in [32.0, 180.0]) {
    testWidgets(
      'real placeholder width $placeholderWidth participates in fitting',
      (tester) async {
        await show(
          tester,
          '',
          span: TextSpan(
            children: [
              const TextSpan(text: 'A\n'),
              WidgetSpan(child: SizedBox(width: placeholderWidth, height: 40)),
            ],
          ),
        );
        final text = tester.getRect(find.byKey(_paragraph));
        final metadata = tester.getRect(find.byKey(_footer));
        expect(metadata.top < text.bottom, placeholderWidth == 32);
        noOverlap(tester);
      },
    );
  }
}
