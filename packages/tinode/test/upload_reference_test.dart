import 'dart:convert';
import 'dart:typed_data';

import 'package:collapse_tinode/tinode.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  for (final (responseRef, expected) in [
    ('file.png', '/v0/file/s/file.png'),
    ('/v0/file/s/file.png', '/v0/file/s/file.png'),
    (
      'http://127.0.0.1:8086/v0/file/s/file.png',
      '/v0/file/s/file.png',
    ),
    (
      'http://127.0.0.1:8086/v0/file/s/a%20b.png?download=1&name=x%2Fy#preview',
      '/v0/file/s/a%20b.png?download=1&name=x%2Fy',
    ),
  ]) {
    test('upload returns a device-independent ref from $responseRef', () async {
      final uploader = _uploader(responseRef);
      final native = TinodeGateway(
        endpoint: Uri.parse('http://10.0.2.2:6060'),
        apiKey: 'test',
      );
      try {
        final ref = await uploader.upload(
          Uint8List.fromList([1]),
          name: 'file.png',
          mime: 'image/png',
        );
        expect(ref, expected);
        expect(Uri.parse(ref).hasScheme, isFalse);
        expect(Uri.parse(ref).hasAuthority, isFalse);
        expect(uploader.resolveFile(ref).toString(),
            'http://127.0.0.1:8086$expected');
        expect(native.resolveFile(ref).toString(),
            'http://10.0.2.2:6060$expected');
      } finally {
        await uploader.dispose();
        await native.dispose();
      }
    });
  }

  for (final ref in [
    'https://external.test/v0/file/s/file.png',
    '//external.test/v0/file/s/file.png',
    'http://127.0.0.1:6060/v0/file/s/file.png',
    'https://127.0.0.1:8086/v0/file/s/file.png',
    'http://user:password@127.0.0.1:8086/v0/file/s/file.png',
  ]) {
    test('upload still rejects an untrusted response origin: $ref', () async {
      final uploader = _uploader(ref);
      try {
        await expectLater(
          uploader.upload(Uint8List(1), name: 'file.png', mime: 'image/png'),
          throwsA(isA<TinodeException>().having((e) => e.code, 'code', 403)),
        );
      } finally {
        await uploader.dispose();
      }
    });
  }
}

TinodeGateway _uploader(String ref) => TinodeGateway(
      endpoint: Uri.parse('http://127.0.0.1:8086'),
      apiKey: 'test',
      httpClient: MockClient((_) async => http.Response(
            jsonEncode({
              'ctrl': {
                'code': 200,
                'params': {'url': ref}
              },
            }),
            200,
          )),
    )..token = 'synthetic-token';
