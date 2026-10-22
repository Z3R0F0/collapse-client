import 'dart:async';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:collapse/src/presentation/chat/chat_cubit.dart';
import 'package:collapse/src/presentation/chat/message_list.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_test/flutter_test.dart';

import 'fake_gateway.dart';

class TailGateway extends FakeGateway {
  final entered = Completer<void>(), release = Completer<void>();
  Completer<void>? descriptionRelease;
  bool failHistory = false;

  @override
  Future<Map<String, dynamic>> description(String topic) async {
    final result = await super.description(topic);
    await descriptionRelease?.future;
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> history(
    String topic, {
    int? since,
    int? before,
    int limit = 40,
  }) async {
    final rows = await super.history(
      topic,
      since: since,
      before: before,
      limit: limit,
    );
    if (!entered.isCompleted) entered.complete();
    await release.future;
    if (failHistory) throw StateError('History temporarily unavailable');
    return rows;
  }
}

class TailRepository extends ChatsRepository {
  TailRepository({required super.database, required super.gateway})
    : super(serverId: 'local');
  Completer<void>? cachedReadGate;
  final cachedReadEntered = Completer<void>();

  @override
  Future<HistoryWindow?> cachedHistory(String topicId, {int limit = 40}) async {
    final window = await super.cachedHistory(topicId, limit: limit);
    if (cachedReadGate != null) {
      cachedReadEntered.complete();
      await cachedReadGate!.future;
    }
    return window;
  }
}

class CachedTailFixture {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final gateway = TailGateway();
  late final repo = TailRepository(database: db, gateway: gateway);
  late final cubit = ChatCubit(repo);
  final controller = FlutterListViewController();
  final following = <bool>[];
  final states = <ChatState>[];
  StreamSubscription<ChatState>? _subscription;

  Future<void> prepare(
    int head, {
    int cached = 20,
    bool staleHead = false,
    bool open = true,
  }) async {
    await repo.start('me');
    gateway.seed(head);
    if (staleHead) gateway.descriptionRelease = Completer<void>();
    await db.mergeTopic('local|me', 'usrPeer', {
      'seq': staleHead ? cached : head,
    });
    await db.batch(
      (batch) => batch.insertAll(db.messages, [
        for (var seq = 1; seq <= cached; seq++)
          MessagesCompanion.insert(
            scope: 'local|me',
            topicId: 'usrPeer',
            seq: seq,
            clientId: 'usrPeer:$seq',
            senderId: 'peer',
            createdAtMs: seq,
            content: '"cached"',
          ),
      ]),
    );
    await db.recordCoverage('local|me', 'usrPeer', 1, cached + 1);
    gateway.ready = true;
    _subscription = cubit.stream.listen(states.add);
    if (open) await cubit.open('usrPeer');
  }

  Future<void> reconcile() async {
    gateway.descriptionRelease?.complete();
    await gateway.entered.future.timeout(const Duration(seconds: 2));
    final settled = repo
        .changesFor('usrPeer')
        .firstWhere(
          (event) =>
              event.historySync == HistorySyncPhase.completed ||
              event.historySync == HistorySyncPhase.failed,
        );
    gateway.release.complete();
    await settled.timeout(const Duration(seconds: 2));
    await pumpEventQueue(times: 100);
  }

  Widget build() => MaterialApp(
    home: Scaffold(
      body: StreamBuilder<ChatState>(
        stream: cubit.stream,
        initialData: cubit.state,
        builder: (context, snapshot) {
          final state = snapshot.requireData;
          return MessageList(
            controller: controller,
            messages: [
              for (final message in state.messages)
                chat.Message.custom(id: message.id, authorId: message.senderId),
            ],
            navigationEpoch: state.navigationEpoch,
            targetId: state.targetId,
            navigating: state.loading,
            atLatest: state.atLiveEdge,
            canLoadOlder: state.hasOlder,
            canLoadNewer: state.hasNewer,
            olderPageKey: state.window?.span,
            newerPageKey: state.window?.span,
            onLoadOlder: cubit.loadOlder,
            onLoadNewer: cubit.loadNewer,
            onFollowingChanged: (value) {
              following.add(value);
              cubit.setFollowingLive(value);
            },
            onVisibleIds: cubit.setVisibleMessages,
            itemBuilder:
                (
                  context,
                  message,
                  index,
                  animation, {
                  messagesGroupingMode,
                  messageGroupingTimeoutInSeconds,
                  isRemoved,
                }) => SizedBox(
                  key: ValueKey('row-${message.id}'),
                  height: 80,
                  child: Text(message.id),
                ),
          );
        },
      ),
    ),
  );

  Future<void> dispose() async {
    if (gateway.descriptionRelease case final gate? when !gate.isCompleted) {
      gate.complete();
    }
    if (!gateway.release.isCompleted) gateway.release.complete();
    if (repo.cachedReadGate case final gate? when !gate.isCompleted) {
      gate.complete();
    }
    await _subscription?.cancel();
    await cubit.close();
    await repo.dispose();
    await gateway.dispose();
    await db.close();
    controller.dispose();
  }
}
