import 'dart:convert';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:drift/drift.dart';

const searchScope = 'local|me';
const searchTopic = 'usrPeer';

ChatMessage searchMessage(int seq, Object content, {String? id}) => ChatMessage(
  id: id ?? 'search-$seq',
  topicId: searchTopic,
  seq: seq,
  localSeq: seq.abs(),
  senderId: seq < 0 || id != null ? 'me' : 'peer',
  createdAt: DateTime.utc(2026, 1, 1),
  content: content,
);

/// Unindexed schema-1-style content; production writes use transactional hooks.
Future<void> legacySearchMessage(
  AppDatabase db,
  int seq,
  Object content, {
  String scope = searchScope,
  String topic = searchTopic,
}) => db
    .into(db.messages)
    .insert(
      MessagesCompanion.insert(
        scope: scope,
        topicId: topic,
        seq: seq,
        clientId: '$topic:$seq',
        senderId: 'peer',
        createdAtMs: 1,
        content: jsonEncode(content),
      ),
    )
    .then((_) {});

class SearchSchemaV1 extends AppDatabase {
  SearchSchemaV1(super.executor) : super.forTesting();
  @override
  int get schemaVersion => 1;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createTable(topics);
      await m.createTable(messages);
      await m.createTable(outbox);
      await m.createTable(outboxAttachments);
    },
  );
}
