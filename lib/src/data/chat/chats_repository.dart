import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:collapse_tinode/collapse_tinode.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/message_seq_cache.dart';
import '../../domain/chat/chat_models.dart';
import '../../domain/chat/history_models.dart';
import '../../domain/chat/search_models.dart';

export '../../domain/chat/search_models.dart';
export '../../domain/chat/history_models.dart';

part 'session_lifecycle.dart';
part 'topic_sync.dart';
part 'history_loading.dart';
part 'window_loading.dart';
part 'message_queue.dart';
part 'outbox_delivery.dart';
part 'message_actions.dart';
part 'realtime_events.dart';
part 'message_search.dart';
part 'search_navigation.dart';
part 'history_navigation.dart';
part 'history_snapshot.dart';
part 'history_spans.dart';

/// Account-scoped SQLite is authoritative. Transport never owns UI state.
class ChatsRepository {
  ChatsRepository({
    required this.database,
    required this.gateway,
    required this.serverId,
  });

  final AppDatabase database;
  final TinodeGateway gateway;
  final String serverId;
  final _changes = StreamController<ChatChange>.broadcast();
  final Map<String, Future<void>> _attaching = {};
  final Map<String, Future<void>> _topicSyncs = {};
  final Set<String> _attached = {};
  final Map<String, int> _historyRequests = {};
  final _sequenceCache = MessageSeqCache();
  final _storingMessages = <(String, int, String, int), Future<ChatMessage?>>{};
  final Set<String> _searchPrepared = {};
  StreamSubscription<TinodeEvent>? _subscription;
  Future<void> _eventTail = Future.value();
  Future<void>? _refreshing;
  Future<void>? _flushing;
  Future<void> _localWrites = Future.value();
  Future<void> _retiredWorkers = Future.value();
  bool _flushAgain = false;
  Timer? _retryTimer;
  String? _scope;
  String? _userId;
  int _generation = 0;
  int _lastLocalSeq = 0;

  String get currentUserId => _userId ?? '';
  int get sessionGeneration => _generation;
  String get _activeScope => _scope ?? (throw StateError('No active account'));
  bool get _networkReady => gateway.connected && gateway.userId == _userId;
  Stream<ChatChange> changesFor(String topicId) =>
      _changes.stream.where((e) => e.topicId == topicId);

  Future<void> start(String userId) => _startSession(userId);

  Future<void> stop() => _stopSession();

  Future<void> dispose() => _disposeSession();

  Future<void> clear() => database.clearScope(_activeScope);

  Stream<List<ChatTopic>> watchTopics() =>
      database.watchTopics(_activeScope, userId: currentUserId);

  Stream<ChatTopic?> watchTopic(String id) =>
      database.watchTopic(_activeScope, id, userId: currentUserId);

  Future<ChatTopic?> getTopic(String id) async {
    final scope = _activeScope;
    final generation = _generation;
    final result = await database.topic(scope, id, currentUserId);
    return _scope == scope && _generation == generation ? result : null;
  }

  /// Newer incoming sequences, without treating own ACKs as arrivals or reads.
  Future<int> countIncomingAfter(String topicId, int afterSeq) async {
    final scope = _activeScope;
    final generation = _generation;
    final result = await database.countIncomingAfter(
      scope,
      topicId,
      currentUserId,
      afterSeq,
    );
    return _scope == scope && _generation == generation ? result : 0;
  }

  Future<ChatMessage?> getMessage(String topicId, int seq) async {
    final row = await database.messageRow(_activeScope, topicId, seq);
    return row == null ? null : database.toMessage(row);
  }

  Future<void> ensureTopic(String topicId) => _ensureTopic(topicId);

  /// Gallery metadata requires membership, but never opens a chat window/tail.
  Future<void> prepareMediaTopic(String topicId) async {
    final scope = _activeScope, generation = _generation;
    if (!_networkReady) return;
    await _attach(topicId);
    if (!_historyActive(scope, generation)) return;
    if (await database.topicRow(scope, topicId) == null) {
      await database.mergeTopic(scope, topicId, const {});
    }
    if (_historyActive(scope, generation)) await _syncDeletions(scope, topicId);
  }

  /// An inline attachment may need its one original message, never a chat page.
  Future<ChatMessage?> mediaMessage(
    String topicId,
    int seq, {
    String? id,
  }) async {
    final scope = _activeScope, generation = _generation;
    final row = id == null
        ? await database.messageRow(scope, topicId, seq)
        : await database.messageById(scope, id);
    if (!_historyActive(scope, generation)) return null;
    if (row != null) return database.toMessage(row);
    if (seq <= 0 || !_networkReady) return null;
    await _attach(topicId);
    if (!_historyActive(scope, generation)) return null;
    await _fetch(scope, topicId, since: seq, before: seq + 1, limit: 1);
    return _historyActive(scope, generation) ? getMessage(topicId, seq) : null;
  }

  Future<void> refreshTopics() => _refreshTopicList();

  Future<HistoryWindow?> openHistory(
    String topicId, {
    int? aroundSeq,
    String? aroundId,
    int limit = 40,
  }) => _openHistory(
    topicId,
    aroundSeq: aroundSeq,
    aroundId: aroundId,
    limit: limit,
  );

