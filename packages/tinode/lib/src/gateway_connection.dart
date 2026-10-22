part of 'tinode_gateway.dart';

extension _GatewayConnection on TinodeGateway {
  Future<void> _connect() async {
    final epoch = ++_epoch;
    final uri = serverUri.replace(
      scheme: serverUri.scheme == 'https' ? 'wss' : 'ws',
      path: '/v0/channels',
      queryParameters: {'apikey': apiKey},
    );
    final socket = _connector(uri);
    _socket = socket;
    _subscription = socket.stream.listen(
      (frame) {
        if (epoch == _epoch) _onFrame(frame);
      },
      onError: (Object error) {
        if (epoch == _epoch) unawaited(disconnect());
      },
      onDone: () {
        if (epoch == _epoch) _lostConnection();
      },
    );
    try {
      await socket.ready.timeout(timeout);
      if (epoch != _epoch || _socket == null) {
        throw const TinodeException(0, 'Connection was cancelled');
      }
      await _request('hi', {'ver': '0.25', 'ua': 'Collapse/0.1 (Dart)'});
      if (epoch != _epoch || _socket == null) {
        throw const TinodeException(0, 'Connection was cancelled');
      }
      _ready = true;
      _events.add(const TinodeEvent('connected', {}));
    } catch (_) {
      if (epoch == _epoch) await disconnect();
      rethrow;
    }
  }

  Future<void> _disconnect() async {
    final socket = _socket;
    ++_epoch;
    _lostConnection();
    await _subscription?.cancel();
    _subscription = null;
    await socket?.sink.close();
  }

  Future<void> _probeConnection() async {
    final socket = _socket;
    if (!_ready || socket == null) {
      throw const TinodeException(0, 'Not connected');
    }
    final epoch = _epoch;
    final response = Completer<void>();
    _probeResponse = response;
    try {
      socket.sink.add('1');
      await response.future.timeout(timeout);
    } catch (_) {
      if (epoch == _epoch) await disconnect();
      rethrow;
    } finally {
      if (identical(_probeResponse, response)) _probeResponse = null;
    }
  }

  void _lostConnection() {
    final wasOpen = _socket != null;
    _socket = null;
    _ready = false;
    userId = null;
    token = null;
    _attached.clear();
    _attaching.clear();
    final probe = _probeResponse;
    _probeResponse = null;
    _probing = null;
    if (probe != null && !probe.isCompleted) {
      probe.completeError(const TinodeException(0, 'Connection closed'));
    }
    for (final upload in _uploads.toList()) {
      if (!upload.isCompleted) upload.complete();
    }
    _uploads.clear();
    for (final pending in _pending.values.toList()) {
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(
          const TinodeException(0, 'Connection closed'),
        );
      }
    }
    _pending.clear();
    if (wasOpen && !_events.isClosed) {
      _events.add(const TinodeEvent('disconnected', {}));
    }
  }

  Future<void> _dispose() async {
    if (_disposed) return;
    _disposed = true;
    await disconnect();
    _http.close();
    await _events.close();
  }
}
