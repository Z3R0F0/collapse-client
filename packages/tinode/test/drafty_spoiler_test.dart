import 'dart:convert';

import 'package:collapse_tinode/tinode.dart';
import 'package:test/test.dart';

void main() {
  test('copy restores text/newlines, previews and replies never reveal it', () {
    final doc = DraftyCodec.markdown(
      'before ||**secret 👩‍💻** [link](https://secret.example)|| after\nnext',
    );
    final original = jsonEncode(doc);
    expect(DraftyCodec.copyText(doc), 'before secret 👩‍💻 link after\nnext');
    expect(DraftyCodec.previewText(doc), 'before  after\nnext');
    expect(DraftyCodec.plainText(doc), isNot(contains('secret')));
    final reply = DraftyCodec.reply(
      content: 'answer',
      quote: doc,
      authorId: 'usrA',
      authorName: 'A',
    );
    expect(jsonEncode(reply), isNot(contains('secret')));
    expect(DraftyCodec.forward(doc), doc);
    expect(jsonEncode(doc), original);
  });

  test('copy restores formatted block line breaks', () {
    final doc =
        DraftyCodec.markdown('```dart\nvoid main() {\n  run();\n}\n```');
    expect(DraftyCodec.copyText(doc), 'void main() {\n  run();\n}');
  });

  test('malformed hidden payloads cannot opt into reveal', () {
    for (final payload in [
      null,
      true,
      'secret',
      {'txt': 'too long'},
      {'txt': 5}
    ]) {
      final doc = <String, dynamic>{
        'txt': '••',
        'fmt': [
          {'at': 0, 'len': 2, 'key': 0}
        ],
        'ent': [
          {
            'tp': 'HD',
            'data': {'spoiler': payload}
          }
        ],
      };
      expect(DraftyCodec.spoiler(doc, DraftyCodec.formats(doc).single), isNull);
      expect(DraftyCodec.copyText(doc), '••');
      expect(DraftyCodec.previewText(doc), '');
    }
  });

  test('untrusted recursive fragments are bounded', () {
    var doc = <String, dynamic>{'txt': 'x'};
    for (var i = 0; i < 20; i++) {
      doc = {
        'txt': '•',
        'fmt': [
          {'at': 0, 'len': 1, 'key': 0}
        ],
        'ent': [
          {
            'tp': 'HD',
            'data': {'spoiler': doc}
          }
        ],
      };
    }
    expect(DraftyCodec.copyText(doc), '•');
  });

  test('overlapping hidden ranges cannot shift after joining emoji graphemes',
      () {
    final doc = <String, dynamic>{
      'txt': '•••',
      'fmt': [
        {'at': 1, 'len': 2, 'key': 0},
        {'at': 0, 'len': 3, 'key': 1},
      ],
      'ent': [
        {
          'tp': 'HD',
          'data': {
            'spoiler': {
              'txt': '🇺•',
              'fmt': [
                {'at': 1, 'len': 1, 'key': 0}
              ],
              'ent': [
                {
                  'tp': 'HD',
                  'data': {
                    'spoiler': {'txt': '🇳'}
                  }
                }
              ],
            }
          }
        },
        {
          'tp': 'HD',
          'data': {
            'spoiler': {'txt': 'abc'}
          }
        },
      ],
    };
    expect(DraftyCodec.copyText(doc), 'abc');
  });

  test('received CR followed by BR preserves original formatting offsets', () {
    expect(
        DraftyCodec.copyText({
          'txt': '\r •',
          'fmt': [
            {'tp': 'BR', 'at': 1, 'len': 1},
            {'at': 2, 'len': 1, 'key': 0},
          ],
          'ent': [
            {
              'tp': 'HD',
              'data': {
                'spoiler': {'txt': 's'}
              }
            }
          ],
        }),
        '\r\ns');
  });
}
