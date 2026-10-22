part of 'app_database.dart';

extension _MediaQueries on AppDatabase {
  Future<List<MediaItem>> _mediaPage(
    String scope,
    String topicId,
    MediaCategory category, {
    MediaCursor? before,
    MediaCursor? after,
    int limit = 24,
  }) async {
    final query = select(mediaEntries)
      ..where(
        (m) =>
            m.scope.equals(scope) &
            m.topicId.equals(topicId) &
            m.type.isIn(category.types) &
            m.seq.isBiggerThanValue(0),
      );
    if (before != null) {
      query.where(
        (m) =>
            m.seq.isSmallerThanValue(before.seq) |
            (m.seq.equals(before.seq) &
                m.entityIndex.isSmallerThanValue(before.key)),
      );
    }
    if (after != null) {
      query.where(
        (m) =>
            m.seq.isBiggerThanValue(after.seq) |
            (m.seq.equals(after.seq) &
                m.entityIndex.isBiggerThanValue(after.key)),
      );
    }
    query
      ..orderBy([
        (m) =>
            after == null ? OrderingTerm.desc(m.seq) : OrderingTerm.asc(m.seq),
        (m) => after == null
            ? OrderingTerm.desc(m.entityIndex)
            : OrderingTerm.asc(m.entityIndex),
      ])
      ..limit(limit);
    return (await query.get()).map(_toMedia).toList()..sort(MediaItem.compare);
  }

  Future<MediaItem?> _mediaItem(
    String scope,
    String topicId,
    MediaCursor cursor,
  ) async {
    final row =
        await (select(mediaEntries)..where(
              (m) =>
                  m.scope.equals(scope) &
                  m.topicId.equals(topicId) &
                  m.seq.equals(cursor.seq) &
                  m.entityIndex.equals(cursor.key),
            ))
            .getSingleOrNull();
    return row == null ? null : _toMedia(row);
  }

  MediaItem _toMedia(MediaEntryRow row) => MediaItem(
    topicId: row.topicId,
    messageId: row.clientId,
    seq: row.seq,
    entityIndex: row.entityIndex,
    type: row.type,
    data: Map<String, dynamic>.from(jsonDecode(row.data) as Map),
    senderId: row.senderId,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row.createdAtMs,
      isUtc: true,
    ),
    inline: row.isInline,
  );

  Future<void> _removeMedia(String scope, String topicId, int low, int high) =>
      (delete(mediaEntries)..where(
            (m) =>
                m.scope.equals(scope) &
                m.topicId.equals(topicId) &
                m.seq.isBiggerOrEqualValue(low) &
                m.seq.isSmallerThanValue(high),
          ))
          .go();
}
