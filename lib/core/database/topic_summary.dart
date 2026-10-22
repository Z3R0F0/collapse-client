part of 'app_database.dart';

extension _TopicSummary on AppDatabase {
  Future<void> _refreshTopicSummary(String scope, String topicId) async {
    final server =
        await (select(messages)
              ..where(
                (m) =>
                    m.scope.equals(scope) &
                    m.topicId.equals(topicId) &
                    m.seq.isBiggerThanValue(0) &
                    m.hidden.equals(false) &
                    m.deleted.equals(false),
              )
              ..orderBy([(m) => OrderingTerm.desc(m.seq)])
              ..limit(1))
            .getSingleOrNull();
    final pending =
        await (select(messages)
              ..where(
                (m) =>
                    m.scope.equals(scope) &
                    m.topicId.equals(topicId) &
                    m.seq.isSmallerThanValue(0) &
                    m.hidden.equals(false) &
                    m.deleted.equals(false),
              )
              ..orderBy([(m) => OrderingTerm.desc(m.localSeq)])
              ..limit(1))
            .getSingleOrNull();
    final row =
        pending != null &&
            (server == null || pending.createdAtMs >= server.createdAtMs)
        ? pending
        : server;
    final message = row == null ? null : toMessage(row);
    await (update(
      topics,
    )..where((t) => t.scope.equals(scope) & t.id.equals(topicId))).write(
      TopicsCompanion(
        lastMessageSeq: Value(row?.seq ?? 0),
        lastMessageAt: Value(row?.createdAtMs),
        lastPreview: Value(
          message == null ? '' : AppDatabase.preview(message.content),
        ),
      ),
    );
  }
}
