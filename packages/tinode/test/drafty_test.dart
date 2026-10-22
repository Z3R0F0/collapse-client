import 'package:collapse_tinode/tinode.dart';
import 'package:test/test.dart';

void main() {
  test('newlines use grapheme offsets after non-BMP characters', () {
    final doc = DraftyCodec.text('A😀\nБ');
    expect(doc['txt'], 'A😀 Б');
    expect(doc['fmt'], [
      {'tp': 'BR', 'at': 2, 'len': 1}
    ]);
    expect(DraftyCodec.plainText(doc), 'A😀\nБ');
  });
  test('malformed style offsets do not crash plain-text fallback', () {
    expect(
        DraftyCodec.plainText({
          'txt': 'hello',
          'fmt': [
            {'tp': 'ST', 'at': 'invalid'},
            {'tp': 'BR', 'at': 999},
            null,
          ]
        }),
        'hello');
  });
  test('plain strings are literal, not reinterpreted as Markdown or JSON', () {
    expect(DraftyCodec.plainText(DraftyCodec.decode('*hello*')), '*hello*');
    expect(DraftyCodec.plainText(DraftyCodec.decode('{"txt":"secret"}')),
        '{"txt":"secret"}');
  });
  test('unknown canonical entities survive without mutating the source', () {
    final source = {
      'txt': ' ',
      'fmt': [
        {'at': 0, 'len': 1, 'key': 0}
      ],
      'ent': [
        {
          'tp': 'FUTURE',
          'data': {
            'nested': ['value']
          }
        }
      ]
    };
    final copy = DraftyCodec.forward(source);
    expect(copy, source);
    (copy['ent'] as List).clear();
    expect(source['ent'], hasLength(1));
  });
  test('media remains canonical and supports pending local uploads', () {
    final doc = DraftyCodec.media(
        type: 'IM',
        ref: '',
        name: 'a.png',
        mime: 'image/png',
        size: 20,
        caption: 'hello',
        width: 10,
        height: 20);
    expect(doc['fmt'], [
      {'at': 0, 'len': 1, 'key': 0}
    ]);
    expect(((doc['ent'] as List).single as Map)['data'], {
      'mime': 'image/png',
      'ref': '',
      'name': 'a.png',
      'size': 20,
      'width': 10,
      'height': 20,
    });
  });
  test('generic attachments are out of band, including when quoted', () {
    final attachment = DraftyCodec.media(
        type: 'EX',
        ref: '/v0/file/s/f',
        name: 'f.pdf',
        mime: 'application/pdf',
        size: 3);
    final reply = DraftyCodec.reply(
        content: attachment,
        quote: 'first',
        authorId: 'usrA',
        authorName: '😀');
    final attachmentFormat =
        (reply['fmt'] as List).cast<Map>().firstWhere((f) => f['at'] == -1);
    expect(attachmentFormat['key'], 1);
    expect(DraftyCodec.plainText(reply), '😀\nfirst\n');
  });
  test('reply shifts styles and entity keys using grapheme offsets', () {
    final reply = DraftyCodec.reply(content: {
      'txt': 'bold',
      'fmt': [
        {'tp': 'ST', 'at': 0, 'len': 4}
      ]
    }, quote: 'hello', authorId: 'usrA', authorName: '😀');
    expect(DraftyCodec.plainText(reply), '😀\nhello\nbold');
    expect(
        (reply['fmt'] as List)
            .cast<Map>()
            .firstWhere((f) => f['tp'] == 'ST')['at'],
        8);
  });
}
