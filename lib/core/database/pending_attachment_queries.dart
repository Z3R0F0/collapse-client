part of 'app_database.dart';

extension _PendingAttachmentQueries on AppDatabase {
  Future<Uint8List?> _readPendingAttachmentBytes(
    String scope,
    ChatMessage message,
    int entityIndex,
  ) async {
    // Both rows are addressed by their complete primary keys. Check the blob
    // length in SQLite before loading it, rather than reading every attachment.
    final row = await customSelect(
      '''SELECT a.bytes FROM outbox_attachments a
         JOIN messages m ON m.scope = a.scope AND m.client_id = a.client_id
         WHERE a.scope = ? AND a.client_id = ? AND a.entity_index = ?
           AND m.topic_id = ? AND m.seq = ? AND m.sender_id = ?
           AND m.hidden = 0 AND m.deleted = 0 AND m.seq < 0
           AND length(a.bytes) BETWEEN 1 AND 10485760''',
      variables: [
        Variable(scope),
        Variable(message.id),
        Variable(entityIndex),
        Variable(message.topicId),
        Variable(message.seq),
        Variable(message.senderId),
      ],
      readsFrom: {outboxAttachments, messages},
    ).getSingleOrNull();
    return row?.read<Uint8List>('bytes');
  }
}
