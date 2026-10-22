import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:collapse_tinode/tinode.dart';
import 'package:test/test.dart';

JsonMap quote(Object value, {Object content = ''}) => DraftyCodec.reply(
    content: content, quote: value, authorId: 'usrA', authorName: 'A');

void main() {
  test('hundreds of rich replies do not recursively retain previous quotes',
      () {
    Object message = 'start';
    for (var i = 0; i < 200; i++) {
      message = quote(message,
          content: DraftyCodec.markdown('**Reply $i** ${'x' * 1024}'));
      final doc = message as JsonMap;
      expect(utf8.encode(jsonEncode(doc)).length, lessThan(4096));
      expect(
          DraftyCodec.formats(doc).where((f) => f['tp'] == 'QQ'), hasLength(1));
      expect(
          DraftyCodec.formats(doc).where((f) => f['tp'] == 'ST'), isNotEmpty);
    }
  });

  test(
      'quote removes hidden ranges and remaps grapheme styles and entity holes',
      () {
    final source = DraftyCodec.markdown(
        '**👨‍👩‍👧‍👦 e\u0301** [site](https://example.com)');
    (source['fmt'] as List).add({'tp': 'HD', 'at': 0, 'len': 1});
    source['ent'] = [null, ...source['ent'] as List];
    for (final f in (source['fmt'] as List).cast<Map>()) {
      if (f.containsKey('key')) f['key'] = 1;
    }
    final before = jsonEncode(source);
    final result = quote(source);
    expect(DraftyCodec.plainText(result), 'A\ne\u0301 site\n');
    expect(DraftyCodec.formats(result).where((f) => f['tp'] == 'ST'), [
      {'at': 2, 'len': 1, 'tp': 'ST'},
    ]);
    expect(DraftyCodec.formats(result).where((f) => f['key'] == 1), [
      {'at': 4, 'len': 4, 'key': 1},
    ]);
    expect(jsonEncode(source), before);
    expect(DraftyCodec.forward(source), source);
  });

  test('quote clips styled Unicode to 256 graphemes including ellipsis', () {
    final result = quote(DraftyCodec.markdown('**${'👍🏽' * 300}**'));
    final outer =
        DraftyCodec.formats(result).singleWhere((f) => f['tp'] == 'QQ');
    expect(
        outer['len'], 258); // Author and separator plus 256-character excerpt.
    expect((result['txt'] as String).characters.length, 259);
    expect(
        DraftyCodec.formats(result).singleWhere((f) => f['tp'] == 'ST')['len'],
        255);
    expect(DraftyCodec.plainText(result), endsWith('…\n'));
  });

  test('one pathological combining cluster cannot bypass the quote byte cap',
      () {
    final source = 'e${'\u0301' * 10000}';
    final result = quote(source);
    expect(DraftyCodec.plainText(result), 'A\n…\n');
    expect(utf8.encode(jsonEncode(result)).length, lessThan(512));
    expect(DraftyCodec.forward(source)['txt'], source);
  });

  test('removing a hidden separator can form a new flag grapheme', () {
    final result = quote({
      'txt': '🇦x🇧',
      'fmt': [
        {'tp': 'HD', 'at': 1, 'len': 1},
        {'tp': 'ST', 'at': 2, 'len': 1},
      ],
    });
    expect(DraftyCodec.plainText(result), 'A\n🇦🇧\n');
    expect(DraftyCodec.formats(result).where((f) => f['tp'] == 'ST'), [
      {'at': 2, 'len': 1, 'tp': 'ST'},
    ]);
  });

  test('thousands of styles trigger only a bounded quote fallback', () {
    final source = <String, dynamic>{
      'txt': 'visible',
      'fmt': List.generate(1000, (_) => {'tp': 'ST', 'at': 0, 'len': 7}),
    };
    final result = quote(source);
    expect(DraftyCodec.plainText(result), 'A\nvisible\n');
    expect(utf8.encode(jsonEncode(result)).length, lessThan(16 * 1024));
    expect(DraftyCodec.formats(result).where((f) => f['tp'] == 'ST'), isEmpty);
    expect(source['fmt'], hasLength(1000));
  });
}
