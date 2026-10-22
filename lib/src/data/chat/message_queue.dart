part of 'chats_repository.dart';

extension _MessageQueue on ChatsRepository {
  /// Serialize only short local writes, never transport or viewport work.
  Future<T> _writeLocal<T>(
    String scope,
    int generation,
    Future<T> Function() write,
  ) {
    final result = _localWrites.then((_) {
      if (_scope != scope || _generation != generation) {
        throw StateError('The send session has ended');
      }
      return write();
    });
    // A failed write must not poison later independent send/draft intents.
    _localWrites = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _queueMessage(
    String topicId,
    Object content, {
    Map<String, dynamic> head = const {},
    List<PendingUpload> uploads = const [],
    bool clearDraft = false,
  }) {
    final scope = _activeScope;
    final senderId = currentUserId;
    final generation = _generation;
    // Capture before the FIFO tail: callers may edit/reuse their maps meanwhile.
    final capturedContent = jsonDecode(jsonEncode(content)) as Object;
    final capturedHead = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(head)) as Map,
    );
    final capturedUploads = <PendingUpload>[];
    for (final upload in uploads) {
      if (upload.bytes.isEmpty || upload.bytes.length > 10 * 1024 * 1024) {
        throw ArgumentError('Attachments must contain 1 byte to 10 MiB');
      }
      final entities = content is Map ? content['ent'] : null;
      if (entities is! List ||
          upload.entityIndex < 0 ||
          upload.entityIndex >= entities.length) {
        throw ArgumentError('Attachment entity index is invalid');
      }
      capturedUploads.add(
        PendingUpload(
          entityIndex: upload.entityIndex,
          bytes: Uint8List.fromList(upload.bytes),
          name: upload.name,
          mime: upload.mime,
        ),
      );
    }
    return _writeLocal(scope, generation, () async {
      var topic = await database.topicRow(scope, topicId);
      if (topic == null) {
        await database.mergeTopic(scope, topicId, const {});
        topic = await database.topicRow(scope, topicId);
      }
      if (_generation != generation || _scope != scope) {
        throw StateError('The send session has ended');
      }
      final localSeq = max(
        DateTime.now().microsecondsSinceEpoch,
        _lastLocalSeq + 1,
      );
      _lastLocalSeq = localSeq;
      final id = const Uuid().v4();
      final message = ChatMessage(
        id: id,
        topicId: topicId,
        seq: -localSeq,
        localSeq: localSeq,
        senderId: senderId,
        createdAt: DateTime.now().toUtc(),
        content: capturedContent,
        head: {
          ...capturedHead,
          'mime': 'text/x-drafty',
          'localSeq': localSeq,
          'x-client-id': id,
        },
        delivery: Delivery.queued,
      );
      await database.enqueue(
        scope,
        message,
        capturedUploads,
        clearDraft: clearDraft ? topic?.draft : null,
      );
      if (_generation != generation || _scope != scope) return;
      _changes.add(
        ChatChange(topicId, message: message, origin: ChatChangeOrigin.arrival),
      );
      if (_networkReady) unawaited(flushOutbox());
    });
  }

  Future<void> _retryMessage(String clientId) async {
    await database.outboxAttempt(
      _activeScope,
      clientId,
      delivery: Delivery.queued,
      nextRetryAt: 0,
    );
    await flushOutbox();
  }

  Future<void> _flushPendingMessages() {
    if (!_networkReady || _scope == null) return Future.value();
    _flushAgain = true;
    if (_flushing != null) return _flushing!;
    final generation = _generation;
    final scope = _scope;
    bool active() =>
        _generation == generation && _scope == scope && _networkReady;
    Future<void> drain() async {
      do {
        _flushAgain = false;
        await _flushOutbox();
      } while (active() && _flushAgain);
    }

    late final Future<void> task;
    task = drain().whenComplete(() {
      if (!identical(_flushing, task)) return;
      _flushing = null;
      if (active() && _flushAgain) unawaited(flushOutbox());
    });
    _flushing = task;
    return task;
  }
}
