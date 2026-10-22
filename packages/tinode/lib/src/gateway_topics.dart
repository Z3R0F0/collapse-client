part of 'tinode_gateway.dart';

extension _GatewayTopics on TinodeGateway {
  Future<JsonMap> _attach(String topic, {JsonMap? set}) {
    if (_attached.contains(topic)) {
      return Future.value({'code': 200, 'topic': topic});
    }
    return _attaching.putIfAbsent(topic, () {
      final epoch = _epoch;
      late final Future<JsonMap> attaching;
      attaching = _request('sub', {'topic': topic, if (set != null) 'set': set})
          .then((ctrl) {
        if (epoch == _epoch && (ctrl['code'] as int? ?? 500) < 300) {
          _attached.add(ctrl['topic'] as String? ?? topic);
        }
        return ctrl;
      }).whenComplete(() {
        if (identical(_attaching[topic], attaching)) _attaching.remove(topic);
      });
      return attaching;
    });
  }

  Future<JsonMap> _leave(String topic, {bool unsubscribe = false}) async {
    final ctrl =
        await _request('leave', {'topic': topic, 'unsub': unsubscribe});
    _attached.remove(topic);
    return ctrl;
  }

  Future<List<JsonMap>> _subscriptions({String topic = 'me'}) async {
    final meta = await _request('get', {'topic': topic, 'what': 'sub'},
        metaSection: 'sub');
    return (meta['sub'] as List? ?? [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  Future<JsonMap> _description(String topic) async {
    final meta = await _request('get', {'topic': topic, 'what': 'desc'},
        metaSection: 'desc');
    return Map<String, dynamic>.from(meta['desc'] as Map? ?? {});
  }

  Future<JsonMap> _deletions(String topic, {int since = 0}) async {
    final meta = await _request(
        'get',
        {
          'topic': topic,
          'what': 'del',
          'del': {'since': since},
        },
        metaSection: 'del');
    return Map<String, dynamic>.from(meta['del'] as Map? ?? {});
  }

  Future<JsonMap> _setMeta(String topic, JsonMap set,
          {List<String> attachments = const []}) =>
      _request('set', {...set, 'topic': topic},
          extra: _attachmentExtra(attachments));
  Future<JsonMap> _publish(String topic,
          {required Object content,
          JsonMap head = const {},
          String? clientId}) =>
      _request(
          'pub',
          {
            'topic': topic,
            'noecho': false,
            'content': content,
            'head': {...head, if (clientId != null) 'x-client-id': clientId},
          },
          extra: _attachmentExtra(head['attachments']));
  void _note(String topic, String what, {int? seq}) {
    final socket = _socket;
    if (socket == null) throw const TinodeException(0, 'Not connected');
    if ((what == 'read' || what == 'recv') && (seq == null || seq < 1)) {
      throw ArgumentError('Receipts require a positive server sequence');
    }
    // No global debounce: receipts in one chat must never suppress another chat.
    socket.sink.add(jsonEncode({
      'note': {
        'topic': topic,
        'what': what,
        if (seq != null) 'seq': seq,
      }
    }));
  }

  Future<JsonMap> _deleteMessages(String topic, List<Map<String, int>> ranges,
          {bool hard = false}) =>
      _request('del',
          {'topic': topic, 'what': 'msg', 'delseq': ranges, 'hard': hard});
}
