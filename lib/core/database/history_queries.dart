part of 'app_database.dart';

extension _HistoryQueries on AppDatabase {
  Future<void> _hideMessageRow(String scope, String topicId, int seq) =>
      transaction(() async {
        await _removeMedia(scope, topicId, seq, seq + 1);
        await (update(messages)..where(
              (m) =>
                  m.scope.equals(scope) &
                  m.topicId.equals(topicId) &
                  m.seq.equals(seq),
            ))
            .write(const MessagesCompanion(hidden: Value(true)));
        await refreshSummary(scope, topicId);
      });

  Future<void> _applyMessageDeletions(
    String scope,
    String topicId,
    List<Map<String, dynamic>> ranges,
    int deletionId,
  ) => transaction(() async {
    final topic = await topicRow(scope, topicId);
    final remembered = (jsonDecode(topic?.deletedRanges ?? '[]') as List)
        .map((r) => List<int>.from(r as List))
        .toList();
    for (final range in ranges) {
      final low = AppDatabase.intValue(range['low']);
      final hi = AppDatabase.intValue(range['hi'], low + 1);
      if (low <= 0 || hi <= low) continue;
      remembered.add([low, hi]);
      await _removeMedia(scope, topicId, low, hi);
      await (update(messages)..where(
            (m) =>
                m.scope.equals(scope) &
                m.topicId.equals(topicId) &
                m.seq.isBiggerOrEqualValue(low) &
                m.seq.isSmallerThanValue(hi),
          ))
          .write(const MessagesCompanion(deleted: Value(true)));
      await _writeHistoryCoverage(scope, topicId, low, hi);
    }
    remembered.sort((a, b) => a[0].compareTo(b[0]));
    final merged = <List<int>>[];
    for (final range in remembered) {
      if (merged.isNotEmpty && range[0] <= merged.last[1]) {
        merged.last[1] = max(merged.last[1], range[1]);
      } else {
        merged.add(range);
      }
    }
    await (update(topics)
          ..where((t) => t.scope.equals(scope) & t.id.equals(topicId)))
        .write(TopicsCompanion(deletedRanges: Value(jsonEncode(merged))));
    await customUpdate(
      'UPDATE topics SET deletion_id = MAX(deletion_id, ?) WHERE scope = ? AND id = ?',
      variables: [Variable(deletionId), Variable(scope), Variable(topicId)],
      updates: {topics},
    );
    await refreshSummary(scope, topicId);
  });

  Future<void> _recordHistoryCoverage(
    String scope,
    String topicId,
    int start,
    int end,
  ) => transaction(() => _writeHistoryCoverage(scope, topicId, start, end));

  // Merge and deletion already own a transaction. Reuse it so their coverage
  // stays atomic without nesting the web OPFS navigator-lock interceptor.
  Future<void> _writeHistoryCoverage(
    String scope,
    String topicId,
    int start,
    int end,
  ) async {
    if (start >= end) return;
    final topic = await topicRow(scope, topicId);
    if (topic == null) return;
    final ranges =
        (jsonDecode(topic.coverage) as List)
            .map((r) => List<int>.from(r as List))
            .toList()
          ..add([start, end]);
    ranges.sort((a, b) => a[0].compareTo(b[0]));
    final merged = <List<int>>[];
    for (final range in ranges) {
      if (merged.isNotEmpty && range[0] <= merged.last[1]) {
        merged.last[1] = max(merged.last[1], range[1]);
      } else {
        merged.add(range);
      }
    }
    await (update(topics)
          ..where((t) => t.scope.equals(scope) & t.id.equals(topicId)))
        .write(TopicsCompanion(coverage: Value(jsonEncode(merged))));
  }
}
