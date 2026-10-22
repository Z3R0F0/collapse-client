part of 'chats_repository.dart';

extension _RealtimeEvents on ChatsRepository {
  Future<void> _handleEvent(
    TinodeEvent event,
    String scope, {
    required ChatChangeOrigin origin,
  }) async {
    final payload = event.payload;
    final topicId = event.topic ?? payload['topic']?.toString();
    switch (event.kind) {
      case 'data':
        await _storeData(scope, payload, origin: origin);
      case 'info':
        if (topicId == null) return;
        final what = payload['what'];
        final seq = AppDatabase.intValue(payload['seq']);
        final self = payload['from'] == currentUserId;
        if (what == 'read' || what == 'recv') {
          await database.receipts(
            scope,
            topicId,
            currentUserId,
            read: self && what == 'read' ? seq : null,
            recv: self && what == 'recv' ? seq : null,
            peerRead: !self && what == 'read' ? seq : null,
            peerRecv: !self && what == 'recv' ? seq : null,
          );
          _changes.add(ChatChange(topicId, reset: true));
        }
      case 'pres':
        final id = topicId == 'me' ? payload['src']?.toString() : topicId;
        if (id == null) return;
        final what = payload['what'];
        if (what == 'on' || what == 'off') {
          await database.setPresence(scope, id, what == 'on');
        }
        if (what == 'msg') {
          await database.mergeTopic(scope, id, {'seq': payload['seq']});
          // A new P2P conversation first arrives through `me`: its body is not
          // included there. Attach once and populate the initial preview/tail.
          // Already attached topics deliver data directly without resubscription.
          if (_scope == scope && _networkReady && !_attached.contains(id)) {
            await ensureTopic(id);
            if (_scope != scope) return;
            await _fetch(scope, id, limit: 40);
          }
          _changes.add(ChatChange(id, reset: true));
        }
        if ((what == 'acs' || what == 'upd') &&
            id != 'me' &&
            _scope == scope &&
            _networkReady) {
          try {
            final attached = _attached.contains(id);
            await ensureTopic(id);
            if (_scope != scope) return;
            if (!attached) await _fetch(scope, id, limit: 40);
            _changes.add(ChatChange(id, reset: true));
          } catch (_) {
            // Access changes may revoke this topic. Keep other chats running.
          }
        }
        if (what == 'del' && _networkReady) await _syncDeletions(scope, id);
        if (what == 'read' || what == 'recv') {
          await database.receipts(
            scope,
            id,
            currentUserId,
            read: what == 'read' ? AppDatabase.intValue(payload['seq']) : null,
            recv: what == 'recv' ? AppDatabase.intValue(payload['seq']) : null,
          );
        }
      case 'meta':
        if (topicId != null && topicId != 'me' && payload['desc'] is Map) {
          await database.mergeTopic(
            scope,
            topicId,
            Map<String, dynamic>.from(payload['desc'] as Map),
          );
        }
      case 'disconnected':
        final topics = _attached.where((id) => id != 'me').toList();
        final generation = _generation;
        _attached.clear();
        _attaching.clear();
        await database.markOffline(scope);
        if (_scope == scope && _generation == generation) {
          for (final id in topics) {
            _changes.add(ChatChange(id, reset: true));
          }
        }
    }
  }

  Future<ChatMessage?> _storeData(
    String scope,
    Map<String, dynamic> packet, {
    required ChatChangeOrigin origin,
  }) {
    final topic = packet['topic']?.toString();
    final seq = AppDatabase.intValue(packet['seq']);
    if (_scope != scope ||
        topic == null ||
        seq <= 0 ||
        packet['content'] == null) {
      return Future.value();
    }
    // The same immutable Tinode sequence arrives through the global stream and
    // a history result. Join while storage is pending, before the completed
    // sequence cache can protect it. Receipts and ACK merges keep their owners.
    final key = (scope, _generation, topic, seq);
    return _storingMessages.putIfAbsent(key, () {
      return _storeDataOnce(scope, packet, origin: origin).whenComplete(() {
        _storingMessages.remove(key);
      });
    });
  }

  Future<ChatMessage?> _storeDataOnce(
    String scope,
    Map<String, dynamic> packet, {
    required ChatChangeOrigin origin,
  }) async {
    if (_scope != scope) return null;
    final generation = _generation;
    final topicId = packet['topic']?.toString();
    final seq = AppDatabase.intValue(packet['seq']);
    if (topicId == null || seq <= 0 || packet['content'] == null) return null;
    final sender = packet['from']?.toString() ?? '';
    final existing = await database.messageRow(scope, topicId, seq);
    if (_sequenceCache.contains(topicId, seq) && existing != null) {
      return database.toMessage(existing);
    }
    final head = packet['head'] is Map
        ? Map<String, dynamic>.from(packet['head'] as Map)
        : <String, dynamic>{};
    final id = sender == currentUserId && head['x-client-id'] is String
        ? head['x-client-id'] as String
        : '$topicId:$seq';
    final local = sender == currentUserId
        ? await database.messageById(scope, id)
        : null;
    final known =
        existing != null ||
        (local?.topicId == topicId && local?.senderId == sender);
    if (await database.topicRow(scope, topicId) == null) {
      await database.mergeTopic(scope, topicId, const {});
    }
    if (_generation != generation || _scope != scope) return null;
    final message = await database.mergeMessage(
      scope,
      ChatMessage(
        id: id,
        topicId: topicId,
        seq: seq,
        localSeq: local?.localSeq ?? 0,
        senderId: sender,
        createdAt: ChatsRepository._timestamp(packet['ts']),
        content: packet['content'] as Object,
        head: head,
      ),
      currentUserId,
    );
    if (_generation != generation || _scope != scope) return message;
    _sequenceCache.add(topicId, seq);
    // mergeMessage stores this row's coverage in the same transaction.
    _changes.add(
      ChatChange(
        topicId,
        message: message,
        origin: known ? ChatChangeOrigin.update : origin,
      ),
    );
    if (sender != currentUserId) {
      await database.receipts(scope, topicId, currentUserId, recv: seq);
      if (_scope == scope && _generation == generation && _networkReady) {
        gateway.note(topicId, 'recv', seq: seq);
      }
    }
    return message;
  }
}
