import 'dart:convert';

import 'package:collapse_tinode/tinode.dart';
import 'package:test/test.dart';

JsonMap quote(Object value, {Object content = ''}) => DraftyCodec.reply(
    content: content, quote: value, authorId: 'usrA', authorName: 'A');

List<Map> entities(JsonMap doc, String type) => (doc['ent'] as List? ?? [])
    .whereType<Map>()
    .where((e) => e['tp'] == type)
    .toList();

void main() {
  test(
      'quote keeps referenced photo, metadata and small preview, not large inline data',
      () {
    final source = DraftyCodec.media(
        type: 'IM',
        ref: '/v0/file/s/photo',
        name: 'a.png',
        mime: 'image/png',
        size: 10000,
        preview: 'AQID',
        thumbnail: 'A' * 10000,
        width: 20,
        height: 30);
    final result = quote(source);
    expect(entities(result, 'IM').single['data'], {
      'ref': '/v0/file/s/photo',
      'name': 'a.png',
      'mime': 'image/png',
      'size': 10000,
      'preview': 'AQID',
      'width': 20,
      'height': 30,
    });
    expect(DraftyCodec.formats(result).where((f) => f['key'] == 1), [
      {'at': 2, 'len': 1, 'key': 1},
    ]);
    expect(entities(source, 'IM').single['data']['val'], hasLength(10000));
  });

  test('small inline-only photo remains an actual image in the quote', () {
    final source = DraftyCodec.media(
        type: 'IM',
        ref: '',
        name: 'a.png',
        mime: 'image/png',
        size: 3,
        thumbnail: 'AQID');
    expect(entities(quote(source), 'IM').single['data']['val'], 'AQID');
  });

  test(
      'large inline-only photo becomes a readable filename, not a broken image',
      () {
    final source = DraftyCodec.media(
        type: 'IM',
        ref: '',
        name: 'a.png',
        mime: 'image/png',
        size: 10000,
        thumbnail: 'A' * 10000);
    final before = jsonEncode(source);
    final result = quote(source);
    expect(DraftyCodec.plainText(result), 'A\n[📷 a.png]\n');
    expect(entities(result, 'IM'), isEmpty);
    expect(jsonEncode(source), before);
    expect(DraftyCodec.forward(source), source);
    // The same large image as NEW reply content must not be lightened.
    expect(entities(quote('old', content: source), 'IM').single['data']['val'],
        hasLength(10000));
  });

  test('out-of-band files are limited to three and moved inside the quote', () {
    final source = <String, dynamic>{
      'txt': '',
      'fmt': List.generate(5, (i) => {'at': -1, 'len': 0, 'key': i}),
      'ent': List.generate(
          5,
          (i) => {
                'tp': 'EX',
                'data': {
                  'ref': '/v0/file/s/$i',
                  'name': '$i.pdf',
                  'mime': 'application/pdf'
                }
              }),
    };
    final result = quote(source, content: 'next');
    expect(entities(result, 'EX'), hasLength(3));
    expect(DraftyCodec.formats(result).where((f) => f['at'] == -1), isEmpty);
    expect(entities(quote(result, content: 'again'), 'EX'), isEmpty);
    expect(entities(source, 'EX'), hasLength(5));
  });

  test('aggregate media payload over 16KiB falls back only in the quote', () {
    final source = <String, dynamic>{
      'txt': ' ' * 25,
      'fmt': List.generate(25, (i) => {'at': i, 'len': 1, 'key': i}),
      'ent': List.generate(
          25,
          (i) => {
                'tp': 'IM',
                'data': {
                  'ref': '/v0/file/s/$i',
                  'name': '$i.png',
                  'val': 'A' * 4096
                }
              }),
    };
    final before = jsonEncode(source);
    final result = quote(source);
    expect(utf8.encode(jsonEncode(result)).length, lessThan(16 * 1024));
    expect(DraftyCodec.plainText(result), contains('[📷 0.png]'));
    expect(entities(result, 'IM'), isEmpty);
    expect(jsonEncode(source), before);
  });
}
