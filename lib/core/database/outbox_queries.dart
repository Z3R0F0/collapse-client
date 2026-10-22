part of 'app_database.dart';

extension _OutboxQueries on AppDatabase {
  Future<void> _enqueueMessage(
    String scope,
    ChatMessage message,
    List<PendingUpload> uploads, {
    String? clearDraft,
  }) => transaction(() async {
    await into(messages).insert(
      MessagesCompanion.insert(
        scope: scope,
        topicId: message.topicId,
        seq: message.seq,
        clientId: message.id,
        localSeq: Value(message.localSeq),
        senderId: message.senderId,
        createdAtMs: message.createdAt.millisecondsSinceEpoch,
        content: jsonEncode(message.content),
        head: Value(jsonEncode(message.head)),
        delivery: Value(Delivery.queued.index),
      ),
    );
    await _indexMessage(scope, message.topicId, message.seq, message.content);
    await _indexMedia(scope, message);
    await into(outbox).insert(
      OutboxCompanion.insert(
        scope: scope,
        clientId: message.id,
        topicId: message.topicId,
        localSeq: message.localSeq,
        afterSeq: Value(
          (await topicRow(scope, message.topicId))?.serverSeq ?? 0,
        ),
      ),
    );
    for (final upload in uploads) {
      await into(outboxAttachments).insert(
        OutboxAttachmentsCompanion.insert(
          scope: scope,
          clientId: message.id,
          entityIndex: upload.entityIndex,
          bytes: upload.bytes,
          name: upload.name,
          mime: upload.mime,
        ),
      );
    }
    await refreshSummary(scope, message.topicId);
    if (clearDraft != null) {
      await clearDraftIfMatches(scope, message.topicId, clearDraft);
    }
  });

  Future<void> _cancelPendingMessage(
    String scope,
    ChatMessage message,
  ) => transaction(() async {
    await (delete(outbox)..where(
          (row) => row.scope.equals(scope) & row.clientId.equals(message.id),
        ))
        .go();
    await (delete(outboxAttachments)..where(
          (row) => row.scope.equals(scope) & row.clientId.equals(message.id),
        ))
        .go();
    // Retain a hidden merge target if an already in-flight publish is accepted.
    final current = await messageById(scope, message.id);
    if (current != null) await hide(scope, current.topicId, current.seq);
  });

  Future<List<OutboxRow>> _loadOutbox(String scope) =>
      (select(outbox)
            ..where((o) => o.scope.equals(scope))
            ..orderBy([(o) => OrderingTerm.asc(o.localSeq)]))
          .get();

  Future<List<OutboxAttachmentRow>> _loadPendingUploads(
    String scope,
    String clientId,
  ) => (select(
    outboxAttachments,
  )..where((o) => o.scope.equals(scope) & o.clientId.equals(clientId))).get();

  Future<void> _storeUploadedAttachment(
    String scope,
    String clientId,
    int index,
    String ref,
    Object content,
  ) => transaction(() async {
    await (update(outboxAttachments)..where(
          (o) =>
              o.scope.equals(scope) &
              o.clientId.equals(clientId) &
              o.entityIndex.equals(index),
        ))
        .write(OutboxAttachmentsCompanion(remoteRef: Value(ref)));
    await (update(messages)
          ..where((m) => m.scope.equals(scope) & m.clientId.equals(clientId)))
        .write(MessagesCompanion(content: Value(jsonEncode(content))));
    final row = await messageById(scope, clientId);
    if (row != null) {
      await _indexMedia(scope, toMessage(row));
      await _indexMessage(
        scope,
        row.topicId,
        row.seq,
        content,
        hidden: row.hidden || row.deleted,
      );
    }
  });

  Future<void> _recordOutboxAttempt(
    String scope,
    String id, {
    required Delivery delivery,
    bool? ambiguous,
    int? attempts,
    int? nextRetryAt,
    String? error,
  }) => transaction(() async {
    await (update(messages)..where(
          (m) =>
              m.scope.equals(scope) &
              m.clientId.equals(id) &
              m.seq.isSmallerThanValue(0),
        ))
        .write(MessagesCompanion(delivery: Value(delivery.index)));
    await (update(
      outbox,
    )..where((o) => o.scope.equals(scope) & o.clientId.equals(id))).write(
      OutboxCompanion(
        ambiguous: ambiguous == null ? const Value.absent() : Value(ambiguous),
        attempts: attempts == null ? const Value.absent() : Value(attempts),
        nextRetryAt: nextRetryAt == null
            ? const Value.absent()
            : Value(nextRetryAt),
        error: Value(error),
      ),
    );
  });
}
