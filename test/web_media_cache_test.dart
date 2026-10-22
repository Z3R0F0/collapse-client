import 'dart:async';
import 'package:collapse/src/data/media/media_http_client.dart';
import 'package:collapse/src/data/media/web_media_cache.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'web eviction preserves retained cache hits and deletes file bytes',
    () async {
      final requests = <String>[];
      final cache = WebMediaCache(
        maxBytes: 8,
        maxEntries: 2,
        client: MediaHttpClient.buffered(
          MockClient((request) async {
            requests.add(request.url.path);
            return http.Response.bytes(
              List.filled(request.url.path == '/large' ? 7 : 3, 1),
              200,
            );
          }),
        ),
      );
      addTearDown(cache.dispose);
      await _read(cache, 'a');
      await _read(cache, 'b');
      final removed = (await cache.getFileFromCache('b'))!.file;
      await _read(cache, 'a');
      await _read(cache, 'c');
      expect(await removed.exists(), isFalse);
      expect(await cache.getFileFromCache('b'), isNull);
      expect(await _read(cache, 'a'), [1, 1, 1]);
      expect(requests, ['/a', '/b', '/c']);
      expect(await cache.store.getCacheSize(), 6);
      await _read(cache, 'large');
      expect(await cache.store.getCacheSize(), 7);
      expect(
        (await cache.config.repo.getAllObjects()).map((item) => item.key),
        ['large'],
      );
      expect(await _fileCount(cache), 1);
    },
  );

  test(
    'parallel misses return bytes before safe eviction and share same key',
    () async {
      final requests = <String>[];
      final started = Completer<void>();
      final slow = Completer<http.Response>();
      final cache = WebMediaCache(
        maxBytes: 3,
        maxEntries: 1,
        client: MediaHttpClient.buffered(
          MockClient((request) async {
            requests.add(request.url.path);
            if (request.url.path == '/slow') {
              started.complete();
              return slow.future;
            }
            return http.Response.bytes([2, 2, 2], 200);
          }),
        ),
      );
      addTearDown(cache.dispose);
      final first = _read(cache, 'slow');
      await started.future;
      final same = _read(cache, 'slow');
      expect(await _read(cache, 'fast').timeout(const Duration(seconds: 1)), [
        2,
        2,
        2,
      ]);
      slow.complete(http.Response.bytes([1, 1, 1], 200));
      expect(await Future.wait([first, same]), [
        [1, 1, 1],
        [1, 1, 1],
      ]);
      expect(requests, ['/slow', '/fast']);
      expect(await cache.store.getCacheSize(), 3);
      expect(await _fileCount(cache), 1);
      expect(await _read(cache, 'slow'), [1, 1, 1]);
      expect(requests, ['/slow', '/fast']);
    },
  );

  test(
    'concurrent completions never return removed handles or exceed retained budget',
    () async {
      final cache = WebMediaCache(
        maxBytes: 6,
        maxEntries: 2,
        client: MediaHttpClient.buffered(
          MockClient(
            (request) async => http.Response.bytes(
              List.filled(3, int.parse(request.url.path.substring(1))),
              200,
            ),
          ),
        ),
      );
      addTearDown(cache.dispose);
      final result = await Future.wait(
        List.generate(25, (index) => _read(cache, '$index')),
      );
      for (var index = 0; index < result.length; index++) {
        expect(result[index], List.filled(3, index));
      }
      expect(await cache.store.getCacheSize(), lessThanOrEqualTo(6));
      expect(await _fileCount(cache), lessThanOrEqualTo(2));
      expect(await cache.config.repo.getAllObjects(), hasLength(2));
    },
  );

  test(
    'expired immutable files stay available offline without hidden refresh',
    () async {
      var calls = 0;
      final cache = WebMediaCache(
        client: MediaHttpClient.buffered(
          MockClient((_) async {
            if (++calls > 1) throw StateError('offline');
            return http.Response.bytes(
              [1, 2],
              200,
              headers: {'cache-control': 'no-cache'},
            );
          }),
        ),
      );
      addTearDown(cache.dispose);
      expect(await _read(cache, 'a'), [1, 2]);
      expect(await _read(cache, 'a'), [1, 2]);
      expect(calls, 1);
      final file = (await cache.getFileFromCache('a'))!.file;
      await file.delete();
      await expectLater(_read(cache, 'a'), throwsStateError);
      expect(calls, 2);
    },
  );

  test(
    'failed streamed body leaves no partial memory file and can retry',
    () async {
      var attempt = 0;
      final source = StreamController<List<int>>();
      source.add([1, 2]);
      final cache = WebMediaCache(
        client: MediaHttpClient.buffered(
          MockClient.streaming(
            (_, _) async => http.StreamedResponse(
              ++attempt == 1 ? source.stream : Stream.value([3, 4]),
              200,
            ),
          ),
          const Duration(milliseconds: 10),
        ),
      );
      addTearDown(cache.dispose);
      await expectLater(_read(cache, 'a'), throwsA(isA<TimeoutException>()));
      expect(await _fileCount(cache), 0);
      expect(await cache.config.repo.getAllObjects(), isEmpty);
      expect(await _read(cache, 'a'), [3, 4]);
      expect(await _fileCount(cache), 1);
      await source.close();
    },
  );

  test(
    'dispose aborts active requests, releases cached files and forbids retry',
    () async {
      final started = Completer<void>();
      final aborted = Completer<void>();
      final cache = WebMediaCache(
        client: MediaHttpClient.buffered(
          MockClient.streaming((request, _) async {
            if (request.url.path == '/cached') {
              return http.StreamedResponse(Stream.value([1]), 200);
            }
            final result = Completer<http.StreamedResponse>();
            (request as http.Abortable).abortTrigger!.then((_) {
              aborted.complete();
              result.completeError(http.RequestAbortedException(request.url));
            });
            started.complete();
            return result.future;
          }),
        ),
      );
      await _read(cache, 'cached');
      final pending = expectLater(
        _read(cache, 'stalled'),
        throwsA(isA<http.RequestAbortedException>()),
      );
      await started.future;
      await cache.dispose();
      await pending;
      await aborted.future;
      expect(await _fileCount(cache), 0);
      expect(await cache.config.repo.getAllObjects(), isEmpty);
      await expectLater(_read(cache, 'cached'), throwsStateError);
    },
  );
}

Future<List<int>> _read(WebMediaCache cache, String key) =>
    cache.read('https://chat.test/$key', key: key, headers: const {});

Future<int> _fileCount(WebMediaCache cache) async =>
    (await (cache.config.fileSystem as MemoryCacheSystem).directory)
        .listSync()
        .length;
