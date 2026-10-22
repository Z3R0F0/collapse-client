part of 'chats_repository.dart';

extension _MessageActions on ChatsRepository {
  Future<void> _markVisibleRead(String topicId, int seq) async {
    final scope = _activeScope;
    final topic = await database.topicRow(scope, topicId);
    // Tinode read notes are cumulative watermarks, not per-message receipts.
    // The UI must call this only for an actually visible foreground message.
    final read = min(seq, topic?.serverSeq ?? 0);
    if (read <= 0 || read <= (topic?.readSeq ?? 0)) return;
    await database.receipts(scope, topicId, currentUserId, read: read);
    if (_scope == scope && _networkReady) {
      gateway.note(topicId, 'read', seq: read);
    }
  }

  Future<void> _hideLocalMessage(ChatMessage message) async {
    final scope = _activeScope;
    await database.hide(scope, message.topicId, message.seq);
    if (_scope == scope) _changes.add(ChatChange(message.topicId, reset: true));
  }

  Future<void> _deleteMessage(
    ChatMessage message, {
    bool forEveryone = false,
  }) async {
    if (message.pending) {
      final scope = _activeScope;
      await database.cancelPending(scope, message);
      if (_scope == scope) {
        _changes.add(ChatChange(message.topicId, reset: true));
      }
      return;
    }
    if (!_networkReady) throw StateError('Deletion requires a connection');
    final scope = _activeScope;
    final generation = _generation;
    await _attach(message.topicId);
    if (_scope != scope || _generation != generation) return;
    await gateway.deleteMessages(message.topicId, [
      {'low': message.seq},
    ], hard: forEveryone);
    await database.applyDeletions(scope, message.topicId, [
      {'low': message.seq},
    ], 0);
    if (_scope == scope && _generation == generation) {
      _changes.add(ChatChange(message.topicId, reset: true));
    }
  }

  Future<void> _syncDeletions(String scope, String topicId) async {
    if (_scope != scope) return;
    final generation = _generation;
    final topic = await database.topicRow(scope, topicId);
    if (!_historyActive(scope, generation)) return;
    final data = await gateway.deletions(
      topicId,
      since: (topic?.deletionId ?? 0) + 1,
    );
    if (!_historyActive(scope, generation)) return;
    final ranges = data['delseq'];
    if (ranges is List) {
      await database.applyDeletions(
        scope,
        topicId,
        ranges
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList(),
        AppDatabase.intValue(data['clear']),
      );
      if (_historyActive(scope, generation)) {
        _changes.add(ChatChange(topicId, reset: true));
      }
    }
  }
}
