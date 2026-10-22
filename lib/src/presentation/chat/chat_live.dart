part of 'chat_cubit.dart';

extension _ChatLive on ChatCubit {
  Future<void> _changed(ChatChange change, {required bool allowArrival}) async {
    final window = state.window;
    if (state.loading || window == null || isClosed) return;
    final generation = _generation;
    if (change.historySync == HistorySyncPhase.started) {
      _awaitingLatestTail = _followingLive;
      return;
    }
    if (change.historySync == HistorySyncPhase.failed) {
      _awaitingLatestTail = false;
      // Keep this span, but refresh availability learned from metadata before
      // the failed fetch. A cache island must not claim the global live end.
    }
    final message = change.message;
    if (!change.reset && message == null) return;
    final exists =
        message != null && window.messages.any((item) => item.id == message.id);
    final following = _followingLive;
    if (_awaitingLatestTail &&
        change.historySync == HistorySyncPhase.completed) {
      _awaitingLatestTail = false;
      if (following) {
        final latest = await repository.cachedHistory(
          change.topicId,
          limit: WindowPolicy.pageSize,
        );
        if (!_active(generation)) return;
        if (_followingLive &&
            state.window?.span == window.span &&
            latest != null &&
            latest.span.server.end > window.span.server.end) {
          // The complete tail replaces the cached island quietly. This is not
          // navigation or a live arrival; no extra request or motion is needed.
          _publish(state.copyWith(window: latest));
          return;
        }
      }
    }
    // Re-read one atomic span: ACKs, deletions and receipts are authoritative
    // in the DB. A pending local suffix is never a server-history frontier.
    final next = await repository.inspectHistoryWindow(
      change.topicId,
      window.span,
      retain: following ? HistoryDirection.newer : HistoryDirection.older,
      include:
          following &&
              !exists &&
              change.origin != ChatChangeOrigin.update &&
              !(_awaitingLatestTail &&
                  change.origin == ChatChangeOrigin.history)
          ? message
          : null,
    );
    if (!_active(generation) || next == null) return;
    final admitted =
        message != null && next.messages.any((item) => item.id == message.id);
    _publish(
      state.copyWith(
        window: next,
        arrivalIds:
            allowArrival &&
                following &&
                !exists &&
                admitted &&
                change.origin == ChatChangeOrigin.arrival
            ? {message.id}
            : const {},
      ),
    );
  }
}
