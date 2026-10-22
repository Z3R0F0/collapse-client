import 'package:characters/characters.dart';
import 'package:collapse_tinode/tinode.dart';
import 'package:test/test.dart';

List<JsonMap> entities(JsonMap doc, String type) =>
    (doc['ent'] as List? ?? const [])
        .cast<JsonMap>()
        .where((e) => e['tp'] == type)
        .toList();

String visible(JsonMap doc) {
  final text = (doc['txt'] as String).characters.toList();
  for (final format in DraftyCodec.formats(doc)) {
    final key = format['key'];
    final entity = key is int ? DraftyCodec.entity(doc, key) : null;
    if (entity?['tp'] != 'HD') continue;
    final at = format['at'] as int;
    final len = format['len'] as int;
    final fragment = entity!['data']['spoiler'] as JsonMap;
    final value = DraftyCodec.plainText(fragment).characters.toList();
    expect(value, hasLength(len));
    text.replaceRange(at, at + len, value);
  }
  return text.join();
}

void main() {
  test('Telegram double underscore is italic and nested styles survive', () {
    final doc =
        DraftyCodec.markdown('**bold __italic__** __just italic__ ~~gone~~');
    expect(doc['txt'], 'bold italic just italic gone');
    expect(
        DraftyCodec.formats(doc).where((f) => f['tp'] == 'ST'), hasLength(1));
    expect(
        DraftyCodec.formats(doc).where((f) => f['tp'] == 'EM'), hasLength(2));
    expect(
        DraftyCodec.formats(doc).where((f) => f['tp'] == 'DL'), hasLength(1));
  });

  test('multiple spoilers mask only their text and retain nested styles', () {
    final doc = DraftyCodec.markdown('A ||**secret** __words__|| B ||next||');
    expect(doc['txt'], 'A •••••• ••••• B ••••');
    expect(visible(doc), 'A secret words B next');
    expect(entities(doc, 'HD').map((e) => e['data']['spoiler']['txt']),
        ['secret words', 'next']);
    expect(
        entities(doc, 'HD')
            .every((e) => (e['data'] as Map).keys.single == 'spoiler'),
        isTrue);
    expect(DraftyCodec.previewText(doc), 'A  B');
    expect(DraftyCodec.formats(doc).where((f) => f.containsKey('tp')), isEmpty);
    final fragment = entities(doc, 'HD').first['data']['spoiler'] as JsonMap;
    expect(DraftyCodec.formats(fragment).where((f) => f['tp'] == 'ST'),
        hasLength(1));
    expect(DraftyCodec.formats(fragment).where((f) => f['tp'] == 'EM'),
        hasLength(1));
  });

  test('nested spoiler ranges never leak or change grapheme positions', () {
    final doc = DraftyCodec.markdown('||||secret||||');
    expect(doc['txt'], '••••••');
    expect(visible(doc), 'secret');
    expect(entities(doc, 'HD'), hasLength(1));
    expect(entities(doc, 'HD').single['data']['spoiler']['ent'], isNull);
    expect(DraftyCodec.formats(doc).every((f) => f['at'] == 0 && f['len'] == 6),
        isTrue);
  });

  test('spoilers count emoji and combining marks as graphemes', () {
    final doc = DraftyCodec.markdown('👩‍💻 ||🇺🇳 e\u0301 **Ж**|| end');
    expect(doc['txt'], '👩‍💻 • • • end');
    expect(visible(doc), '👩‍💻 🇺🇳 e\u0301 Ж end');
    final hidden =
        DraftyCodec.formats(doc).firstWhere((f) => f.containsKey('key'));
    expect(hidden['at'], 2);
    expect(hidden['len'], 5);
    final fragment = entities(doc, 'HD').single['data']['spoiler'] as JsonMap;
    final bold =
        DraftyCodec.formats(fragment).firstWhere((f) => f['tp'] == 'ST');
    expect(bold['at'], 4);
    expect(bold['len'], 1);
  });

  test('spoilers preserve whitespace and line break formats', () {
    final doc = DraftyCodec.markdown('||a  b\nc||');
    expect(doc['txt'], '•  • •');
    expect(visible(doc), 'a  b\nc');
    expect(DraftyCodec.plainText(doc), '•  • •');
  });

  test('a combining mark outside a spoiler keeps its complete grapheme', () {
    for (final source in ['||e||\u0301', 'e||\u0301||']) {
      final doc = DraftyCodec.markdown(source);
      expect(doc['txt'], '•');
      expect(visible(doc), 'e\u0301');
      expect(DraftyCodec.formats(doc).single['len'], 1);
    }
  });

  test('styles enclosing a spoiler stay public without exposing its fragment',
      () {
    final doc = DraftyCodec.markdown('**before ||__secret__|| after**');
    expect(doc['txt'], 'before •••••• after');
    expect(visible(doc), 'before secret after');
    expect(
        DraftyCodec.formats(doc).where((f) => f['tp'] == 'ST'), hasLength(1));
    expect(DraftyCodec.formats(doc).where((f) => f['tp'] == 'EM'), isEmpty);
    final fragment = entities(doc, 'HD').single['data']['spoiler'] as JsonMap;
    expect(DraftyCodec.formats(fragment).single['tp'], 'EM');
  });

  test('code is literal, and fenced code retains language metadata', () {
    final inline = DraftyCodec.markdown('`||secret|| __literal__`');
    expect(inline['txt'], '||secret|| __literal__');
    expect(entities(inline, 'HD'), isEmpty);
    final block = DraftyCodec.markdown('```dart\n||secret|| __literal__\n```');
    expect(block['txt'], '||secret|| __literal__');
    expect(entities(block, 'HD'), isEmpty);
    expect(entities(block, 'CO'), [
      {
        'tp': 'CO',
        'data': {'language': 'dart', 'block': true}
      }
    ]);
  });

  test('escaped and unmatched delimiters remain literal', () {
    final doc =
        DraftyCodec.markdown(r'\_\_x\_\_ \|\|y\|\| __unfinished ||unfinished');
    expect(doc['txt'], '__x__ ||y|| __unfinished ||unfinished');
    expect(doc['ent'], isNull);
    expect(doc['fmt'], isNull);
  });

  test(
      'safe links inside spoilers preserve targets but not visible labels in txt',
      () {
    final doc = DraftyCodec.markdown('||[**label**](https://example.org)||');
    expect(doc['txt'], '•••••');
    expect(visible(doc), 'label');
    expect(entities(doc, 'LN'), isEmpty);
    final fragment = entities(doc, 'HD').single['data']['spoiler'] as JsonMap;
    expect(
        entities(fragment, 'LN').single['data']['url'], 'https://example.org');
    expect(DraftyCodec.formats(doc).where((f) => f.containsKey('tp')), isEmpty);
    final unsafe = DraftyCodec.markdown('||[label](javascript:alert)||');
    expect(unsafe['txt'], '•••••');
    expect(entities(unsafe, 'LN'), isEmpty);
    expect(
        entities(
            entities(unsafe, 'HD').single['data']['spoiler'] as JsonMap, 'LN'),
        isEmpty);
  });

  test('blank paragraph lines are retained without changing block contents',
      () {
    final doc = DraftyCodec.markdown('one\n\ntwo\n\n\nthree');
    expect(DraftyCodec.plainText(doc), 'one\n\ntwo\n\n\nthree');
  });

  test('links whose entire label is hidden keep their URL inside HD only', () {
    for (final source in [
      '[||secret||](https://secret.example/token)',
      '[**||one||** ||two||](https://secret.example/token)',
    ]) {
      final doc = DraftyCodec.markdown(source);
      expect(entities(doc, 'LN'), isEmpty);
      final fragment = entities(doc, 'HD').single['data']['spoiler'] as JsonMap;
      expect(entities(fragment, 'LN').single['data']['url'],
          'https://secret.example/token');
      expect(entities(fragment, 'HD'), isEmpty);
    }
  });

  test('partially visible link labels keep their intentionally public target',
      () {
    final doc =
        DraftyCodec.markdown('[public ||secret||](https://example.org)');
    expect(doc['txt'], 'public ••••••');
    expect(entities(doc, 'LN').single['data']['url'], 'https://example.org');
    expect(entities(doc, 'HD'), hasLength(1));
  });

  test('source, incoming and forwarded Drafty are never reparsed', () {
    const source = '__italic__ ||secret||';
    final doc = DraftyCodec.markdown(source);
    expect(source, '__italic__ ||secret||');
    expect(DraftyCodec.decode(source), {'txt': source});
    expect(DraftyCodec.forward(source), {'txt': source});
    expect(DraftyCodec.forward(doc), doc);
  });
}
