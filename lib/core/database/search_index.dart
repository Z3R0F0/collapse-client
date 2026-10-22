part of 'app_database.dart';

extension _SearchIndex on AppDatabase {
  Future<void> _indexMessage(
    String scope,
    String topicId,
    int seq,
    Object content, {
    bool hidden = false,
  }) => _writeSearchBody(
    scope,
    topicId,
    seq,
    hidden ? '' : DraftyCodec.previewText(content),
  );

  Future<void> _writeSearchBody(
    String scope,
    String topicId,
    int seq,
    String body,
  ) => customStatement(
    '''
    INSERT INTO message_search(scope, topic_id, seq, body) VALUES (?, ?, ?, ?)
    ON CONFLICT(scope, topic_id, seq) DO UPDATE SET body=excluded.body
    WHERE body IS NOT excluded.body
  ''',
    [scope, topicId, seq, body],
  );

  Future<bool> _prepareSearchBatch(String scope, String topicId) async {
    final key = (scope, topicId);
    final before = _searchCursors[key];
    final result = await transaction(() async {
      final rows = await customSelect(
        '''
          SELECT m.seq, m.hidden, m.deleted, $_searchProjection
          FROM messages m
          WHERE m.scope=? AND m.topic_id=?
          ${before == null ? '' : 'AND m.seq < ?'} AND NOT EXISTS (
            SELECT 1 FROM message_search s WHERE s.scope=m.scope
              AND s.topic_id=m.topic_id AND s.seq=m.seq
          )
          ORDER BY m.seq DESC LIMIT 40
          ''',
        variables: [
          Variable(scope),
          Variable(topicId),
          if (before != null) Variable(before),
        ],
      ).get();
      for (final row in rows) {
        final hidden = row.read<bool>('hidden') || row.read<bool>('deleted');
        final doc = <String, dynamic>{
          'txt': row.read<String>('text'),
          'fmt': jsonDecode(row.read<String>('formats')),
          'ent': [
            for (final type in jsonDecode(row.read<String>('types')) as List)
              {'tp': type},
          ],
        };
        await _indexMessage(
          scope,
          topicId,
          row.read<int>('seq'),
          doc,
          hidden: hidden,
        );
      }
      final cursor = rows.lastOrNull?.read<int>('seq');
      if (cursor == null) return (true, null);
      final remaining = await customSelect(
        '''
          SELECT 1 FROM messages m WHERE m.scope=? AND m.topic_id=? AND m.seq < ?
          AND NOT EXISTS (SELECT 1 FROM message_search s WHERE s.scope=m.scope
            AND s.topic_id=m.topic_id AND s.seq=m.seq) LIMIT 1
          ''',
        variables: [Variable(scope), Variable(topicId), Variable(cursor)],
      ).getSingleOrNull();
      return (remaining == null, cursor);
    });
    if (result.$1) {
      _searchCursors.remove(key);
    } else {
      _searchCursors[key] = result.$2!;
    }
    return result.$1;
  }
}
