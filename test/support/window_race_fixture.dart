import 'dart:async';
import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:drift/native.dart';
import 'fake_gateway.dart';

class ReadGate<T> {
  final captured = Completer<T>();
  final release = Completer<void>();
  Future<T> pause(T value) async {
    captured.complete(value);
    await release.future;
    return value;
  }
}

class PausedWindowRepository extends ChatsRepository {
  PausedWindowRepository(AppDatabase db, FakeGateway gateway)
    : super(database: db, gateway: gateway, serverId: 'local');
  ReadGate<List<ChatMessage>>? latestGate;
  ReadGate<MessagePage>? beforeGate;
  ReadGate<MessagePage>? afterGate;
  ReadGate<List<ChatMessage>>? reloadGate;
  ReadGate<HistoryWindow?>? openGate;
  ReadGate<HistoryWindow?>? olderGate;
  ReadGate<HistoryWindow?>? newerGate;
  ReadGate<HistoryWindow?>? inspectGate;

  @override
  Future<HistoryWindow?> openHistory(
    String topicId, {
    int? aroundSeq,
    String? aroundId,
    int limit = 40,
  }) async {
    final gate = openGate;
    openGate = null;
    final window = await super.openHistory(
      topicId,
      aroundSeq: aroundSeq,
      aroundId: aroundId,
      limit: limit,
    );
    return gate == null ? window : gate.pause(window);
  }

  @override
  Future<HistoryWindow?> extendHistory(
    String topicId,
    HistorySpan span, {
    required HistoryDirection direction,
    int limit = 40,
    int capacity = 120,
    String? anchorId,
  }) async {
    final gate = direction == HistoryDirection.older ? olderGate : newerGate;
    if (direction == HistoryDirection.older) {
      olderGate = null;
    } else {
      newerGate = null;
    }
    final window = await super.extendHistory(
      topicId,
      span,
      direction: direction,
      limit: limit,
      capacity: capacity,
      anchorId: anchorId,
    );
    return gate == null ? window : gate.pause(window);
  }

  @override
  Future<HistoryWindow?> inspectHistoryWindow(
    String topicId,
    HistorySpan span, {
    HistoryDirection retain = HistoryDirection.older,
    int capacity = 120,
    ChatMessage? include,
  }) async {
    final gate = inspectGate;
    inspectGate = null;
    final window = await super.inspectHistoryWindow(
      topicId,
      span,
      retain: retain,
      capacity: capacity,
      include: include,
    );
    return gate == null ? window : gate.pause(window);
  }

  @override
  Future<List<ChatMessage>> loadLatest(String topicId, {int limit = 40}) async {
    final gate = latestGate;
    latestGate = null;
    final rows = await super.loadLatest(topicId, limit: limit);
    return gate == null ? rows : gate.pause(rows);
  }

  @override
  Future<MessagePage> loadBeforeMessage(
    ChatMessage message, {
    int limit = 40,
  }) async {
    final gate = beforeGate;
    beforeGate = null;
    final page = await super.loadBeforeMessage(message, limit: limit);
    return gate == null ? page : gate.pause(page);
  }

  @override
  Future<MessagePage> loadAfterMessage(
    ChatMessage message, {
    int limit = 40,
  }) async {
    final gate = afterGate;
    afterGate = null;
    final page = await super.loadAfterMessage(message, limit: limit);
    return gate == null ? page : gate.pause(page);
  }

  @override
  Future<List<ChatMessage>> reloadWindow(
    String topicId,
    List<ChatMessage> window,
  ) async {
    final gate = reloadGate;
    reloadGate = null;
    final rows = await super.reloadWindow(topicId, window);
    return gate == null ? rows : gate.pause(rows);
  }
}

class PausedPendingDatabase extends AppDatabase {
  PausedPendingDatabase() : super.forTesting(NativeDatabase.memory());
  ReadGate<List<ChatMessage>>? pendingGate;
  @override
  Future<List<ChatMessage>> pendingMessages(
    String scope,
    String topicId, {
    int? before,
    int? since,
    int limit = 40,
  }) async {
    final gate = pendingGate;
    pendingGate = null;
    final rows = await super.pendingMessages(
      scope,
      topicId,
      before: before,
      since: since,
      limit: limit,
    );
    return gate == null ? rows : gate.pause(rows);
  }
}
