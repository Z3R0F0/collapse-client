import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collapse/core/config.dart';
import 'package:collapse/src/data/media/media_repository.dart';
import 'package:collapse_tinode/tinode.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late TinodeGateway gateway;
  late MediaRepository media;
  late _Cache cache;
  setUp(() {
    gateway = TinodeGateway(
      endpoint: Uri.parse('https://chat.test'),
      apiKey: 'key',
    );
    gateway.userId = 'usrA';
    gateway.token = 'synthetic-token';
    cache = _Cache();
    media = MediaRepository(
      AppConfig(
        endpoint: Uri.parse('wss://chat.test/v0/channels'),
        apiKey: 'key',
      ),
      gateway,
      cache: cache,
    )..userId = 'usrA';
  });
  tearDown(() async {
    await media.dispose();
    await gateway.dispose();
  });

  test('Tinode bare references resolve relative to the download endpoint', () {
    expect(
      media.resolve('file.png').toString(),
      'https://chat.test/v0/file/s/file.png',
    );
    expect(
      media.resolve('./file.png').toString(),
      'https://chat.test/v0/file/s/file.png',
    );
    expect(
      media.resolve('/v0/file/s/file.png').toString(),
      'https://chat.test/v0/file/s/file.png',
    );
  });

  test('credentials are scoped to exact origin and current account', () {
    expect(media.headers(Uri.parse('https://chat.test/v0/file/s/a')), {
      'X-Tinode-APIKey': 'key',
      'Authorization': 'token synthetic-token',
    });
    expect(media.headers(Uri.parse('https://external.test/a')), isEmpty);
    expect(media.headers(Uri.parse('https://child.chat.test/a')), isEmpty);
    expect(media.headers(Uri.parse('https://chat.test:8443/a')), isEmpty);
    expect(media.headers(Uri.dataFromString('plain')), isEmpty);
    media.userId = 'usrB';
    expect(
      media
          .headers(Uri.parse('https://chat.test/a'))
          .containsKey('Authorization'),
      isFalse,
    );
  });

  test(
    'dangerous schemes, userinfo and insecure external media are rejected',
    () {
      for (final ref in [
        'javascript:alert(1)',
        'file:///private/file',
        'https://user:password@chat.test/a',
        'http://external.test/a',
      ]) {
        expect(() => media.resolve(ref), throwsFormatException);
      }
    },
  );

  test(
    'account changes use separate cache keys, without reusing credentials',
    () async {
      await expectLater(media.bytes('/v0/file/s/a'), throwsStateError);
      media.userId = 'usrB';
      await expectLater(media.bytes('/v0/file/s/a'), throwsStateError);
      expect(cache.keys, hasLength(2));
      expect(cache.keys.first, isNot(cache.keys.last));
      expect(cache.headers.first['Authorization'], 'token synthetic-token');
      expect(cache.headers.last.containsKey('Authorization'), isFalse);
    },
  );

  test('expired cached image and playback remain available offline', () async {
    final ref = '/v0/file/s/cached';
    final key = '${media.config.serverId}|usrA|$ref';
    final file = _File('/cache/old.bin', [1, 2, 3]);
    cache.files[key] = FileInfo(file, FileSource.Cache, DateTime(2000), ref);
    expect(await media.bytes(ref), [1, 2, 3]);
    expect(await media.playable(ref, 'audio/wav'), Uri.file(file.path));
    expect(cache.streamCalls, 2);
  });

  test('data URI size limit applies to bytes and playback', () async {
    final ref = Uri.dataFromBytes(
      Uint8List(MediaRepository.maxBytes + 1),
      mimeType: 'application/octet-stream',
    ).toString();
    await expectLater(media.bytes(ref), throwsFormatException);
    await expectLater(
      media.playable(ref, 'application/octet-stream'),
      throwsFormatException,
    );
  });

  test(
    'canonical inline media validates base64 and prefers full remote ref',
    () async {
      final ref = media.draftyReference({'val': 'AQID', 'mime': 'audio/wav'});
      expect(await media.bytes(ref), [1, 2, 3]);
      expect(Uri.parse(ref).data!.mimeType, 'audio/wav');
      expect(
        media.draftyReference({'ref': '/v0/file/s/full', 'val': 'preview'}),
        '/v0/file/s/full',
      );
      for (final invalid in [
        'not base64!',
        [1, 2, 3],
        {'val': 1},
        'A',
      ]) {
        expect(
          () => media.draftyReference({'val': invalid}),
          throwsFormatException,
        );
      }
      expect(
        () => media.draftyReference({
          'val': base64Encode(Uint8List(MediaRepository.maxBytes + 1)),
          'size': 1,
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'native inline playback caches bytes by scoped digest, not a raw data URI',
    () async {
      final ref = media.draftyReference({'val': 'AQID', 'mime': 'audio/wav'});
      final first = await media.playable(ref, 'audio/wav');
      expect(first.scheme, 'file');
      expect(cache.inlineBytes, [1, 2, 3]);
      expect(cache.extensions, ['wav']);
      expect(
        cache.inlineUrls.single,
        matches(r'^collapse-inline:[a-f0-9]{64}$'),
      );
      expect(
        cache.inlineKeys.single,
        startsWith('${media.config.serverId}|usrA|inline:'),
      );
      expect(await media.playable(ref, 'audio/wav'), first);
      expect(cache.inlineKeys, hasLength(1));
      media.userId = 'usrB';
      await media.playable(ref, 'audio/../../bad;evil');
      expect(cache.inlineKeys, hasLength(2));
      expect(cache.inlineKeys.last, isNot(cache.inlineKeys.first));
      expect(cache.extensions.last, 'bin');
    },
  );

  test(
    'streaming download allows exactly 10 MiB and preserves HTTP metadata',
    () async {
      final client = MediaHttpClient(
        MockClient.streaming((request, body) async {
          expect(request.followRedirects, isFalse);
          return http.StreamedResponse(
            Stream.value(Uint8List(MediaRepository.maxBytes)),
            200,
            contentLength: MediaRepository.maxBytes,
            headers: {'content-type': 'image/png'},
            reasonPhrase: 'OK',
            request: request,
          );
        }),
      );
      addTearDown(client.close);
      final response = await client.send(
        http.Request('GET', Uri.parse('https://chat.test/a')),
      );
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'image/png');
      expect(response.reasonPhrase, 'OK');
      expect(
        await response.stream.fold<int>(
          0,
          (count, bytes) => count + bytes.length,
        ),
        MediaRepository.maxBytes,
      );
    },
  );

  test(
    'streaming download cancels at first byte above limit with no declared length',
    () async {
      var cancelled = false;
      final source = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      source.add(Uint8List(MediaRepository.maxBytes));
      source.add([1]);
      final client = MediaHttpClient(
        MockClient.streaming(
          (_, _) async => http.StreamedResponse(source.stream, 200),
        ),
      );
      addTearDown(client.close);
      final response = await client.send(
        http.Request('GET', Uri.parse('https://chat.test/a')),
      );
      await expectLater(response.stream.drain<void>(), throwsFormatException);
      expect(cancelled, isTrue);
      await source.close();
    },
  );

  test(
    'oversized declared download is cancelled before its payload is consumed',
    () async {
      var cancelled = false;
      var aborted = false;
      final source = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      final client = MediaHttpClient(
        MockClient.streaming((request, _) async {
          (request as http.Abortable).abortTrigger!.then((_) => aborted = true);
          return http.StreamedResponse(
            source.stream,
            200,
            contentLength: MediaRepository.maxBytes + 1,
          );
        }),
      );
      addTearDown(client.close);
      await expectLater(
        client.send(http.Request('GET', Uri.parse('https://chat.test/a'))),
        throwsFormatException,
      );
      expect(cancelled, isTrue);
      expect(aborted, isTrue);
      await source.close();
    },
  );

  test(
    'redirect and failed response bodies are cancelled without forwarding auth',
    () async {
      for (final status in [304, 307, 401, 500]) {
        var cancelled = false;
        var aborted = false;
        final source = StreamController<List<int>>(
          onCancel: () => cancelled = true,
        );
        final client = MediaHttpClient(
          MockClient.streaming((request, _) async {
            expect(request.followRedirects, isFalse);
            expect(request.headers['Authorization'], 'token synthetic-token');
            (request as http.Abortable).abortTrigger!.then(
              (_) => aborted = true,
            );
            return http.StreamedResponse(
              source.stream,
              status,
              headers: {'location': 'https://other.test/media'},
            );
          }),
        );
        final request = http.Request('GET', Uri.parse('https://chat.test/a'))
          ..headers['Authorization'] = 'token synthetic-token';
        final response = await client.send(request);
        expect(response.statusCode, status);
        expect(await response.stream.toBytes(), isEmpty);
        expect(cancelled, isTrue);
        expect(aborted, isTrue);
        await source.close();
        client.close();
      }
    },
  );

  test(
    'stalled response headers time out and abort the underlying request',
    () async {
      final aborted = Completer<void>();
      final client = MediaHttpClient(
        MockClient.streaming((request, _) {
          final pending = Completer<http.StreamedResponse>();
          (request as http.Abortable).abortTrigger!.then((_) {
            aborted.complete();
            pending.completeError(http.RequestAbortedException(request.url));
          });
          return pending.future;
        }),
        const Duration(milliseconds: 10),
      );
      addTearDown(client.close);
      await expectLater(
        client.send(
          http.Request('GET', Uri.parse('https://chat.test/stalled')),
        ),
        throwsA(isA<TimeoutException>()),
      );
      await aborted.future;
    },
  );

  test(
    'stalled response body times out, cancels stream and can be retried',
    () async {
      var cancelled = false;
      final source = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      source.add([1]);
      var attempt = 0;
      final client = MediaHttpClient(
        MockClient.streaming((_, _) async {
          attempt++;
          return http.StreamedResponse(
            attempt == 1 ? source.stream : Stream.value([2]),
            200,
          );
        }),
        const Duration(milliseconds: 10),
      );
      addTearDown(client.close);
      final response = await client.send(
        http.Request('GET', Uri.parse('https://chat.test/stalled')),
      );
      await expectLater(
        response.stream.drain<void>(),
        throwsA(isA<TimeoutException>()),
      );
      expect(cancelled, isTrue);
      final retry = await client.send(
        http.Request('GET', Uri.parse('https://chat.test/stalled')),
      );
      expect(await retry.stream.toBytes(), [2]);
      await source.close();
    },
  );
}

/// Records the cache boundary without native filesystem/plugin dependencies.
class _Cache implements BaseCacheManager {
  final keys = <String>[];
  final headers = <Map<String, String>>[];
  final inlineKeys = <String>[];
  final inlineUrls = <String>[];
  final extensions = <String>[];
  Uint8List? inlineBytes;
  final files = <String, FileInfo>{};
  int streamCalls = 0;
  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async => files[key];
  @override
  Future<File> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) async {
    inlineKeys.add(key!);
    inlineUrls.add(url);
    extensions.add(fileExtension);
    inlineBytes = Uint8List.fromList(fileBytes);
    final file = _File('/cache/${inlineKeys.length}.$fileExtension');
    files[key] = FileInfo(
      file,
      FileSource.Cache,
      DateTime.now().add(maxAge),
      url,
    );
    return file;
  }

  @override
  Future<void> dispose() async {}
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    streamCalls++;
    keys.add(key!);
    this.headers.add(Map<String, String>.from(headers ?? {}));
    final cached = files[key];
    if (cached != null) {
      yield cached;
      return;
    }
    throw StateError('Captured cache request');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getSingleFile) {
      keys.add(invocation.namedArguments[#key] as String);
      headers.add(
        Map<String, String>.from(invocation.namedArguments[#headers] as Map),
      );
      return Future<Never>.error(StateError('Captured cache request'));
    }
    return super.noSuchMethod(invocation);
  }
}

class _File implements File {
  _File(this.path, [this.bytes = const []]);
  final List<int> bytes;
  @override
  final String path;
  @override
  Future<int> length() async => bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => Uint8List.fromList(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
