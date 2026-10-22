part of 'app_database.dart';

extension _SearchQueries on AppDatabase {
  Future<List<SearchHit>> _searchMessages(
    String scope,
    String topicId,
    String query, {
    SearchCursor? before,
    int limit = 40,
  }) async {
    if (query.length > 512) {
      throw const FormatException('Search query exceeds 512 characters');
    }
    // User punctuation/operators are literal tokenizer input, never FTS syntax.
    final words = query.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final expression = words
        .map((w) => '"${w.replaceAll('"', '""')}"*')
        .join(' AND ');
    if (expression.isEmpty) return [];
    final variables = <Variable>[
      Variable(scope),
      Variable(topicId),
      Variable(expression),
    ];
    var cursor = '';
    if (before != null) {
      cursor = before.pending
          ? 'AND (m.seq > 0 OR (m.seq < 0 AND m.local_seq < ?))'
          : 'AND m.seq > 0 AND m.seq < ?';
      variables.add(Variable(before.order));
    }
    variables.add(Variable(limit.clamp(1, 41)));
    final rows = await customSelect('''
      SELECT m.client_id, m.topic_id, m.seq, m.local_seq, m.sender_id,
        m.created_at_ms,
        substr(snippet(message_fts, 0, '', '', '…', 24), 1, 512) AS snippet
      FROM message_fts JOIN message_search s ON s.id=message_fts.rowid
      JOIN messages m ON m.scope=s.scope AND m.topic_id=s.topic_id AND m.seq=s.seq
      WHERE s.scope=? AND s.topic_id=? AND message_fts MATCH ?
        AND NOT m.hidden AND NOT m.deleted $cursor
      ORDER BY (m.seq < 0) DESC,
        CASE WHEN m.seq < 0 THEN m.local_seq ELSE m.seq END DESC LIMIT ?
    ''', variables: variables).get();
    return [
      for (final row in rows)
        SearchHit(
          id: row.read<String>('client_id'),
          topicId: row.read<String>('topic_id'),
          seq: row.read<int>('seq'),
          localSeq: row.read<int>('local_seq'),
          senderId: row.read<String>('sender_id'),
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('created_at_ms'),
            isUtc: true,
          ),
          snippet: row.read<String>('snippet'),
        ),
    ];
  }
}
