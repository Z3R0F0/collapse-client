part of 'chat_cubit.dart';

extension _ChatOpen on ChatCubit {
  Future<void> _open(String topicId, {int? aroundSeq, String? aroundId}) async {
    final sameTopic =
        _topicId == topicId &&
        _accountId == repository.currentUserId &&
        _sessionGeneration == repository.sessionGeneration;
    final generation = ++_generation;
    _topicId = topicId;
    _accountId = repository.currentUserId;
    _sessionGeneration = repository.sessionGeneration;
    final latest = aroundSeq == null && aroundId == null;
    _followingLive = latest;
    _awaitingLatestTail = false;
    // Cancel both old listeners before yielding: an overlapping open must not
    // have its new listener canceled by this navigation's continuation.
    await Future.wait<void>([
      if (_subscription != null) _subscription!.cancel(),
      if (_unreadSubscription != null) _unreadSubscription!.cancel(),
    ]);
    if (!_active(generation)) return;
    final ready = Completer<void>();
    _updates = ready.future;
    // Keep the old rendered snapshot until its replacement is complete.
    _publish(
      state.copyWith(
        loading: true,
        unreadCount: sameTopic ? state.unreadCount : 0,
        clearPaging: true,
        clearError: true,
      ),
    );
    // The same DB-derived count as Home; never a distance from a window cursor.
    // Reads must update it even while a history request is still pending.
    _unreadSubscription = repository
        .watchTopic(topicId)
        .map((topic) => topic?.unreadCount ?? 0)
        .distinct()
        .listen((count) {
          if (_active(generation) && count != state.unreadCount) {
            _publish(state.copyWith(unreadCount: count));
          }
        });
    _subscription = repository.changesFor(topicId).listen((event) {
      final allowArrival = !state.loading;
      _serialize(
        generation,
        () => _changed(event, allowArrival: allowArrival),
      ).ignore();
    });
    try {
      var window = await repository.openHistory(
        topicId,
        aroundSeq: aroundSeq,
        aroundId: aroundId,
      );
      if (!_active(generation)) return;
      if (window != null) {
        window = await repository.inspectHistoryWindow(
          topicId,
          window.span,
          capacity: WindowPolicy.pageSize,
          retain: latest ? HistoryDirection.newer : HistoryDirection.older,
        );
        if (!_active(generation)) return;
      }
      final target = latest
          ? null
          : window?.messages
                .where(
                  (message) => aroundId != null
                      ? message.id == aroundId
                      : message.seq == aroundSeq,
                )
                .firstOrNull;
      if (window == null || (!latest && target == null)) {
        final previous = state.window;
        final retained = previous == null
            ? null
            : await repository.inspectHistoryWindow(topicId, previous.span);
        if (_active(generation)) {
          _publish(
            state.copyWith(
              window: retained,
              loading: false,
              error: latest
                  ? 'load_failed'
                  : previous == null
                  ? 'message_unavailable'
                  : null,
            ),
          );
        }
        return;
      }
      _visibleIds = const {};
      _publish(
        ChatState(
          window: window,
          unreadCount: state.unreadCount,
          navigationEpoch: state.navigationEpoch + 1,
          targetId: target?.id,
          revision: state.revision + 1,
        ),
      );
    } catch (_) {
      if (_active(generation)) {
        _publish(state.copyWith(loading: false, error: 'load_failed'));
      }
    } finally {
      ready.complete();
    }
  }
}
