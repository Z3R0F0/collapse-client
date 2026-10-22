part of 'app_database.dart';

extension _HistoryWindowQueries on AppDatabase {
  Future<List<ChatMessage>> _localHistoryRows(
    String scope,
    String topicId, {
    required int serverEnd,
    int? before,
    int? since,
    int limit = 40,
  }) async {
    if (limit <= 0) return [];
    final query = select(messages)
      ..where(
        (m) =>
            m.scope.equals(scope) &
            m.topicId.equals(topicId) &
            m.localSeq.isBiggerThanValue(0) &
            m.hidden.equals(false) &
            m.deleted.equals(false) &
            (m.seq.isSmallerThanValue(0) |
                m.seq.isBiggerOrEqualValue(serverEnd)),
      );
    if (before != null) {
      query.where((m) => m.localSeq.isSmallerThanValue(before));
    }
    if (since != null) query.where((m) => m.localSeq.isBiggerThanValue(since));
    query
      ..orderBy([
        (m) => since == null
            ? OrderingTerm.desc(m.localSeq)
            : OrderingTerm.asc(m.localSeq),
      ])
      ..limit(limit);
    final rows = (await query.get()).map(toMessage).toList();
    return since == null ? rows.reversed.toList() : rows;
  }

  Future<int?> _unretainedHistorySeq(
    String scope,
    String topicId,
    SequenceRange range,
    int localEnd,
  ) async {
    final row = await customSelect(
      'SELECT MIN(seq) AS seq FROM messages WHERE scope=? AND topic_id=? '
      'AND seq>=? AND seq<? AND hidden=0 AND deleted=0 '
      'AND (local_seq=0 OR local_seq>=?)',
      variables: [
        Variable(scope),
        Variable(topicId),
        Variable(range.start),
        Variable(range.end),
        Variable(localEnd),
      ],
      readsFrom: {messages},
    ).getSingle();
    return row.readNullable<int>('seq');
  }

  Future<int?> _firstLocalAck(
    String scope,
    String topicId,
    Iterable<String> ids,
  ) async {
    if (ids.isEmpty) return null;
    final row = await customSelect(
      'SELECT MIN(seq) AS seq FROM messages WHERE scope=? AND topic_id=? '
      'AND seq>0 AND client_id IN (${List.filled(ids.length, '?').join(',')})',
      variables: [Variable(scope), Variable(topicId), ...ids.map(Variable.new)],
      readsFrom: {messages},
    ).getSingle();
    return row.readNullable<int>('seq');
  }

  /// One SQL snapshot combines server rows and the retained local suffix. An
  /// ACK cannot appear twice or fall between separate pending/server SELECTs.
  Future<List<ChatMessage>> _historyRows(
    String scope,
    String topicId,
    HistorySpan span, {
    required HistoryDirection retain,
    required int limit,
  }) async {
    if (limit <= 0) return [];
    final order = retain == HistoryDirection.older ? 'ASC' : 'DESC';
    final server = span.server;
    final ids = span.retainedLocalIds;
    final localFilter = ids.isEmpty
        ? '0'
        : 'local_seq>0 AND client_id IN (${List.filled(ids.length, '?').join(',')})';
    final rows = await customSelect(
      'SELECT * FROM messages WHERE scope=? AND topic_id=? '
      'AND hidden=0 AND deleted=0 AND '
      '((seq>=? AND seq<?) OR ($localFilter)) '
      'ORDER BY CASE WHEN seq>=? AND seq<? THEN 0 ELSE 1 END $order, '
      'CASE WHEN seq>=? AND seq<? THEN seq ELSE local_seq END $order LIMIT ?',
      variables: [
        Variable(scope),
        Variable(topicId),
        Variable(server.start),
        Variable(server.end),
        ...ids.map(Variable.new),
        Variable(server.start),
        Variable(server.end),
        Variable(server.start),
        Variable(server.end),
        Variable(limit),
      ],
      readsFrom: {messages},
    ).get();
    final result = rows
        .map((row) => toMessage(messages.map(row.data)))
        .toList();
    return retain == HistoryDirection.older ? result : result.reversed.toList();
  }
}
