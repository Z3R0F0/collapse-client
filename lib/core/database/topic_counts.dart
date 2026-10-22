part of 'app_database.dart';

extension _TopicCounts on AppDatabase {
  // Only known own positive rows are excluded. Pending rows, incoming rows and
  // unknown cache gaps must not disappear from unread/after-window counts.
  // Hidden/deleted own rows still occupied a sequence, so exclude them too.
  String _incomingCountSql(String after) =>
      '''
    MAX(0, t.server_seq - $after - (
      SELECT COUNT(*) FROM messages m
      WHERE m.scope=t.scope AND m.topic_id=t.id
        AND m.seq>$after AND m.seq<=t.server_seq
        AND m.sender_id=? AND m.sender_id<>''
    ))
  ''';

  Selectable<ChatTopic> _selectTopicSummaries(
    String scope,
    String userId, {
    String? id,
  }) =>
      customSelect(
        'SELECT t.*, ${_incomingCountSql('t.read_seq')} AS unread_count '
        'FROM topics t WHERE t.scope=? ${id == null ? '' : 'AND t.id=?'} '
        'ORDER BY t.last_message_at DESC',
        variables: [
          Variable(userId),
          Variable(scope),
          if (id != null) Variable(id),
        ],
        readsFrom: {topics, messages},
      ).map(
        (row) => toTopic(
          topics.map(row.data),
          unreadCount: row.read<int>('unread_count'),
        ),
      );

  Future<int> _countIncomingAfter(
    String scope,
    String id,
    String userId,
    int afterSeq,
  ) async {
    // An integer literal is safe here and avoids duplicating a bound value in
    // the shared expression. The indexed (scope, topic, seq) range reads no body.
    final row = await customSelect(
      'SELECT ${_incomingCountSql('${max(0, afterSeq)}')} AS count '
      'FROM topics t WHERE t.scope=? AND t.id=?',
      variables: [Variable(userId), Variable(scope), Variable(id)],
      readsFrom: {topics, messages},
    ).getSingleOrNull();
    return row?.read<int>('count') ?? 0;
  }
}
