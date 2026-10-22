import 'dart:convert';

import 'package:collapse_tinode/tinode.dart';
import 'package:test/test.dart';

void main() {
  test('preview removes overlapping hidden and quote ranges, not raw data', () {
    final doc = <String, dynamic>{
      'txt': 'secret old new',
      'fmt': [
        {'at': 0, 'len': 7, 'tp': 'HD'},
        {'at': 0, 'len': 11, 'tp': 'QQ'},
      ],
    };
    final original = jsonEncode(doc);
    expect(DraftyCodec.previewText(doc), 'new');
    expect(DraftyCodec.plainText(doc), 'secret old new');
    expect(jsonEncode(doc), original);
    expect(DraftyCodec.forward(doc), doc);
  });

  for (final quoteType in ['QQ', 'QR']) {
    test('preview hides $quoteType quotes and restores grapheme BR offsets',
        () {
      final doc = <String, dynamic>{
        'txt': '👨‍👩‍👧‍👦 old new line',
        'fmt': [
          {'tp': quoteType, 'at': 0, 'len': 5},
          {'tp': 'BR', 'at': 5, 'len': 1},
          {'tp': 'BR', 'at': 9, 'len': 1},
        ],
      };
      expect(DraftyCodec.previewText(doc), 'new\nline');
    });
  }

  test('preview hides media markers with omitted key zero and entity holes',
      () {
    final doc = <String, dynamic>{
      'txt': 'X Y caption',
      'fmt': [
        {'len': 1},
        {'at': 2, 'len': 1, 'key': 2}
      ],
      'ent': [
        {'tp': 'IM'},
        null,
        {'tp': 'AU'}
      ],
    };
    expect(DraftyCodec.previewText(doc), 'caption');
  });

  test('preview ignores malformed hidden ranges and keeps strings literal', () {
    expect(
        DraftyCodec.previewText({
          'txt': 'visible',
          'fmt': [
            {'tp': 'HD', 'at': 'bad', 'len': 1},
            {'tp': 'HD', 'at': 0, 'len': 100},
            {'tp': 'QQ', 'at': -1, 'len': 100},
          ],
        }),
        'visible');
    expect(DraftyCodec.previewText('**literal**'), '**literal**');
  });
}
