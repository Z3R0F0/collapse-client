import 'dart:async';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:collapse_tinode/collapse_tinode.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/arrival_gateway.dart';

class _HeldStoreDatabase extends AppDatabase {
  _HeldStoreDatabase() : super.forTesting(NativeDatabase.memory());
  final entered = Completer<void>(), release = Completer<void>();
  bool hold = true, failNext = false;
  int merges = 0;

  @override
  Future<MessageRow?> messageRow(String scope, String topicId, int seq) async {
    final row = await super.messageRow(scope, topicId, seq);
    if (hold) {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    }
    return row;
  }

  @override
  Future<ChatMessage> mergeMessage(
    String scope,
    ChatMessage message,
    String userId,
  ) {
    merges++;
    if (failNext) {
      failNext = false;
      return Future.error(StateError('Fixture store failure'));
    }
    return super.mergeMessage(scope, message, userId);
  }
}

void main() {
  test('failed joined store is removed so history can retry', () async {
    final database = _HeldStoreDatabase()..failNext = true;
    final gateway = ArrivalGateway()
      ..seed(1)
      ..emitHistory = true;
    final repository = ChatsRepository(
      database: database,
      gateway: gateway,
      serverId: 'local',
    );
    await repository.start('me');
    gateway.ready = true;
    await repository.ensureTopic('usrPeer');
    try {
      final failed = expectLater(
        repository.loadBefore('usrPeer', 2, limit: 1),
        throwsStateError,
      );
      await database.entered.future;
      await pumpEventQueue();
      database.hold = false;
      database.release.complete();
      await failed;
      expect(database.merges, 1);
      expect(
        (await repository.loadBefore('usrPeer', 2, limit: 1)).messages,
        hasLength(1),
      );
      expect(database.merges, 2);
      expect(gateway.notes.where((note) => note.what == 'recv'), hasLength(1));
    } finally {
      if (!database.release.isCompleted) database.release.complete();
      await repository.dispose();
      await gateway.dispose();
      await database.close();
    }
  });

  for (final sameAccount in [false, true]) {
    test(
      'new ${sameAccount ? 'same-account session' : 'account'} never joins an old held store',
      () async {
        final database = _HeldStoreDatabase();
        final gateway = ArrivalGateway()..seed(1);
        final repository = ChatsRepository(
          database: database,
          gateway: gateway,
          serverId: 'local',
        );
        await repository.start('me');
        gateway.ready = true;
        await repository.ensureTopic('usrPeer');
        final old = repository.loadBefore('usrPeer', 2, limit: 1);
        await database.entered.future;
        try {
          gateway.ready = false;
          await repository.stop();
          gateway.userId = sameAccount ? 'me' : 'other';
          await repository.start(gateway.userId!);
          gateway.ready = true;
          database.hold = false;
          await repository.ensureTopic('usrPeer');
          final replacement = await repository
              .loadBefore('usrPeer', 2, limit: 1)
              .timeout(const Duration(seconds: 3));
          expect(replacement.messages, hasLength(1));
          expect(database.merges, 1);
          database.release.complete();
          expect((await old).messages, isEmpty);
          expect(database.merges, 1);
          expect(
            gateway.notes.where((note) => note.what == 'recv'),
            hasLength(1),
          );
        } finally {
          if (!database.release.isCompleted) database.release.complete();
          await old;
          await repository.dispose();
          await gateway.dispose();
          await database.close();
        }
      },
    );
  }

  for (final count in [1, 40]) {
    test(
      'global and fetched $count-message history stores each sequence once',
      () async {
        final database = _HeldStoreDatabase();
        final gateway = ArrivalGateway()
          ..seed(count)
          ..emitHistory = true;
        final repository = ChatsRepository(
          database: database,
          gateway: gateway,
          serverId: 'local',
        );
        final changes = <ChatChange>[];
        await repository.start('me');
        gateway.ready = true;
        await repository.ensureTopic('usrPeer');
        final subscription = repository
            .changesFor('usrPeer')
            .listen(changes.add);
        try {
          final loading = repository.loadBefore(
            'usrPeer',
            count + 1,
            limit: count,
          );
          await database.entered.future;
          await pumpEventQueue();
          database.hold = false;
          database.release.complete();
          expect((await loading).messages, hasLength(count));
          final drained = repository
              .changesFor('usrPeer')
              .firstWhere((change) => change.reset);
          gateway.controller.add(
            const TinodeEvent('info', {
              'topic': 'usrPeer',
              'from': 'peer',
              'what': 'recv',
              'seq': 0,
            }),
          );
          await drained.timeout(const Duration(seconds: 3));
          expect(database.merges, count);
          expect(
            changes.where((change) => change.message != null),
            hasLength(count),
          );
          expect(
            gateway.notes.where((note) => note.what == 'recv'),
            hasLength(count),
          );
          expect(
            changes.every(
              (change) => change.origin != ChatChangeOrigin.arrival,
            ),
            isTrue,
          );
        } finally {
          if (!database.release.isCompleted) database.release.complete();
          await subscription.cancel();
          await repository.dispose();
          await gateway.dispose();
          await database.close();
        }
      },
    );
  }
}
