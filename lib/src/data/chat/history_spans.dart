part of 'chats_repository.dart';

extension _HistorySpans on ChatsRepository {
  bool _historyActive(String scope, int generation) =>
      _scope == scope && _generation == generation;

  List<SequenceRange> _historyRanges(TopicRow topic) =>
      (jsonDecode(topic.coverage) as List)
          .map((r) => SequenceRange((r as List)[0] as int, r[1] as int))
          .toList();

  SequenceRange? _historyComponent(TopicRow topic, int seq) =>
      _historyRanges(topic).where((range) => range.contains(seq)).firstOrNull;

  /// Skip only ACKs already ordered before the local cursor, and only through
  /// proved coverage. A peer row or an unknown hole still stops this frontier.
  Future<int> _localServerFrontier(
    String scope,
    TopicRow topic,
    HistorySpan span,
  ) async {
    final local = span.local;
    final cursor = span.server.end;
    if (local == null) return cursor;
    final known = _historyComponent(topic, cursor);
    if (known == null) return cursor;
    final end = min(known.end, topic.serverSeq + 1);
    return await database.unretainedHistorySeq(
          scope,
          topic.id,
          SequenceRange(cursor, end),
          local.end,
        ) ??
        end;
  }

  Future<int> _localOlderFrontier(
    String scope,
    TopicRow topic,
    HistorySpan span,
  ) async => span.local == null
      ? span.server.start
      : await database.firstLocalAck(scope, topic.id, span.retainedLocalIds) ??
            topic.serverSeq + 1;

  SequenceRange _historyGap(
    TopicRow topic,
    int cursor,
    HistoryDirection direction,
    int limit,
  ) {
    if (direction == HistoryDirection.older) {
      var start = max(1, cursor - limit);
      for (final range in _historyRanges(topic)) {
        if (range.end <= cursor) start = max(start, range.end);
      }
      return SequenceRange(start, cursor);
    }
    var end = min(topic.serverSeq + 1, cursor + limit);
    for (final range in _historyRanges(topic)) {
      if (range.start >= cursor) end = min(end, range.start);
    }
    return SequenceRange(cursor, end);
  }

  Future<HistoryEdge> _serverHistoryEdge(
    String scope,
    TopicRow topic,
    int cursor,
    HistoryDirection direction,
  ) async {
    final older = direction == HistoryDirection.older;
    final component = _historyComponent(topic, older ? cursor - 1 : cursor);
    if (component != null) {
      final range = older
          ? SequenceRange(component.start, cursor)
          : SequenceRange(cursor, min(component.end, topic.serverSeq + 1));
      final rows = await database.historyRows(
        scope,
        topic.id,
        HistorySpan(server: range),
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return const HistoryEdge(HistoryAvailability.available);
      }
      cursor = older ? range.start : range.end;
    }
    if (older ? cursor <= 1 : cursor >= topic.serverSeq + 1) {
      return const HistoryEdge(HistoryAvailability.exhausted);
    }
    return HistoryEdge(
      _networkReady
          ? HistoryAvailability.available
          : HistoryAvailability.blocked,
      gap: _historyGap(topic, cursor, direction, 40),
    );
  }

  /// Cache-first adjacent expansion; at most one bounded network interval.
  Future<SequenceRange> _expandServerHistory(
    String scope,
    int generation,
    String topicId,
    SequenceRange span,
    HistoryDirection direction,
    int limit, {
    bool fetch = true,
  }) async {
    if (limit <= 0) return span;
    final older = direction == HistoryDirection.older;
    final origin = older ? span.start : span.end;
    var cursor = origin;
    var topic = await database.topicRow(scope, topicId);
    if (topic == null || !_historyActive(scope, generation)) return span;
    // The second pass can use only the interval fetched in the first pass.
    for (var pass = 0; pass < 2; pass++) {
      final component = _historyComponent(topic!, older ? origin - 1 : origin);
      if (component != null) {
        final range = older
            ? SequenceRange(component.start, origin)
            : SequenceRange(origin, min(component.end, topic.serverSeq + 1));
        final rows = await database.historyRows(
          scope,
          topicId,
          HistorySpan(server: range),
          retain: older ? HistoryDirection.newer : HistoryDirection.older,
          limit: limit,
        );
        if (!_historyActive(scope, generation)) return span;
        cursor = rows.length == limit
            ? (older ? rows.first.seq : rows.last.seq + 1)
            : (older ? range.start : range.end);
        if (rows.length == limit) break;
      }
      if (pass == 1 ||
          !fetch ||
          !_networkReady ||
          (older ? cursor <= 1 : cursor >= topic.serverSeq + 1)) {
        break;
      }
      final gap = _historyGap(topic, cursor, direction, min(40, limit));
      if (gap.isEmpty) break;
      await _fetch(
        scope,
        topicId,
        since: gap.start,
        before: gap.end,
        limit: gap.end - gap.start,
      );
      if (!_historyActive(scope, generation)) return span;
      topic = await database.topicRow(scope, topicId);
      if (topic == null) return span;
    }
    return older
        ? SequenceRange(cursor, span.end)
        : SequenceRange(span.start, cursor);
  }
}
