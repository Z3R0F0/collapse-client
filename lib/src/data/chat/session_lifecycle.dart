part of 'chats_repository.dart';

extension _SessionLifecycle on ChatsRepository {
  Future<void> _startSession(String userId) async {
    final nextScope = '$serverId|$userId';
    if (_scope != nextScope) {
      await stop();
      _scope = nextScope;
      _userId = userId;
      final generation = _generation;
      try {
        await database.resetAcknowledgedOrigins(nextScope);
        if (_scope != nextScope || _generation != generation) return;
        final queued = await database.pendingOutbox(nextScope);
        if (_scope != nextScope || _generation != generation) return;
        _lastLocalSeq = queued.lastOrNull?.localSeq ?? 0;
        _subscription = gateway.events.listen((event) {
          // Tinode history also uses the global data stream. Capture provenance
          // on receipt: its request may finish while this event waits in the tail.
          final topic = event.topic ?? event.payload['topic']?.toString();
          final origin = (_historyRequests[topic] ?? 0) > 0
              ? ChatChangeOrigin.history
              : ChatChangeOrigin.arrival;
          _eventTail = _eventTail
              .then((_) async {
                if (generation != _generation) return;
                await _handleEvent(event, nextScope, origin: origin);
              })
              .catchError((Object _) {
                // Transport/session errors are shown by the owning connection Cubit.
              });
        });
      } catch (_) {
        // A failed local initialization must not leave a same-scope session
        // which skips initialization/subscription on the next attempt.
        if (_scope == nextScope && _generation == generation) await stop();
        rethrow;
      }
    }
    if (_networkReady) {
      // start owns durable local initialization, not the duration of every
      // remote chat refresh. Explicit refreshTopics remains awaitable.
      unawaited(refreshTopics().catchError((Object _) {}));
      unawaited(flushOutbox());
    }
  }

  Future<void> _stopSession() async {
    _generation++;
    if (_flushing != null || _refreshing != null || _topicSyncs.isNotEmpty) {
      // Logout stays nonblocking, but disposal must still own a late accepted
      // publish ACK, even after a replacement session clears these handles.
      _retiredWorkers = Future.wait<void>(
        [
          _retiredWorkers,
          ?_flushing,
          ?_refreshing,
          ..._topicSyncs.values,
        ].map((task) => task.catchError((Object _) {})),
      ).then<void>((_) {});
    }
    _historyRequests.clear();
    _retryTimer?.cancel();
    _retryTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    _attached.clear();
    _attaching.clear();
    _topicSyncs.clear();
    _sequenceCache.clear();
    _searchPrepared.clear();
    _refreshing = null;
    _flushing = null;
    _scope = null;
    _userId = null;
  }

  Future<void> _disposeSession() async {
    await stop();
    // Unlike logout, disposal is a barrier before the caller closes SQLite.
    // Invalidate first, then finish existing workers (transport has its normal
    // timeout); no old event/ACK continuation may race the database close.
    await Future.wait(
      [
        _eventTail,
        _localWrites,
        _retiredWorkers,
      ].map((task) => task.catchError((Object _) {})),
    );
    // Cubit snapshot reads may already own a transaction outside those tails.
    // Drift's native close does not itself acquire the transaction lock.
    await database.exclusively(() async {});
    await _changes.close();
  }
}
