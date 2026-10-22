part of 'app_database.dart';

extension _MessageQueries on AppDatabase {
  Future<MessageRow?> _findMessageRow(String scope, String topicId, int seq) =>
      (select(messages)..where(
            (m) =>
                m.scope.equals(scope) &
                m.topicId.equals(topicId) &
                m.seq.equals(seq),
          ))
          .getSingleOrNull();

  Future<MessageRow?> _findMessageByClientId(String scope, String clientId) =>
      (select(messages)
            ..where((m) => m.scope.equals(scope) & m.clientId.equals(clientId))
            ..limit(1))
          .getSingleOrNull();

  Future<List<MessageRow>> _findMessagesByClientIds(
    String scope,
    Iterable<String> ids,
  ) => (select(
    messages,
  )..where((m) => m.scope.equals(scope) & m.clientId.isIn(ids))).get();

  Future<List<ChatMessage>> _loadMessagePage(
    String scope,
    String topicId, {
    int? before,
    int? since,
    int limit = 40,
  }) async {
    final query = select(messages)
      ..where(
        (m) =>
            m.scope.equals(scope) &
            m.topicId.equals(topicId) &
            m.seq.isBiggerThanValue(0) &
            m.hidden.equals(false) &
            m.deleted.equals(false),
      );
    if (before != null) query.where((m) => m.seq.isSmallerThanValue(before));
    if (since != null) query.where((m) => m.seq.isBiggerThanValue(since));
    query
      ..orderBy([
        (m) =>
            since != null ? OrderingTerm.asc(m.seq) : OrderingTerm.desc(m.seq),
      ])
      ..limit(limit);
    final rows = await query.get();
    final result = rows.map(toMessage).toList();
    if (since == null) return result.reversed.toList();
    return result;
  }

  Future<List<ChatMessage>> _loadPendingMessages(
    String scope,
    String topicId, {
    int? before,
    int? since,
    int limit = 40,
  }) async {
    final query = select(messages)
      ..where(
        (m) =>
            m.scope.equals(scope) &
            m.topicId.equals(topicId) &
            m.seq.isSmallerThanValue(0) &
            m.hidden.equals(false) &
            m.deleted.equals(false),
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

  ChatMessage _mapMessageRow(MessageRow row) => ChatMessage(
    id: row.clientId,
    topicId: row.topicId,
    seq: row.seq,
    localSeq: row.localSeq,
    senderId: row.senderId,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row.createdAtMs,
      isUtc: true,
    ),
    content: jsonDecode(row.content) as Object,
    head: Map<String, dynamic>.from(jsonDecode(row.head) as Map),
    delivery: Delivery.values[row.delivery],
    hidden: row.hidden || row.deleted,
  );
}
