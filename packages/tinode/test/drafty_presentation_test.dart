import 'dart:convert';
import 'package:collapse_tinode/tinode.dart';
import 'package:test/test.dart';

JsonMap media(String name, {String type = 'IM'}) => DraftyCodec.media(
      type: type,
      ref: '/v0/file/s/$name',
      name: name,
      mime: 'application/octet-stream',
      size: 12,
    );

JsonMap reply(Object body, Object quote) => DraftyCodec.reply(
      content: body,
      quote: quote,
      authorId: 'usrAlice',
      authorName: 'Alice',
    );

void main() {
  test('reply views preserve original keys and exclude quoted gallery media',
      () {
    final doc = reply(media('body'), media('quoted'));
    final original = jsonEncode(doc);
    final parts = DraftyCodec.splitReply(doc);
    expect(DraftyCodec.attachments(parts.quote!).single.entityIndex, 1);
    expect(DraftyCodec.attachments(parts.body).single.entityIndex, 2);
    final gallery = DraftyCodec.attachments(doc, excludeQuotes: true).single;
    expect(gallery.entityIndex, 2);
    expect(gallery.entity['data']['name'], 'body');
    expect(DraftyCodec.previewText(parts.quote!), 'Alice');
    expect(jsonEncode(doc), original);
    expect(DraftyCodec.forward(doc), doc);
  });

  test('text reply body never expands retained quoted entity table', () {
    final parts = DraftyCodec.splitReply(reply('answer', media('quoted')));
    expect(parts.body['txt'], 'answer');
    expect(parts.body['fmt'], isEmpty);
    expect(DraftyCodec.attachments(parts.body), isEmpty);
    expect(DraftyCodec.attachments(parts.quote!), hasLength(1));
  });

  test(
      'grapheme slice remaps styles and leaves source and body entities intact',
      () {
    final body = DraftyCodec.markdown('**👩🏽‍💻 é**');
    final parts = DraftyCodec.splitReply(reply(body, '👨‍👩‍👧‍👦 quoted'));
    expect(parts.body['txt'], body['txt']);
    expect(parts.body['fmt'], body['fmt']);
    expect(DraftyCodec.previewText(parts.quote!), 'Alice\n👨‍👩‍👧‍👦 quoted');
  });

  test('out of band files remain in body, quoted files are inline in quote',
      () {
    final doc = reply(media('body', type: 'EX'), media('quoted', type: 'EX'));
    final parts = DraftyCodec.splitReply(doc);
    expect(DraftyCodec.attachments(parts.quote!).single.entityIndex, 1);
    expect(DraftyCodec.attachments(parts.body).single.entityIndex, 2);
    expect(DraftyCodec.attachments(doc, excludeQuotes: true).single.entityIndex,
        2);
  });

  test('hidden-only references are omitted, visible duplicates remain once',
      () {
    final doc = <String, dynamic>{
      'txt': 'abcd',
      'fmt': [
        {'at': 0, 'len': 1}, // default key zero, hidden
        {'at': 0, 'len': 2, 'tp': 'HD'},
        {'at': 1, 'len': 1, 'key': 2}, // hidden occurrence
        {'at': 2, 'len': 1, 'key': 2}, // same entity visible
        {'at': 3, 'len': 1, 'key': 3},
        {'at': 3, 'len': 1, 'tp': 'QQ'},
      ],
      'ent': [
        {'tp': 'IM'},
        null,
        {'tp': 'VD'},
        {'tp': 'AU'},
        {'tp': 'EX'},
      ],
    };
    expect(DraftyCodec.attachments(doc).map((e) => e.entityIndex), [2, 3]);
    expect(
        DraftyCodec.attachments(doc, excludeQuotes: true)
            .map((e) => e.entityIndex),
        [2]);
  });

  test('legacy absence, explicit empty formats and malformed references differ',
      () {
    final doc = <String, dynamic>{
      'txt': '',
      'ent': [
        null,
        {'tp': 'IM'}
      ]
    };
    expect(DraftyCodec.attachments(doc).single.entityIndex, 1);
    expect(DraftyCodec.attachments({...doc, 'fmt': []}), isEmpty);
    expect(
        DraftyCodec.attachments({
          ...doc,
          'fmt': [
            {'at': -1, 'key': 0},
            {'at': 99, 'len': 1, 'key': 1},
          ]
        }),
        isEmpty);
    expect(identical(DraftyCodec.splitReply(doc).body, doc), isTrue);
  });

  test('legacy QR and default key zero are canonical read-only views', () {
    final doc = <String, dynamic>{
      'txt': 'q body',
      'fmt': [
        {'tp': 'QR', 'len': 1},
        {'tp': 'BR', 'at': 1, 'len': 1},
        {'len': 1},
      ],
      'ent': [
        {'tp': 'IM'}
      ],
    };
    expect(DraftyCodec.splitReply(doc).body['txt'], 'body');
    expect(DraftyCodec.attachments(doc, excludeQuotes: true), isEmpty);
    expect(
        DraftyCodec.attachments(DraftyCodec.splitReply(doc).quote!)
            .single
            .entityIndex,
        0);
  });
}
