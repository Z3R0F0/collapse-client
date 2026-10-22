import 'package:collapse_tinode/tinode.dart';
import 'package:test/test.dart';

void main() {
  // Fixtures verified against tinode-js v0.25.1 parse()/quote(), not UTF-16.
  for (final cluster in ['👨‍👩‍👧‍👦', '👍🏽', '🇷🇺', 'e\u0301']) {
    test('line break and strong ranges count $cluster as one grapheme', () {
      final doc = DraftyCodec.text('A$cluster\nB');
      expect(doc, {
        'txt': 'A$cluster B',
        'fmt': [
          {'tp': 'BR', 'len': 1, 'at': 2}
        ],
      });
      expect(DraftyCodec.plainText(doc), 'A$cluster\nB');
      expect(DraftyCodec.markdown('**$cluster**'), {
        'txt': cluster,
        'fmt': [
          {'tp': 'ST', 'at': 0, 'len': 1}
        ],
      });
    });
  }

  test('style starting inside a combined grapheme matches Tinode mapping', () {
    expect(DraftyCodec.markdown('e**\u0301**'), {
      'txt': 'e\u0301',
      'fmt': [
        {'tp': 'ST', 'at': 0, 'len': 1}
      ],
    });
  });

  test('reply emits the pinned Tinode QQ quote and grapheme offsets', () {
    final reply = DraftyCodec.reply(
      content: 'next',
      quote: DraftyCodec.markdown('**bold**'),
      authorId: 'usrA',
      authorName: '👨‍👩‍👧‍👦',
    );
    expect(reply['txt'], '👨‍👩‍👧‍👦 bold next');
    expect(reply['fmt'], [
      {'at': 0, 'len': 1, 'key': 0},
      {'at': 1, 'len': 1, 'tp': 'BR'},
      {'at': 2, 'len': 4, 'tp': 'ST'},
      {'at': 0, 'len': 6, 'tp': 'QQ'},
      {'at': 6, 'len': 1, 'tp': 'BR'},
    ]);
  });
}
