part of 'app_database.dart';

extension _TopicQueries on AppDatabase {
  Future<TopicRow?> _findTopicRow(String scope, String id) => (select(
    topics,
  )..where((t) => t.scope.equals(scope) & t.id.equals(id))).getSingleOrNull();

  Stream<List<ChatTopic>> _watchTopicList(String scope, String userId) =>
      _selectTopicSummaries(scope, userId).watch();

  Stream<ChatTopic?> _watchSingleTopic(
    String scope,
    String id,
    String userId,
  ) => _selectTopicSummaries(scope, userId, id: id).watchSingleOrNull();

  ChatTopic _mapTopicRow(TopicRow row, {required int unreadCount}) => ChatTopic(
    id: row.id,
    title: row.title,
    avatarRef: row.avatarRef,
    online: row.online,
    isGroup: row.isGroup,
    serverSeq: row.serverSeq,
    readSeq: row.readSeq,
    recvSeq: row.recvSeq,
    peerReadSeq: row.peerReadSeq,
    peerRecvSeq: row.peerRecvSeq,
    unreadCount: unreadCount,
    lastPreview: row.lastPreview,
    lastMessageAt: row.lastMessageAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.lastMessageAt!, isUtc: true),
    draft: row.draft,
  );

  Future<void> _mergeTopicRow(
    String scope,
    String id,
    Map<String, dynamic> data,
  ) => transaction(() async {
    final old = await topicRow(scope, id);
    final pub = data['public'] is Map ? data['public'] as Map : const {};
    final photo = pub['photo'];
    var avatar = photo is Map ? photo['ref']?.toString() : null;
    if (avatar?.isEmpty ?? false) avatar = null;
    if (avatar == null &&
        photo is Map &&
        photo['data'] is String &&
        (photo['data'] as String).isNotEmpty) {
      final type = photo['type']?.toString() ?? 'jpeg';
      avatar =
          'data:${type.contains('/') ? type : 'image/$type'};base64,${photo['data']}';
    }
    final title = pub['fn']?.toString() ?? old?.title ?? id;
    await into(topics).insertOnConflictUpdate(
      TopicsCompanion.insert(
        scope: scope,
        id: id,
        title: title,
        avatarRef: Value(pub.containsKey('photo') ? avatar : old?.avatarRef),
        online: Value(
          data['online'] is bool
              ? data['online'] as bool
              : old?.online ?? false,
        ),
        isGroup: Value(id.startsWith('grp')),
        serverSeq: Value(
          max(old?.serverSeq ?? 0, AppDatabase.intValue(data['seq'])),
        ),
        readSeq: Value(
          max(old?.readSeq ?? 0, AppDatabase.intValue(data['read'])),
        ),
        recvSeq: Value(
          max(old?.recvSeq ?? 0, AppDatabase.intValue(data['recv'])),
        ),
        peerReadSeq: Value(old?.peerReadSeq ?? 0),
        peerRecvSeq: Value(old?.peerRecvSeq ?? 0),
        lastMessageSeq: Value(old?.lastMessageSeq ?? 0),
        lastMessageAt: Value(old?.lastMessageAt),
        lastPreview: Value(old?.lastPreview ?? ''),
        draft: Value(old?.draft ?? ''),
        deletionId: Value(old?.deletionId ?? 0),
        coverage: Value(old?.coverage ?? '[]'),
        deletedRanges: Value(old?.deletedRanges ?? '[]'),
      ),
    );
  });

  Future<void> _setTopicPresence(String scope, String id, bool online) =>
      (update(topics)..where((t) => t.scope.equals(scope) & t.id.equals(id)))
          .write(TopicsCompanion(online: Value(online)));

  Future<void> _markTopicsOffline(String scope) async {
    await (update(topics)..where((t) => t.scope.equals(scope))).write(
      const TopicsCompanion(online: Value(false)),
    );
  }

  Future<void> _setTopicDraft(String scope, String id, String text) async {
    await (update(topics)
          ..where((t) => t.scope.equals(scope) & t.id.equals(id)))
        .write(TopicsCompanion(draft: Value(text)));
  }

  Future<void> _clearTopicDraftIfMatches(
    String scope,
    String id,
    String expected,
  ) async {
    await (update(topics)..where(
          (t) =>
              t.scope.equals(scope) &
              t.id.equals(id) &
              t.draft.equals(expected),
        ))
        .write(const TopicsCompanion(draft: Value('')));
  }
}
