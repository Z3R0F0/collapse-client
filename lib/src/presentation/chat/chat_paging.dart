part of 'chat_cubit.dart';

extension _ChatPaging on ChatCubit {
  Future<void> _loadPage(HistoryDirection direction) async {
    final window = state.window;
    if (_topicId == null ||
        window == null ||
        state.loading ||
        state.paging != null) {
      return;
    }
    final edge = direction == HistoryDirection.older
        ? window.older
        : window.newer;
    if (!edge.canLoad) return;
    final generation = _generation;
    final base = window.span;
    final ids = window.messages.map((message) => message.id).toSet();
    final anchorId = _visibleIds.where(ids.contains).firstOrNull;
    _publish(state.copyWith(paging: direction, clearError: true));
    try {
      final next = await repository.extendHistory(
        _topicId!,
        base,
        direction: direction,
        capacity: WindowPolicy.capacity,
        anchorId: anchorId,
      );
      await _serialize(generation, () async {
        if (next == null) {
          _publish(state.copyWith(clearPaging: true));
          return;
        }
        final refreshed = await repository.inspectHistoryWindow(
          _topicId!,
          next.span,
          retain: direction,
          capacity: WindowPolicy.capacity,
        );
        if (!_active(generation) || refreshed == null) return;
        final nextIds = refreshed.messages.map((message) => message.id).toSet();
        final tail = state.messages.lastOrNull;
        var evictedTail = false;
        if (_followingLive &&
            direction == HistoryDirection.older &&
            tail != null &&
            !nextIds.contains(tail.id)) {
          // A committed older window can leave the followed tail. Distinguish
          // actual eviction from deletion/hidden content using one stable ID,
          // not a potentially stale server sequence or availability flag.
          evictedTail = (await repository.reloadWindow(_topicId!, [
            tail,
          ])).isNotEmpty;
          if (!_active(generation)) return;
        }
        final currentIds = state.messages.map((message) => message.id).toSet();
        final painted = _visibleIds.where(currentIds.contains);
        final rebaseAnchor = next.rebaseAnchorId;
        final keepsViewport = rebaseAnchor == null
            ? painted.every(nextIds.contains)
            : nextIds.contains(rebaseAnchor) &&
                  (painted.isEmpty || painted.first == rebaseAnchor);
        // The fetch may cache useful rows, but it cannot replace a newer span
        // or evict a viewport reached while this request was in flight. ACK
        // order normalization keeps the first painted key; non-monotonic ACKs
        // can put its old neighbors hundreds of server sequences apart.
        if (state.window?.span != base || !keepsViewport) {
          _publish(state.copyWith(clearPaging: true));
          return;
        }
        if (evictedTail) setFollowingLive(false);
        _publish(
          state.copyWith(
            window: rebaseAnchor == null
                ? refreshed
                : HistoryWindow(
                    refreshed.messages,
                    span: refreshed.span,
                    older: refreshed.older,
                    newer: refreshed.newer,
                    rebaseAnchorId: rebaseAnchor,
                  ),
            clearPaging: true,
          ),
        );
      });
    } catch (_) {
      if (_active(generation)) {
        _publish(state.copyWith(clearPaging: true, error: 'load_failed'));
      }
    }
  }
}
