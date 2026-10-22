part of 'chats_repository.dart';

extension _MessageSearch on ChatsRepository {
  Future<SearchPage?> _searchMessages(
    String topicId,
    String query, {
    SearchCursor? before,
    int limit = 40,
  }) async {
    final scope = _scope, generation = _generation;
    if (scope == null) return null;
    bool active() => _scope == scope && _generation == generation;
    if (!_searchPrepared.contains(topicId)) {
      final ready = await database.prepareSearch(scope, topicId);
      if (!active()) return null;
      if (ready) _searchPrepared.add(topicId);
    }
    final count = limit.clamp(1, 40);
    final hits = await database.searchMessages(
      scope,
      topicId,
      query,
      before: before,
      limit: count + 1,
    );
    if (!active()) return null;
    final topic = await database.topicRow(scope, topicId);
    if (!active()) return null;
    final complete = topic != null && _searchGap(topic) == null;
    final indexed = _searchPrepared.contains(topicId);
    final visible = hits.take(count).toList();
    return SearchPage(
      hits: List.unmodifiable(visible),
      nextCursor: indexed && hits.length > count ? visible.last.cursor : null,
      cacheIndexed: indexed,
      historyComplete: complete,
      canLoadHistory: !complete && _networkReady,
    );
  }

  Future<bool?> _loadMoreSearchHistory(String topicId) async {
    final scope = _scope, generation = _generation;
    if (scope == null) return null;
    bool active() => _scope == scope && _generation == generation;
    if (!_networkReady) return false;
    await ensureTopic(topicId);
    if (!active()) return null;
    final topic = await database.topicRow(scope, topicId);
    if (!active()) return null;
    if (topic == null) return false;
    final gap = _searchGap(topic);
    if (gap == null) return false;
    await _fetch(scope, topicId, since: gap.$1, before: gap.$2, limit: 40);
    return active() ? true : null;
  }

  /// Newest missing half-open interval, including internal cache gaps.
  (int, int)? _searchGap(TopicRow topic) {
    var end = topic.serverSeq + 1;
    final coverage = (jsonDecode(topic.coverage) as List).map(
      (range) => List<int>.from(range as List),
    );
    for (final range in coverage.toList().reversed) {
      if (end <= 1) return null;
      if (range[0] >= end) continue;
      if (range[1] < end) return (max(range[1], end - 40), end);
      end = range[0];
    }
    return end <= 1 ? null : (max(1, end - 40), end);
  }
}
