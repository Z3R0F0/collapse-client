import 'package:characters/characters.dart';
import 'package:collapse_tinode/tinode.dart';
import 'package:test/test.dart';

List<String> styled(JsonMap doc, String type) => DraftyCodec.formats(doc)
    .where((format) {
      final key = format['key'];
      final entity = key is int ? DraftyCodec.entity(doc, key) : null;
      return (format['tp'] ?? entity?['tp']) == type;
    })
    .map((format) => (doc['txt'] as String)
        .characters
        .skip(format['at'] as int)
        .take(format['len'] as int)
        .join())
    .toList();

void main() {
  test('CommonMark and GFM produce canonical nested inline styles', () {
    final doc = DraftyCodec.markdown(
        '**bold _nested_** and ~~gone~~ and `**literal**`');
    expect(doc['txt'], 'bold nested and gone and **literal**');
    expect(styled(doc, 'ST'), ['bold nested']);
    expect(styled(doc, 'EM'), ['nested']);
    expect(styled(doc, 'DL'), ['gone']);
    expect(styled(doc, 'CO'), ['**literal**']);
  });

  test('escapes, unfinished markup and raw HTML stay readable literal text',
      () {
    expect(DraftyCodec.markdown(r'\*literal\* & **unfinished')['txt'],
        '*literal* & **unfinished');
    expect(DraftyCodec.plainText(DraftyCodec.markdown('<b>raw & text</b>')),
        '<b>raw & text</b>');
    expect(DraftyCodec.markdown('A &amp; B')['txt'], 'A & B');
  });

  test('links retain labels, safe targets and nested formatting', () {
    final doc = DraftyCodec.markdown(
        '[**site**](https://example.com/a?q=1&x=2) <me@example.com>');
    expect(doc['txt'], 'site me@example.com');
    expect(styled(doc, 'ST'), ['site']);
    expect(doc['ent'], [
      {
        'tp': 'LN',
        'data': {'url': 'https://example.com/a?q=1&x=2'}
      },
      {
        'tp': 'LN',
        'data': {'url': 'mailto:me@example.com'}
      },
    ]);
    expect(DraftyCodec.markdown('[unsafe](javascript:alert)')['txt'], 'unsafe');
    expect(DraftyCodec.markdown('[unsafe](javascript:alert)')['ent'], isNull);
  });

  test('blocks, ordered and nested lists, headings and quotes remain readable',
      () {
    final doc = DraftyCodec.markdown(
        '# Title\n\nParagraph\n\n3. three\n4. four\n\n- top\n  - child\n\n> quote');
    expect(DraftyCodec.plainText(doc),
        'Title\n\nParagraph\n\n3. three\n4. four\n• top\n  • child\nquote');
    expect(styled(doc, 'ST'), ['Title']);
    expect(styled(doc, 'QQ'), ['quote']);
  });

  test('fenced and indented code preserve content without parsing markup', () {
    final fenced = DraftyCodec.markdown('```dart\n**raw**\nnext\n```');
    expect(DraftyCodec.plainText(fenced), '**raw**\nnext');
    expect(styled(fenced, 'CO'), ['**raw** next']);
    expect(styled(fenced, 'ST'), isEmpty);
    final indented = DraftyCodec.markdown('    **raw**');
    expect(indented['txt'], '**raw**');
    expect(styled(indented, 'CO'), ['**raw**']);
  });

  test('tables and images keep meaningful text without remote media entities',
      () {
    final table = DraftyCodec.markdown('| A | B |\n| - | - |\n| x | y |');
    expect(DraftyCodec.plainText(table), 'A | B\nx | y');
    final image = DraftyCodec.markdown('![diagram](https://example.com/a.png)');
    expect(image['txt'], 'diagram (https://example.com/a.png)');
    expect(image['ent'], isNull);
  });

  test('task lists keep their checked state as text', () {
    final doc = DraftyCodec.markdown('- [x] done\n- [ ] later');
    expect(DraftyCodec.plainText(doc), '• [x] done\n• [ ] later');
  });

  test('incoming and forwarded content never pass through the Markdown parser',
      () {
    expect(DraftyCodec.decode('**literal**'), {'txt': '**literal**'});
    expect(DraftyCodec.forward('**literal**'), {'txt': '**literal**'});
    expect(DraftyCodec.markdown('**literal**')['txt'], 'literal');
  });
}
