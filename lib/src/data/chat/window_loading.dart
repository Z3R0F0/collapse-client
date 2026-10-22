part of 'chats_repository.dart';

/// Compatibility adapters share the explicit-span navigation implementation.
extension _WindowLoading on ChatsRepository {
  Future<MessagePage> _loadBeforeMessage(
    ChatMessage message, {
    int limit = 40,
  }) => _pageFromMessage(message, HistoryDirection.older, limit);

  Future<MessagePage> _loadAfterMessage(
    ChatMessage message, {
    int limit = 40,
  }) => _pageFromMessage(message, HistoryDirection.newer, limit);

  Future<MessagePage> _pageFromMessage(
    ChatMessage message,
    HistoryDirection direction,
    int limit,
  ) async {
    final scope = _scope, generation = _generation;
    if (scope == null) return const MessagePage([], hasMore: false);
    final row = await database.messageById(scope, message.id);
    if (!_historyActive(scope, generation)) {
      return const MessagePage([], hasMore: false);
    }
    if (row != null) message = database.toMessage(row);
    final topic = await database.topicRow(scope, message.topicId);
    if (topic == null || !_historyActive(scope, generation)) {
      return const MessagePage([], hasMore: false);
    }
    final span = message.pending
        ? HistorySpan(
            server: SequenceRange(topic.serverSeq + 1, topic.serverSeq + 1),
            local: SequenceRange(message.localSeq, message.localSeq + 1),
            retainedLocalIds: {message.id},
          )
        : HistorySpan(server: SequenceRange(message.seq, message.seq + 1));
    final window = await _extendHistory(
      message.topicId,
      span,
      direction: direction,
      limit: limit,
      capacity: limit + 1,
    );
    return MessagePage(
      window?.messages.where((row) => row.id != message.id).toList() ?? [],
      hasMore:
          (direction == HistoryDirection.older ? window?.older : window?.newer)
              ?.canLoad ??
          false,
    );
  }

  Future<bool> _hasCachedMessageAfter(ChatMessage message) async {
    final scope = _scope, generation = _generation;
    if (scope == null) return false;
    final row = await database.messageById(scope, message.id);
    if (row != null) message = database.toMessage(row);
    if (!_historyActive(scope, generation)) return false;
    if (!message.pending &&
        (await database.page(
          scope,
          message.topicId,
          since: message.seq,
          limit: 1,
        )).isNotEmpty) {
      return true;
    }
    final pending = await database.pendingMessages(
      scope,
      message.topicId,
      since: message.pending ? message.localSeq : 0,
      limit: 1,
    );
    return _historyActive(scope, generation) && pending.isNotEmpty;
  }
}
