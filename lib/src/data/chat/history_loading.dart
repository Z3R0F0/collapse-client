part of 'chats_repository.dart';

extension _HistoryLoading on ChatsRepository {
  Future<List<ChatMessage>> _loadLatest(
    String topicId, {
    int limit = 40,
  }) async {
    return (await openHistory(topicId, limit: limit))?.messages ?? [];
  }

  Future<MessagePage> _loadBefore(
    String topicId,
    int beforeSeq, {
    int limit = 40,
  }) async {
    final window = await _extendHistory(
      topicId,
      HistorySpan(server: SequenceRange(beforeSeq, beforeSeq)),
      direction: HistoryDirection.older,
      limit: limit,
      capacity: limit,
      includeLocal: false,
    );
    return MessagePage(
      window?.messages ?? [],
      hasMore: window?.older.canLoad ?? false,
    );
  }

  Future<MessagePage> _loadAfter(
    String topicId,
    int afterSeq, {
    int limit = 40,
  }) async {
    final window = await _extendHistory(
      topicId,
      HistorySpan(server: SequenceRange(afterSeq + 1, afterSeq + 1)),
      direction: HistoryDirection.newer,
      limit: limit,
      capacity: limit,
      includeLocal: false,
    );
    return MessagePage(
      window?.messages ?? [],
      hasMore: window?.newer.canLoad ?? false,
    );
  }

  Future<List<ChatMessage>> _loadAround(
    String topicId,
    int seq, {
    int limit = 40,
  }) async {
    return (await openHistory(
          topicId,
          aroundSeq: seq,
          limit: limit,
        ))?.messages ??
        [];
  }

  Future<List<ChatMessage>> _reloadWindow(
    String topicId,
    List<ChatMessage> window,
  ) async {
    final rows = await database.messagesByIds(
      _activeScope,
      window.map((m) => m.id),
    );
    final byId = {for (final row in rows) row.clientId: row};
    final result = <ChatMessage>[];
    for (final previous in window) {
      final row = byId[previous.id];
      if (row != null && !row.hidden && !row.deleted) {
        result.add(database.toMessage(row));
      }
    }
    result.sort((a, b) {
      if (a.pending != b.pending) return a.pending ? 1 : -1;
      return a.pending
          ? a.localSeq.compareTo(b.localSeq)
          : a.seq.compareTo(b.seq);
    });
    return result;
  }

  Future<List<ChatMessage>> _fetch(
    String scope,
    String topicId, {
    int? since,
    int? before,
    int limit = 40,
  }) async {
    final generation = _generation;
    await _attach(topicId);
    if (_generation != generation || _scope != scope) return [];
    // Pin the upper bound before I/O. A later presence/live watermark cannot
    // prove coverage for messages outside this completed request.
    final requestEnd =
        before ??
        ((await database.topicRow(scope, topicId))?.serverSeq ?? 0) + 1;
    if (requestEnd <= 1 || !_historyActive(scope, generation)) return [];
    _historyRequests.update(topicId, (count) => count + 1, ifAbsent: () => 1);
    try {
      final packets = await gateway.history(
        topicId,
        since: since,
        before: requestEnd,
        limit: limit,
      );
      if (_generation != generation || _scope != scope) return [];
      final result = <ChatMessage>[];
      for (final packet in packets) {
        if (_generation != generation || _scope != scope) return [];
        final message = await _storeData(scope, {
          ...packet,
          'topic': topicId,
        }, origin: ChatChangeOrigin.history);
        if (message != null) result.add(message);
      }
      result.sort((a, b) => a.seq.compareTo(b.seq));
      final low =
          since ?? (packets.length < limit ? 1 : result.firstOrNull?.seq ?? 1);
      if (!_historyActive(scope, generation)) return [];
      await database.recordCoverage(scope, topicId, low, requestEnd);
      return result;
    } finally {
      if (_generation == generation) {
        final remaining = (_historyRequests[topicId] ?? 1) - 1;
        if (remaining == 0) {
          _historyRequests.remove(topicId);
        } else {
          _historyRequests[topicId] = remaining;
        }
      }
    }
  }
}
