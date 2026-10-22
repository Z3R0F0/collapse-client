part of 'chats_repository.dart';

extension _TopicSync on ChatsRepository {
  Future<void> _ensureTopic(String topicId) async {
    final scope = _activeScope;
    final generation = _generation;
    final userId = currentUserId;
    bool active() => _historyActive(scope, generation);
    if (!_networkReady) {
      if (await database.topicRow(scope, topicId) == null && active()) {
        await database.mergeTopic(scope, topicId, const {});
      }
      return;
    }
    await _attach(topicId);
    if (!active()) return;
    final desc = await gateway.description(topicId);
    if (!active()) return;
    await database.mergeTopic(scope, topicId, desc);
    if (!active()) return;
    final peers = await gateway.subscriptions(topic: topicId);
    if (!active()) return;
    for (final peer in peers) {
      if (!active()) return;
      if (peer['user'] != userId && peer['deleted'] == null) {
        await database.receipts(
          scope,
          topicId,
          userId,
          peerRead: AppDatabase.intValue(peer['read']),
          peerRecv: AppDatabase.intValue(peer['recv']),
        );
      }
    }
    if (!active()) return;
    await _syncDeletions(scope, topicId);
  }

  /// One owned background reconciliation per topic/session. A cached open and
  /// the account refresh share it; neither fetches an already covered tail.
  Future<void> _reconcileTopic(String topicId) {
    if (!_networkReady) return Future.value();
    final scope = _activeScope, generation = _generation;
    final shared = _topicSyncs.putIfAbsent(topicId, () {
      late final Future<void> task;
      task =
          (() async {
            await ensureTopic(topicId);
            if (!_historyActive(scope, generation)) return;
            final topic = await database.topicRow(scope, topicId);
            if (topic == null || !_historyActive(scope, generation)) {
              return;
            }
            await _expandServerHistory(
              scope,
              generation,
              topicId,
              SequenceRange(topic.serverSeq + 1, topic.serverSeq + 1),
              HistoryDirection.older,
              40,
            );
          })().whenComplete(() {
            if (identical(_topicSyncs[topicId], task)) {
              _topicSyncs.remove(topicId);
            }
          });
      return task;
    });
    // A cached open can join work which predates its subscription. Replay a
    // balanced lifecycle to this caller, without duplicating the shared I/O.
    _changes.add(ChatChange(topicId, historySync: HistorySyncPhase.started));
    return shared.then(
      (_) {
        if (_historyActive(scope, generation)) {
          _changes.add(
            ChatChange(
              topicId,
              reset: true,
              origin: ChatChangeOrigin.history,
              historySync: HistorySyncPhase.completed,
            ),
          );
        }
      },
      onError: (Object error, StackTrace stack) {
        if (_historyActive(scope, generation)) {
          _changes.add(
            ChatChange(
              topicId,
              reset: true,
              historySync: HistorySyncPhase.failed,
            ),
          );
        }
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  Future<void> _attach(String topicId) {
    if (_attached.contains(topicId)) return Future.value();
    return _attaching.putIfAbsent(topicId, () async {
      final generation = _generation;
      try {
        await gateway.attach(topicId);
        if (generation == _generation) _attached.add(topicId);
      } finally {
        if (generation == _generation) _attaching.remove(topicId);
      }
    });
  }

  Future<void> _refreshTopicList() {
    if (!_networkReady) return Future.value();
    if (_refreshing != null) return _refreshing!;
    final task = _refreshTopics();
    _refreshing = task;
    return task.whenComplete(() {
      if (identical(_refreshing, task)) _refreshing = null;
    });
  }

  Future<void> _refreshTopics() async {
    final scope = _activeScope;
    final generation = _generation;
    bool active() => _scope == scope && _generation == generation;
    await _attach('me');
    if (!active()) return;
    final subscriptions = await gateway.subscriptions();
    if (!active()) return;
    for (final data in subscriptions) {
      if (!active()) return;
      final id = data['topic']?.toString();
      if (id == null || id == 'me' || data['deleted'] != null) continue;
      await database.mergeTopic(scope, id, data);
      if (!active()) return;
      try {
        await _reconcileTopic(id);
        if (!active()) return;
        final topic = await database.topicRow(scope, id);
        if (!active()) return;
        if (topic != null && _networkReady) {
          if (topic.recvSeq > 0) gateway.note(id, 'recv', seq: topic.recvSeq);
          if (topic.readSeq > 0) gateway.note(id, 'read', seq: topic.readSeq);
        }
      } catch (_) {
        // One inaccessible/removed chat must not prevent offline access to others.
      }
    }
  }
}
