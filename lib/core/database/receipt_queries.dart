part of 'app_database.dart';

extension _ReceiptQueries on AppDatabase {
  Future<void> _updateReceipts(
    String scope,
    String topicId,
    String userId, {
    int? read,
    int? recv,
    int? peerRead,
    int? peerRecv,
  }) => transaction(() async {
    await customUpdate(
      'UPDATE topics SET read_seq = MAX(read_seq, ?), recv_seq = MAX(recv_seq, ?), '
      'peer_read_seq = MAX(peer_read_seq, ?), peer_recv_seq = MAX(peer_recv_seq, ?) '
      'WHERE scope = ? AND id = ?',
      variables: [
        Variable(read ?? 0),
        Variable(max(recv ?? 0, read ?? 0)),
        Variable(peerRead ?? 0),
        Variable(max(peerRecv ?? 0, peerRead ?? 0)),
        Variable(scope),
        Variable(topicId),
      ],
      updates: {topics},
    );
    if (peerRead != null || peerRecv != null) {
      final topic = await topicRow(scope, topicId);
      if (topic == null) return;
      await customUpdate(
        'UPDATE messages SET delivery = CASE WHEN seq <= ? THEN ? '
        'WHEN seq <= ? AND delivery < ? THEN ? ELSE delivery END '
        'WHERE scope = ? AND topic_id = ? AND sender_id = ? AND seq > 0',
        variables: [
          Variable(topic.peerReadSeq),
          Variable(Delivery.read.index),
          Variable(topic.peerRecvSeq),
          Variable(Delivery.received.index),
          Variable(Delivery.received.index),
          Variable(scope),
          Variable(topicId),
          Variable(userId),
        ],
        updates: {messages},
      );
    }
  });
}
