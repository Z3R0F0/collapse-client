part of 'tinode_gateway.dart';

extension _GatewayUpload on TinodeGateway {
  /// Tinode GC links live in envelope.extra, not the persisted message head.
  JsonMap? _attachmentExtra(Object? values) {
    if (values is! Iterable) return null;
    final refs = <String>{};
    for (final ref in values.whereType<String>()) {
      if (ref.isEmpty) continue;
      try {
        final uri = resolveFile(ref);
        if (uri.path.startsWith('/v0/file/s/') &&
            uri.path.substring('/v0/file/s/'.length).isNotEmpty) {
          refs.add(uri.path);
        }
      } on TinodeException {
        // Off-origin references are content, not server-managed uploads.
      } on FormatException {
        // Malformed references cannot identify a server-managed upload.
      }
    }
    return refs.isEmpty ? null : {'attachments': refs.toList()};
  }

  /// Resolve Tinode relative refs without ever forwarding credentials off-origin.
  Uri _resolveFile(String ref) {
    final resolved = serverUri.resolve('/v0/file/s/').resolve(ref);
    _checkOrigin(resolved);
    return resolved;
  }

  void _checkOrigin(Uri uri) {
    if (!['http', 'https'].contains(uri.scheme) ||
        uri.origin != serverUri.origin ||
        uri.userInfo.isNotEmpty) {
      throw const TinodeException(403, 'Cross-origin file URL rejected');
    }
  }

  Future<String> _upload(Uint8List bytes,
      {required String name, required String mime}) async {
    final authToken = token;
    if (authToken == null) {
      throw const TinodeException(401, 'Authentication required');
    }
    final epoch = _epoch;
    final aborted = Completer<void>();
    _uploads.add(aborted);
    void checkSession() {
      if (epoch != _epoch || _disposed || aborted.isCompleted) {
        throw const TinodeException(0, 'Upload was cancelled');
      }
    }

    try {
      var target = serverUri.resolve('/v0/file/u/');
      for (var attempt = 0; attempt < 3; attempt++) {
        checkSession();
        _checkOrigin(target);
        final request = http.AbortableMultipartRequest('POST', target,
            abortTrigger: aborted.future)
          ..followRedirects = false
          ..headers.addAll(
              {'X-Tinode-APIKey': apiKey, 'Authorization': 'token $authToken'})
          ..files.add(http.MultipartFile.fromBytes('file', bytes,
              filename: name, contentType: MediaType.parse(mime)));
        final response = await _http.send(request).timeout(timeout);
        checkSession();
        final body = await response.stream.bytesToString().timeout(timeout);
        checkSession();
        if (response.statusCode == 307) {
          final location = response.headers['location'];
          if (location == null) {
            throw const TinodeException(502, 'Missing upload redirect');
          }
          target = target.resolve(location);
          continue;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw TinodeException(response.statusCode, 'Upload failed');
        }
        final ctrl = (jsonDecode(body) as Map)['ctrl'] as Map;
        if ((ctrl['code'] as int? ?? 500) >= 300) {
          throw TinodeException(ctrl['code'] as int? ?? 500, 'Upload rejected');
        }
        final ref = (ctrl['params'] as Map?)?['url'] as String?;
        if (ref == null || ref.isEmpty) {
          throw const TinodeException(502, 'Missing file reference');
        }
        final resolved = resolveFile(ref);
        // Persist Tinode refs, not the current device's host or web proxy port.
        return '${resolved.path}${resolved.hasQuery ? '?${resolved.query}' : ''}';
      }
      throw const TinodeException(502, 'Too many upload redirects');
    } on TimeoutException {
      rethrow;
    } catch (_) {
      checkSession();
      rethrow;
    } finally {
      // Future.timeout alone abandons the Future, not the underlying HTTP I/O.
      if (!aborted.isCompleted) aborted.complete();
      _uploads.remove(aborted);
    }
  }
}
