import 'dart:convert';

import 'package:collapse_tinode/tinode.dart';
import 'package:test/test.dart';

void main() {
  const link = {
    'tp': 'LN',
    'data': {'url': 'https://example.com'}
  };

  test('safe views supply omitted defaults without shifting entity slots', () {
    final doc = <String, dynamic>{
      'txt': 'link',
      'fmt': [
        {'len': 4},
        {'len': 4, 'key': 2},
        {'tp': 'ST'}
      ],
      'ent': [link, null, link],
    };
    expect(DraftyCodec.formats(doc), [
      {'at': 0, 'len': 4, 'key': 0},
      {'at': 0, 'len': 4, 'key': 2},
      {'at': 0, 'len': 0, 'tp': 'ST'},
    ]);
    expect(DraftyCodec.entity(doc, 1), isNull);
    expect(DraftyCodec.entity(doc, 2), link);
    expect(() => DraftyCodec.entity(doc, 2)!['tp'] = 'other',
        throwsUnsupportedError);
  });

  test('malformed ranges and entities are ignored without rewriting raw JSON',
      () {
    final doc = <String, dynamic>{
      'txt': 'text',
      'extra': {'future': true},
      'fmt': [
        null,
        1,
        {'tp': 'HD', 'at': 'bad', 'len': 1},
        {'tp': 'ST', 'at': 1.5, 'len': 1},
        {'tp': 'ST', 'at': -2, 'len': 1},
        {'tp': 'ST', 'at': 0, 'len': -1},
        {'tp': 'ST', 'at': 3, 'len': 2},
        {'tp': 1, 'len': 1},
        {'key': 1, 'len': 1},
        {'key': 'bad', 'len': 1},
        {'key': 100, 'len': 1},
        {'tp': 'FUTURE', 'len': 4, 'custom': 'preserved'},
      ],
      'ent': [link, null],
    };
    final original = jsonEncode(doc);
    expect(DraftyCodec.formats(doc), [
      {'at': 0, 'len': 4, 'tp': 'FUTURE'}
    ]);
    expect(DraftyCodec.plainText(doc), 'text');
    expect(DraftyCodec.decode(doc), doc);
    expect(DraftyCodec.forward(doc), doc);
    expect(jsonEncode(doc), original);
  });

  test('reply shifts default entity key zero and preserves entity holes', () {
    final reply = DraftyCodec.reply(
      content: {
        'txt': 'link',
        'fmt': [
          {'len': 4, 'key': 1}
        ],
        'ent': [null, link],
      },
      quote: {
        'txt': 'quote',
        'fmt': [
          {'len': 5}
        ],
        'ent': [link],
      },
      authorId: 'usrA',
      authorName: 'A',
    );
    expect((reply['ent'] as List)[2], isNull);
    expect(
        DraftyCodec.formats(reply).where((item) => item.containsKey('key')), [
      {'at': 0, 'len': 1, 'key': 0},
      {'at': 2, 'len': 5, 'key': 1},
      {'at': 8, 'len': 4, 'key': 3},
    ]);
  });
}