  /// Ready latest snapshot only; never starts another network reconciliation.
  Future<HistoryWindow?> cachedHistory(String topicId, {int limit = 40}) =>
      _openHistory(topicId, limit: limit, cacheOnly: true);

  Future<HistoryWindow?> extendHistory(
    String topicId,
    HistorySpan span, {
    required HistoryDirection direction,
    int limit = 40,
    int capacity = 120,
    String? anchorId,
  }) => _extendHistory(
    topicId,
    span,
    direction: direction,
    limit: limit,
    capacity: capacity,
    anchorId: anchorId,
  );

  Future<HistoryWindow?> inspectHistoryWindow(
    String topicId,
    HistorySpan span, {
    HistoryDirection retain = HistoryDirection.older,
    int capacity = 120,
    ChatMessage? include,
  }) => _inspectHistoryWindow(
    topicId,
    span,
    retain: retain,
    capacity: capacity,
    include: include,
  );

  Future<List<ChatMessage>> loadLatest(String topicId, {int limit = 40}) =>
      _loadLatest(topicId, limit: limit);

  Future<MessagePage> loadBeforeMessage(
    ChatMessage message, {
    int limit = 40,
  }) => _loadBeforeMessage(message, limit: limit);

  Future<MessagePage> loadAfterMessage(ChatMessage message, {int limit = 40}) =>
      _loadAfterMessage(message, limit: limit);

  Future<bool> hasCachedMessageAfter(ChatMessage message) =>
      _hasCachedMessageAfter(message);

  Future<MessagePage> loadBefore(
    String topicId,
    int beforeSeq, {
    int limit = 40,
  }) => _loadBefore(topicId, beforeSeq, limit: limit);

  Future<MessagePage> loadAfter(
    String topicId,
    int afterSeq, {
    int limit = 40,
  }) => _loadAfter(topicId, afterSeq, limit: limit);

  Future<List<ChatMessage>> loadAround(
    String topicId,
    int seq, {
    int limit = 40,
  }) => _loadAround(topicId, seq, limit: limit);

  Future<List<ChatMessage>> loadAroundId(
    String topicId,
    String clientId, {
    int limit = 40,
  }) => _loadAroundId(topicId, clientId, limit: limit);

  /// No network request. A first page prepares at most 40 legacy cached rows.
  /// Null means the account/session changed while the request was pending.
  Future<SearchPage?> searchMessages(
    String topicId,
    String query, {
    SearchCursor? before,
    int limit = 40,
  }) => _searchMessages(topicId, query, before: before, limit: limit);

  /// One missing <=40-sequence interval, never a crawl or a read receipt.
  Future<bool?> loadMoreSearchHistory(String topicId) =>
      _loadMoreSearchHistory(topicId);

  Future<List<ChatMessage>> reloadWindow(
    String topicId,
    List<ChatMessage> window,
  ) => _reloadWindow(topicId, window);

  Future<void> send(
    String topicId,
    Object content, {
    Map<String, dynamic> head = const {},
    List<PendingUpload> uploads = const [],
    bool clearDraft = false,
  }) => Future<void>.sync(
    () => _queueMessage(
      topicId,
      content,
      head: head,
      uploads: uploads,
      clearDraft: clearDraft,
    ),
  );

  Future<void> retry(String clientId) => _retryMessage(clientId);

  Future<void> flushOutbox() => _flushPendingMessages();

  /// A single local preview, never an upload or a read of another account.
  Future<Uint8List?> pendingAttachmentBytes(
    ChatMessage message,
    int entityIndex,
  ) async {
    final scope = _scope;
    final generation = _generation;
    if (scope == null ||
        message.senderId != _userId ||
        !message.pending ||
        message.hidden ||
        entityIndex < 0) {
      return null;
    }
    final bytes = await database.pendingAttachmentBytes(
      scope,
      message,
      entityIndex,
    );
    return _scope == scope && _generation == generation ? bytes : null;
  }

  Future<void> markRead(String topicId, int seq) =>
      _markVisibleRead(topicId, seq);

  Future<void> updateDraft(String topicId, String text) {
    final scope = _activeScope;
    return _writeLocal(
      scope,
      _generation,
      () => database.setDraft(scope, topicId, text),
    );
  }

  /// A late send completion must not clear another route/session's draft.
  Future<void> clearDraftIfMatches(
    String topicId,
    String expected, {
    required String userId,
    required int sessionGeneration,
  }) {
    if (currentUserId != userId || _generation != sessionGeneration) {
      return Future.value();
    }
    return database.clearDraftIfMatches(_activeScope, topicId, expected);
  }

  Future<void> hideMessage(ChatMessage message) => _hideLocalMessage(message);

  Future<void> deleteMessage(ChatMessage message, {bool forEveryone = false}) =>
      _deleteMessage(message, forEveryone: forEveryone);

  static DateTime _timestamp(Object? value, [int? fallbackMs]) =>
      DateTime.tryParse(value?.toString() ?? '')?.toUtc() ??
      (fallbackMs == null
          ? DateTime.now().toUtc()
          : DateTime.fromMillisecondsSinceEpoch(fallbackMs, isUtc: true));
}
