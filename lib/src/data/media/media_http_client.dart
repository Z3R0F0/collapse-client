import 'dart:async';
import 'package:http/http.dart' as http;

/// Bound downloads while streaming, not only after a large file reaches disk.
class MediaHttpClient extends http.BaseClient {
  MediaHttpClient([
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  ]) : _client = client ?? http.Client(),
       _buffered = false;
  MediaHttpClient.buffered([
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  ]) : _client = client ?? http.Client(),
       _buffered = true;
  final http.Client _client;
  final Duration timeout;
  final bool _buffered;
  final _active = <Completer<void>>{};
  bool _closed = false;
  static const maxBytes = 10 * 1024 * 1024;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.followRedirects = false;
    return _send(request);
  }

  Future<http.StreamedResponse> _send(http.BaseRequest request) async {
    if (_closed) throw StateError('Media client is closed');
    final aborted = Completer<void>();
    _active.add(aborted);
    void abort() {
      if (!aborted.isCompleted) aborted.complete();
      _active.remove(aborted);
    }

    late final http.StreamedResponse response;
    try {
      response = await _client
          .send(_AbortableMediaRequest(request, aborted.future))
          .timeout(timeout);
    } catch (_) {
      abort();
      rethrow;
    }
    if ((response.contentLength ?? 0) > maxBytes) {
      abort();
      await response.stream.listen((_) {}).cancel();
      throw const FormatException('Media exceeds limit');
    }
    Stream<List<int>> bounded() async* {
      var received = 0;
      try {
        await for (final chunk in response.stream.timeout(timeout)) {
          received += chunk.length;
          if (received > maxBytes) {
            throw const FormatException('Media exceeds limit');
          }
          yield chunk;
        }
      } finally {
        abort();
      }
    }

    final hasBody = response.statusCode == 200 || response.statusCode == 202;
    if (!hasBody) {
      // CacheManager does not consume redirects, failures or 304 response bodies.
      abort();
      await response.stream.listen((_) {}).cancel();
    }
    // CacheManager leaves a partial file when its input stream fails. On web,
    // validate one bounded response before writing to its memory filesystem.
    final stream = !hasBody
        ? const Stream<List<int>>.empty()
        : _buffered
        ? Stream<List<int>>.value(await http.ByteStream(bounded()).toBytes())
        : bounded();
    return http.StreamedResponse(
      stream,
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {
    _closed = true;
    for (final request in _active.toList()) {
      if (!request.isCompleted) request.complete();
    }
    _active.clear();
    _client.close();
  }
}

/// Keep the original streamed body while using http's native/browser abort API.
class _AbortableMediaRequest extends http.BaseRequest with http.Abortable {
  _AbortableMediaRequest(this.source, this.abortTrigger)
    : super(source.method, source.url) {
    headers.addAll(source.headers);
    contentLength = source.contentLength;
    persistentConnection = source.persistentConnection;
    followRedirects = false;
  }
  final http.BaseRequest source;
  @override
  final Future<void> abortTrigger;
  @override
  http.ByteStream finalize() {
    super.finalize();
    return source.finalize();
  }
}
