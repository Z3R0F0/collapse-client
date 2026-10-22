part of 'app_database.dart';

extension _MessageMerge on AppDatabase {
  Future<ChatMessage> _mergeAcknowledgedMessage(
    String scope,
    ChatMessage message,
    String userId,
  ) => transaction(() async {
    final server = await messageRow(scope, message.topicId, message.seq);
    MessageRow? local;
    if (message.senderId == userId) {
      final candidate = await messageById(scope, message.id);
      if (candidate?.topicId == message.topicId &&
          candidate?.senderId == userId) {
        local = candidate;
      }
    }
    final old = local ?? server;
    final topic = await topicRow(scope, message.topicId);
    var delivery = max(
      message.delivery.index,
      old?.delivery == Delivery.failed.index
          ? Delivery.sent.index
          : old?.delivery ?? Delivery.sent.index,
    );
    if (message.senderId == userId && message.seq > 0) {
      if ((topic?.peerReadSeq ?? 0) >= message.seq) {
        delivery = Delivery.read.index;
      } else if ((topic?.peerRecvSeq ?? 0) >= message.seq) {
        delivery = max(delivery, Delivery.received.index);
      }
    }
    final id = old?.clientId ?? message.id;
    final deletedRanges = jsonDecode(topic?.deletedRanges ?? '[]') as List;
    final deletedByRange = deletedRanges.any(
      (range) => message.seq >= (range as List)[0] && message.seq < range[1],
    );
    await into(messages).insertOnConflictUpdate(
      MessagesCompanion.insert(
        scope: scope,
        topicId: message.topicId,
        seq: message.seq,
        clientId: id,
        // Wire localSeq is sender-owned. Only an existing local optimistic
        // identity proves membership in this client's retained outbox suffix.
        localSeq: Value(message.senderId == userId ? local?.localSeq ?? 0 : 0),
        senderId: message.senderId,
        createdAtMs: message.createdAt.millisecondsSinceEpoch,
        content: jsonEncode(message.content),
        head: Value(jsonEncode(message.head)),
        delivery: Value(delivery),
        hidden: Value(old?.hidden ?? message.hidden),
        deleted: Value((old?.deleted ?? false) || deletedByRange),
      ),
    );
    await _indexMessage(
      scope,
      message.topicId,
      message.seq,
      message.content,
      hidden:
          (old?.hidden ?? message.hidden) ||
          (old?.deleted ?? false) ||
          deletedByRange,
    );
    await _indexMedia(
      scope,
      toMessage((await messageRow(scope, message.topicId, message.seq))!),
    );
    if (old != null && old.seq != message.seq) {
      await (delete(messages)..where(
            (m) =>
                m.scope.equals(scope) &
                m.topicId.equals(message.topicId) &
                m.seq.equals(old.seq),
          ))
          .go();
    }
    if (message.seq > 0 && message.senderId == userId) {
      await (delete(
        outbox,
      )..where((o) => o.scope.equals(scope) & o.clientId.equals(id))).go();
      await (delete(
        outboxAttachments,
      )..where((o) => o.scope.equals(scope) & o.clientId.equals(id))).go();
    }
    await customUpdate(
      'UPDATE topics SET server_seq = MAX(server_seq, ?) WHERE scope = ? AND id = ?',
      variables: [
        Variable(max(0, message.seq)),
        Variable(scope),
        Variable(message.topicId),
      ],
      updates: {topics},
    );
    await refreshSummary(scope, message.topicId);
    if (message.seq > 0) {
      await _writeHistoryCoverage(
        scope,
        message.topicId,
        message.seq,
        message.seq + 1,
      );
    }
    return toMessage((await messageRow(scope, message.topicId, message.seq))!);
  });
}
