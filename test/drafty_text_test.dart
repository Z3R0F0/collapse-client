import 'package:collapse/core/theme.dart';
import 'package:collapse/src/presentation/chat/drafty_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<TextSpan> render(WidgetTester tester, Object content) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: Scaffold(body: DraftyText(content: content)),
    ),
  );
  final text = tester.widget<Text>(
    find.descendant(of: find.byType(DraftyText), matching: find.byType(Text)),
  );
  return text.textSpan! as TextSpan;
}

void main() {
  testWidgets('overlapping styles end independently', (tester) async {
    final span = await render(tester, {
      'txt': 'abcd',
      'fmt': [
        {'at': 0, 'len': 2, 'tp': 'ST'},
        {'at': 1, 'len': 2, 'tp': 'EM'},
      ],
    });
    final children = span.children!.cast<TextSpan>();
    expect(children.map((s) => s.text), ['a', 'b', 'c', 'd']);
    expect(children.elementAt(1).style!.fontWeight, FontWeight.bold);
    expect(children.elementAt(1).style!.fontStyle, FontStyle.italic);
    expect(children.elementAt(2).style!.fontWeight, isNot(FontWeight.bold));
    expect(children.elementAt(2).style!.fontStyle, FontStyle.italic);
    expect(children.last.style!.fontStyle, isNot(FontStyle.italic));
  });

  testWidgets('incoming strings stay literal rather than parsing Markdown', (
    tester,
  ) async {
    final span = await render(tester, '**literal** <b>text</b>');
    expect(span.toPlainText(), '**literal** <b>text</b>');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'omitted entity key resolves index zero without reindexing holes',
    (tester) async {
      var span = await render(tester, {
        'txt': 'link',
        'fmt': [
          {'len': 4},
        ],
        'ent': [
          {
            'tp': 'LN',
            'data': {'url': 'https://example.com'},
          },
        ],
      });
      expect((span.children!.single as TextSpan).recognizer, isNotNull);
      span = await render(tester, {
        'txt': 'link',
        'fmt': [
          {'len': 4, 'key': 1},
        ],
        'ent': [
          null,
          {
            'tp': 'LN',
            'data': {'url': 'https://example.com'},
          },
        ],
      });
      expect((span.children!.single as TextSpan).recognizer, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('grapheme ranges never split composed emoji or combining text', (
    tester,
  ) async {
    final span = await render(tester, {
      'txt': '👩‍💻 e\u0301 🇷🇺!',
      'fmt': [
        {'at': 0, 'len': 1, 'tp': 'ST'},
        {'at': 2, 'len': 1, 'tp': 'EM'},
        {'at': 4, 'len': 1, 'tp': 'CO'},
      ],
    });
    final children = span.children!.cast<TextSpan>();
    expect(children.first.text, '👩‍💻');
    expect(children.first.style!.fontWeight, FontWeight.bold);
    expect(
      children.singleWhere((s) => s.text == 'e\u0301').style!.fontStyle,
      FontStyle.italic,
    );
    expect(
      children.singleWhere((s) => s.text == '🇷🇺').style!.fontFamily,
      'IBMPlexMono',
    );
    expect(span.toPlainText(), '👩‍💻 e\u0301 🇷🇺!');
  });

  testWidgets('hidden ranges and media placeholders are not visible text', (
    tester,
  ) async {
    final span = await render(tester, {
      'txt': 'secret X body',
      'fmt': [
        {'at': 0, 'len': 7, 'tp': 'HD'},
        {'at': 7, 'len': 1, 'key': 0},
      ],
      'ent': [
        {
          'tp': 'IM',
          'data': {'ref': '/v0/file/s/image'},
        },
      ],
    });
    expect(span.toPlainText(), ' body');
    expect(tester.takeException(), isNull);
  });

  testWidgets('canonical and legacy quotes render alike with line breaks', (
    tester,
  ) async {
    for (final type in ['QQ', 'QR']) {
      final span = await render(tester, {
        'txt': 'quote body',
        'fmt': [
          {'at': 0, 'len': 5, 'tp': type},
          {'at': 5, 'len': 1, 'tp': 'BR'},
        ],
      });
      expect(span.toPlainText(), 'quote\nbody');
      expect(
        (span.children!.first as TextSpan).style!.fontStyle,
        FontStyle.italic,
      );
    }
  });

  testWidgets(
    'malformed or unsafe formats fail closed without crashing the bubble',
    (tester) async {
      for (final content in [
        {'txt': 'safe', 'fmt': 'not a list', 'ent': 42},
        {
          'txt': 'safe',
          'fmt': [
            null,
            {'at': 'bad', 'len': 4, 'tp': 'HD'},
            {'at': -2, 'len': 4, 'tp': 'ST'},
            {'at': 0, 'len': 100, 'tp': 'HD'},
            {'at': 1.5, 'len': 1, 'tp': 'ST'},
            {'at': 0, 'len': 4, 'key': 20},
          ],
          'ent': [null],
        },
        {
          'txt': 'safe',
          'fmt': [
            {'len': 4},
          ],
          'ent': [
            {
              'tp': 'LN',
              'data': {'url': 'javascript:alert(1)'},
            },
          ],
        },
      ]) {
        final span = await render(tester, content);
        expect(span.toPlainText(), 'safe');
        expect(
          span.children!.cast<TextSpan>().every((s) => s.recognizer == null),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
