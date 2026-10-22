import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'media_http_client.dart';
import 'web_cache_info.dart';

/// Uses the package's memory filesystem, with real metadata IDs for eviction.
/// Only file bytes count toward this budget, not image/player decoding buffers.
class WebMediaCache extends CacheManager {
  factory WebMediaCache({
    MediaHttpClient? client,
    int maxBytes = 64 * 1024 * 1024,
    int maxEntries = 200,
  }) => WebMediaCache._(
    client ?? MediaHttpClient.buffered(),
    WebCacheInfo(maxBytes: maxBytes, maxEntries: maxEntries),
  );

  WebMediaCache._(this._client, this._info)
    : super(
        Config(
          'collapse_media',
          repo: _info,
          fileSystem: MemoryCacheSystem(),
          fileService: HttpFileService(httpClient: _client),
        ),
      );

  final MediaHttpClient _client;
  final WebCacheInfo _info;
  Future<void> _queue = Future.value();
  final _active = <Future<Uint8List>>{};
  bool _closed = false;

  Future<Uint8List> read(
    String url, {
    required String key,
    required Map<String, String> headers,
  }) {
    late final Future<Uint8List> result;
    result = _read(
      url,
      key,
      headers,
    ).whenComplete(() => _active.remove(result));
    _active.add(result);
    return result;
  }

  Future<T> _serialize<T>(FutureOr<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Uint8List> _read(
    String url,
    String key,
    Map<String, String> headers,
  ) async {
    await _serialize(() {
      if (_closed) throw StateError('Media cache is closed');
      _info.pin(key);
    });
    try {
      // Tinode attachment refs identify immutable files. Keep a cached file
      // offline, without a hidden refresh racing eviction in the background.
      final cached = await getFileFromCache(key);
      final file =
          cached ?? await downloadFile(url, key: key, authHeaders: headers);
      // Network misses remain concurrent. Only file read/eviction is serialized,
      // so no caller receives a handle another completion can remove underneath.
      return await _serialize(() async {
        if (_closed) throw StateError('Media cache is closed');
        if (await file.file.length() > MediaHttpClient.maxBytes) {
          throw const FormatException('Media exceeds limit');
        }
        _info.touch(key);
        return file.file.readAsBytes();
      });
    } finally {
      await _serialize(() async {
        _info.release(key);
        for (final item in _info.overBudget()) {
          await removeFile(item.key);
        }
      });
    }
  }

  @override
  Future<void> dispose() async {
    _closed = true;
    _client.close();
    await Future.wait(
      _active.toList().map(
        (future) =>
            future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      ),
    );
    await _queue;
    await emptyCache();
    await super.dispose();
  }
}
