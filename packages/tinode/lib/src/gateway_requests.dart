part of 'tinode_gateway.dart';

extension _GatewayRequests on TinodeGateway {
  void _onFrame(dynamic frame) {
    if (frame == '0') {
      final probe = _probeResponse;
      if (probe != null && !probe.isCompleted) probe.complete();
      return;
    }
    try {
      final envelope = jsonDecode(frame as String) as Map;
      for (final kind in ['ctrl', 'meta', 'data', 'pres', 'info']) {
        final raw = envelope[kind];
        if (raw is! Map) continue;
        final event = TinodeEvent(kind, Map<String, dynamic>.from(raw));
        if (kind == 'ctrl' && event.payload['code'] == 205) {
          _attached.remove(event.topic);
        }
        if (kind == 'pres' && event.payload['what'] == 'term') {
          _attached.remove(event.topic);
        }
        if (kind == 'pres' && event.payload['what'] == 'gone') {
          _attached.remove(event.payload['src']);
        }
        _events.add(event);
        final pending = _pending[event.id];
        if (pending == null || pending.completer.isCompleted) continue;
        if (kind == 'ctrl') {
          final code = (event.payload['code'] as num?)?.toInt() ?? 500;
          if (code >= 400) {
            pending.completer.completeError(TinodeException(
              code,
              event.payload['text']?.toString() ?? 'Request failed',
            ));
          } else if (pending.ctrlWhat == null ||
              (event.payload['params'] as Map?)?['what'] == pending.ctrlWhat) {
            pending.completer.complete(event.payload);
          }
        } else if (kind == 'meta' &&
            pending.metaSection != null &&
            event.payload.containsKey(pending.metaSection)) {
          pending.completer.complete(event.payload);
        }
      }
    } on FormatException {
      _events
          .add(const TinodeEvent('protocolError', {'reason': 'Invalid JSON'}));
    } on TypeError {
      _events.add(
          const TinodeEvent('protocolError', {'reason': 'Invalid packet'}));
    }
  }

  Future<JsonMap> _request(String kind, JsonMap payload,
      {String? metaSection, String? ctrlWhat, JsonMap? extra}) async {
    final socket = _socket;
    if (socket == null) throw const TinodeException(0, 'Not connected');
    final id = '${_epoch}_${++_requestId}';
    final pending = _Pending(metaSection, ctrlWhat);
    _pending[id] = pending;
    try {
      socket.sink.add(jsonEncode({
        kind: {...payload, 'id': id},
        if (extra != null) 'extra': extra,
      }));
      return await pending.completer.future.timeout(timeout);
    } finally {
      _pending.remove(id);
    }
  }
}

class _Pending {
  _Pending(this.metaSection, this.ctrlWhat);
  final String? metaSection;
  final String? ctrlWhat;
  final completer = Completer<JsonMap>();
}
