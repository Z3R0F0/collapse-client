import 'dart:convert';
import 'dart:math';

import 'package:collapse_tinode/tinode.dart' show DraftyCodec;
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../src/domain/chat/chat_models.dart';
import '../../src/domain/chat/history_models.dart';
import '../../src/domain/chat/search_models.dart';
import '../../src/domain/chat/media_models.dart';

part 'app_database.g.dart';
part 'tables.dart';
part 'topic_queries.dart';
part 'topic_counts.dart';
part 'message_queries.dart';
part 'message_merge.dart';
part 'topic_summary.dart';
part 'outbox_queries.dart';
part 'pending_attachment_queries.dart';
part 'receipt_queries.dart';
part 'history_queries.dart';
part 'history_window_queries.dart';
part 'search_schema.dart';
part 'search_index.dart';
part 'search_projection.dart';
part 'search_queries.dart';
part 'media_queries.dart';
part 'media_index.dart';

@DriftDatabase(
  tables: [
    Topics,
    Messages,
    Outbox,
    OutboxAttachments,
    MessageSearch,
    MediaEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  final Map<(String, String), int> _searchCursors = {};
  final Map<(String, String), int?> _mediaCursors = {};
  final Set<(String, String)> _mediaPrepared = {};
  AppDatabase()
    : super(
        driftDatabase(
          name: 'collapse',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  // Existing message/outbox rows are untouched; derived text is prepared lazily.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createSearchIndex();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(messageSearch);
        await customStatement(
          'CREATE INDEX messages_client_id ON messages(scope, client_id)',
        );
        await _createSearchIndex();
      }
      if (from < 3) {
        await m.createTable(mediaEntries);
        await m.createIndex(mediaCategory);
      }
    },
  );

  Future<bool> prepareMedia(String scope, String topicId) =>
      _prepareMediaBatch(scope, topicId);

  Future<void> cacheMedia(String scope, List<MediaItem> items, {void Function()? check}) =>
      transaction(() async {
        check?.call();
        await _cacheMedia(scope, items);
        check?.call();
      });

  Future<List<MediaItem>> mediaPage(
    String scope,
    String topicId,
    MediaCategory category, {
    MediaCursor? before,
    MediaCursor? after,
    int limit = 24,
  }) => _mediaPage(
    scope,
    topicId,
    category,
    before: before,
    after: after,
    limit: limit,
  );

  Future<MediaItem?> mediaItem(
    String scope,
    String topicId,
    MediaCursor cursor,
  ) => _mediaItem(scope, topicId, cursor);

  Future<void> clearMedia(String scope, String topicId) => (delete(
    mediaEntries,
  )..where((m) => m.scope.equals(scope) & m.topicId.equals(topicId))).go();

  /// One text-only batch, at most 40 rows. True when all cached rows are ready.
  Future<bool> prepareSearch(String scope, String topicId) =>
      _prepareSearchBatch(scope, topicId);

  Future<List<SearchHit>> searchMessages(
    String scope,
    String topicId,
    String query, {
    SearchCursor? before,
    int limit = 40,
  }) => _searchMessages(scope, topicId, query, before: before, limit: limit);

  Future<TopicRow?> topicRow(String scope, String id) =>
      _findTopicRow(scope, id);

  Stream<List<ChatTopic>> watchTopics(String scope, {required String userId}) =>
      _watchTopicList(scope, userId);

  Stream<ChatTopic?> watchTopic(
    String scope,
    String id, {
    required String userId,
  }) => _watchSingleTopic(scope, id, userId);

  ChatTopic toTopic(TopicRow row, {required int unreadCount}) =>
      _mapTopicRow(row, unreadCount: unreadCount);

  Future<ChatTopic?> topic(String scope, String id, String userId) =>
      _selectTopicSummaries(scope, userId, id: id).getSingleOrNull();

  /// Sequence gaps remain conservatively incoming until their sender is known.
  Future<int> countIncomingAfter(
    String scope,
    String id,
    String userId,
    int afterSeq,
  ) => _countIncomingAfter(scope, id, userId, afterSeq);

  Future<void> mergeTopic(String scope, String id, Map<String, dynamic> data) =>
      _mergeTopicRow(scope, id, data);

  Future<MessageRow?> messageRow(String scope, String topicId, int seq) =>
      _findMessageRow(scope, topicId, seq);

  Future<MessageRow?> messageById(String scope, String clientId) =>
      _findMessageByClientId(scope, clientId);

  Future<List<MessageRow>> messagesByIds(String scope, Iterable<String> ids) =>
      _findMessagesByClientIds(scope, ids);

  Future<List<ChatMessage>> page(
    String scope,
    String topicId, {
    int? before,
    int? since,
    int limit = 40,
  }) => _loadMessagePage(
    scope,
    topicId,
    before: before,
    since: since,
    limit: limit,
  );

  Future<List<ChatMessage>> pendingMessages(
    String scope,
    String topicId, {
    int? before,
    int? since,
    int limit = 40,
  }) => _loadPendingMessages(
    scope,
    topicId,
    before: before,
    since: since,
    limit: limit,
  );

  ChatMessage toMessage(MessageRow row) => _mapMessageRow(row);

  Future<List<ChatMessage>> historyRows(
    String scope,
    String topicId,
    HistorySpan span, {
    HistoryDirection retain = HistoryDirection.older,
    int limit = 121,
  }) => _historyRows(scope, topicId, span, retain: retain, limit: limit);

  Future<List<ChatMessage>> localHistoryRows(
    String scope,
    String topicId, {
    required int serverEnd,
    int? before,
    int? since,
    int limit = 40,
  }) => _localHistoryRows(
    scope,
    topicId,
    serverEnd: serverEnd,
    before: before,
    since: since,
    limit: limit,
  );

  /// No rendered local suffix survives a new session. Discard only derived
  /// positive origin metadata, including legacy values copied from peer heads.
  Future<void> resetAcknowledgedOrigins(String scope) async {
    await customUpdate(
      'UPDATE messages SET local_seq=0 WHERE scope=? AND seq>0 AND local_seq<>0',
      variables: [Variable(scope)],
      updates: {messages},
    );
  }

  Future<int?> unretainedHistorySeq(
    String scope,
    String topicId,
    SequenceRange range,
    int localEnd,
  ) => _unretainedHistorySeq(scope, topicId, range, localEnd);

  Future<int?> firstLocalAck(
    String scope,
    String topicId,
    Iterable<String> ids,
  ) => _firstLocalAck(scope, topicId, ids);

  Future<void> enqueue(
    String scope,
    ChatMessage message,
    List<PendingUpload> uploads, {
    String? clearDraft,
  }) => _enqueueMessage(scope, message, uploads, clearDraft: clearDraft);

  /// ACKs and echoes share one atomic merge, preserving stable local identity.
  Future<ChatMessage> mergeMessage(
    String scope,
    ChatMessage message,
    String userId,
  ) => _mergeAcknowledgedMessage(scope, message, userId);

  Future<void> refreshSummary(String scope, String topicId) =>
      _refreshTopicSummary(scope, topicId);

  Future<void> receipts(
    String scope,
    String topicId,
    String userId, {
    int? read,
    int? recv,
    int? peerRead,
    int? peerRecv,
  }) => _updateReceipts(
    scope,
    topicId,
    userId,
    read: read,
    recv: recv,
    peerRead: peerRead,
    peerRecv: peerRecv,
  );

  Future<void> setPresence(String scope, String id, bool online) =>
      _setTopicPresence(scope, id, online);

  Future<void> markOffline(String scope) => _markTopicsOffline(scope);

  Future<void> setDraft(String scope, String id, String text) =>
      _setTopicDraft(scope, id, text);

  Future<void> clearDraftIfMatches(String scope, String id, String expected) =>
      _clearTopicDraftIfMatches(scope, id, expected);

  Future<void> cancelPending(String scope, ChatMessage message) =>
      _cancelPendingMessage(scope, message);

  Future<void> hide(String scope, String topicId, int seq) =>
      _hideMessageRow(scope, topicId, seq);

  Future<void> applyDeletions(
    String scope,
    String topicId,
    List<Map<String, dynamic>> ranges,
    int deletionId,
  ) => _applyMessageDeletions(scope, topicId, ranges, deletionId);

  Future<List<OutboxRow>> pendingOutbox(String scope) => _loadOutbox(scope);

  Future<List<OutboxAttachmentRow>> uploads(String scope, String clientId) =>
      _loadPendingUploads(scope, clientId);

  Future<Uint8List?> pendingAttachmentBytes(
    String scope,
    ChatMessage message,
    int entityIndex,
  ) => _readPendingAttachmentBytes(scope, message, entityIndex);

  Future<void> uploaded(
    String scope,
    String clientId,
    int index,
    String ref,
    Object content,
  ) => _storeUploadedAttachment(scope, clientId, index, ref, content);

  Future<void> outboxAttempt(
    String scope,
    String id, {
    required Delivery delivery,
    bool? ambiguous,
    int? attempts,
    int? nextRetryAt,
    String? error,
  }) => _recordOutboxAttempt(
    scope,
    id,
    delivery: delivery,
    ambiguous: ambiguous,
    attempts: attempts,
    nextRetryAt: nextRetryAt,
    error: error,
  );

  Future<void> clearScope(String scope) => transaction(() async {
    _searchCursors.removeWhere((key, _) => key.$1 == scope);
    _mediaCursors.removeWhere((key, _) => key.$1 == scope);
    _mediaPrepared.removeWhere((key) => key.$1 == scope);
    await (delete(mediaEntries)..where((t) => t.scope.equals(scope))).go();
    await (delete(outboxAttachments)..where((t) => t.scope.equals(scope))).go();
    await (delete(outbox)..where((t) => t.scope.equals(scope))).go();
    await (delete(messages)..where((t) => t.scope.equals(scope))).go();
    await (delete(topics)..where((t) => t.scope.equals(scope))).go();
  });

  Future<void> recordCoverage(
    String scope,
    String topicId,
    int start,
    int end,
  ) => _recordHistoryCoverage(scope, topicId, start, end);

  static int intValue(Object? value, [int fallback = 0]) => value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? fallback;

  static String preview(Object content) {
    if (content is! Map) return content.toString();
    final text = DraftyCodec.previewText(content).trim();
    if (text.isNotEmpty) return text;
    final entities = content['ent'];
    if (entities is List && entities.isNotEmpty) {
      final type = entities.whereType<Map>().firstOrNull?['tp'];
      // Portable glyphs, not English-only user-facing labels.
      return switch (type) {
        'IM' => '📷',
        'AU' => '🎙',
        'STICKER' => '🙂',
        _ => '📎',
      };
    }
    return '';
  }
}
