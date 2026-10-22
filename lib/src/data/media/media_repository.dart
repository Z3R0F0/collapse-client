import 'dart:convert';
import 'package:collapse_tinode/tinode.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/file.dart';
import '../../../core/config.dart';
import 'media_http_client.dart';
import 'web_media_cache.dart';

export 'media_http_client.dart';

class MediaRepository {
  MediaRepository(this.config, this.gateway, {BaseCacheManager? cache})
    : _client = cache == null && !kIsWeb ? MediaHttpClient() : null {
    _cache =
        cache ??
        (kIsWeb
            ? WebMediaCache()
            : CacheManager(
                Config(
                  'collapse_media',
                  maxNrOfCacheObjects: 200,
                  fileService: HttpFileService(httpClient: _client),
                ),
              ));
  }
  final AppConfig config;
  final TinodeGateway gateway;
  late final BaseCacheManager _cache;
  final MediaHttpClient? _client;
  final _pending = <String, Future<Uint8List>>{};
  String? _userId;
  int _generation = 0;
  String? get userId => _userId;
  set userId(String? value) {
    if (value != _userId) {
      _userId = value;
      _generation++;
    }
  }

  static const maxBytes = MediaHttpClient.maxBytes;

  /// Canonical Drafty uses a remote ref or base64-encoded in-band `val`.
  String draftyReference(Map<String, dynamic> data) {
    final ref = data['ref'];
    if (ref is String && ref.isNotEmpty) return ref;
    final value = data['val'];
    if (value == null || value == '') return '';
    if (value is! String || value.length > ((maxBytes + 2) ~/ 3) * 4) {
      throw const FormatException('Invalid inline media');
    }
    final bytes = base64Decode(value);
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Media exceeds limit');
    }
    return Uri.dataFromBytes(
      bytes,
      mimeType: data['mime'] is String
          ? data['mime'] as String
          : 'application/octet-stream',
    ).toString();
  }

  Uri resolve(String ref) {
    final path = Uri.parse(ref);
    var uri = path.hasScheme || path.path.startsWith('/')
        ? config.httpBase.resolve(ref)
        : config.httpBase.resolve('/v0/file/s/').resolve(ref);
    // Older clients persisted absolute URLs. The configured backend is the
    // same trusted server behind our web proxy, not an external media origin.
    if ({'http', 'https'}.contains(uri.scheme) &&
        uri.userInfo.isEmpty &&
        uri.origin == config.canonicalHttpBase.origin) {
      uri = uri.replace(
        scheme: config.httpBase.scheme,
        host: config.httpBase.host,
        port: config.httpBase.port,
      );
    }
    if (!{'https', 'http', 'data'}.contains(uri.scheme) ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Unsupported media URL');
    }
    if (uri.scheme == 'http' && uri.origin != config.httpBase.origin) {
      throw const FormatException('Insecure external media');
    }
    return uri;
  }

  Map<String, String> headers(Uri uri) =>
      uri.scheme != 'data' && uri.origin == config.httpBase.origin
      ? {
          'X-Tinode-APIKey': config.apiKey,
          if (gateway.token != null && gateway.userId == userId)
            'Authorization': 'token ${gateway.token}',
        }
      : const {};

  String _key(String ref) => '${config.serverId}|$userId|$ref';

  Future<Uint8List> bytes(String ref) async {
    final uri = resolve(ref);
    if (uri.scheme == 'data') return _inlineBytes(uri);
    final key = _key(ref);
    if (_pending.containsKey(key)) return _pending[key]!;
    final future = _load(uri, key);
    _pending[key] = future;
    try {
      return await future;
    } finally {
      _pending.remove(key);
    }
  }

  Future<Uint8List> _load(Uri uri, String key) async {
    final cache = _cache;
    if (cache is WebMediaCache) {
      return cache.read(uri.toString(), key: key, headers: headers(uri));
    }
    final file = await _file(uri, key);
    if (await file.length() > maxBytes) {
      throw const FormatException('Media exceeds limit');
    }
    return file.readAsBytes();
  }

  Future<File> _file(Uri uri, String key) async {
    // Serve a stale cached file immediately, retaining offline availability.
    final cached = await _cache
        .getFileStream(uri.toString(), key: key, headers: headers(uri))
        .where((event) => event is FileInfo)
        .cast<FileInfo>()
        .first;
    return cached.file;
  }

  Future<Uri> playable(String ref, String mime) async {
    final uri = resolve(ref);
    if (uri.scheme == 'data') {
      final bytes = _inlineBytes(uri);
      if (kIsWeb) return uri;
      return playableBytes(bytes, mime);
    }
    if (kIsWeb) return Uri.dataFromBytes(await bytes(ref), mimeType: mime);
    final file = await _file(uri, _key(ref));
    if (await file.length() > maxBytes) {
      throw const FormatException('Media exceeds limit');
    }
    return Uri.file(file.path);
  }

  /// Local outbox/inline bytes use the existing player source/cache path.
  /// The web data URI is transient: it never enters Drafty, SQLite or the wire.
  Future<Uri> playableBytes(Uint8List bytes, String mime) async {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Invalid local media size');
    }
    if (kIsWeb) return Uri.dataFromBytes(bytes, mimeType: mime);
    final generation = _generation;
    void checkAccount() {
      if (generation != _generation) {
        throw StateError('Media account changed');
      }
    }

    final digest = sha256.convert(bytes).toString();
    final key = _key('inline:$digest');
    final cached = await _cache.getFileFromCache(key);
    checkAccount();
    if (cached != null) return Uri.file(cached.file.path);
    final parts = mime.split(';').first.split('/');
    final extension = parts.length == 2 ? parts.last : 'bin';
    final file = await _cache.putFile(
      'collapse-inline:$digest',
      bytes,
      key: key,
      fileExtension: RegExp(r'^[a-zA-Z0-9]+$').hasMatch(extension)
          ? extension
          : 'bin',
    );
    checkAccount();
    return Uri.file(file.path);
  }

  Future<void> dispose() {
    _generation++;
    _client?.close();
    return _cache.dispose();
  }

  Uint8List _inlineBytes(Uri uri) {
    final data = uri.data!.contentAsBytes();
    if (data.length > maxBytes) {
      throw const FormatException('Media exceeds limit');
    }
    return data;
  }
}
