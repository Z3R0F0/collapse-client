part of 'tinode_gateway.dart';

extension _GatewayHistory on TinodeGateway {
  /// History arrives as uncorrelated data packets followed by a correlated ctrl.
  /// Serialize queries within each topic, preserving global event delivery.
  /// Results are newest first even when [since] is provided.
  Future<List<JsonMap>> _history(String topic,
      {int? since, int? before, int limit = 40}) {
    if (limit <= 0 ||
        (since != null && since < 1) ||
        (before != null && before <= 1) ||
        (since != null && before != null && since >= before)) {
      return Future.error(ArgumentError('Invalid history interval'));
    }
    final epoch = _epoch;
    final preceding = _historyQueues[topic] ?? Future<void>.value();
    final result = preceding.then((_) async {
      if (epoch != _epoch) {
        throw const TinodeException(0, 'History belongs to a closed session');
      }
      final messages = <int, JsonMap>{};
      final listener = events.listen((event) {
        if (event.kind != 'data' || event.topic != topic) return;
        final seq = (event.payload['seq'] as num?)?.toInt();
        if (seq == null ||
            (since != null && seq < since) ||
            (before != null && seq >= before)) {
          return;
        }
        messages[seq] = event.payload;
        if (messages.length > limit) {
          messages.remove(messages.keys.reduce((a, b) => a < b ? a : b));
        }
      });
      try {
        await _request(
            'get',
            {
              'topic': topic,
              'what': 'data',
              'data': {
                if (since != null) 'since': since,
                if (before != null) 'before': before,
                'limit': limit
              },
            },
            ctrlWhat: 'data');
        return messages.values.toList()
          ..sort((a, b) => (b['seq'] as int).compareTo(a['seq'] as int));
      } finally {
        await listener.cancel();
      }
    });
    final settled =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _historyQueues[topic] = settled;
    unawaited(settled.then((_) {
      if (identical(_historyQueues[topic], settled)) {
        _historyQueues.remove(topic);
      }
    }));
    return result;
  }
}
