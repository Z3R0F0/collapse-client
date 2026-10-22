import 'dart:async';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class _Gate {
  final entered = Completer<void>(), release = Completer<void>();
  Future<void> wait() async {
    if (!entered.isCompleted) entered.complete();
    await release.future;
  }

  void finish() {
    if (!release.isCompleted) release.complete();
  }
}

class _HeldGateway extends FakeGateway {
  _Gate? descriptionGate, historyGate, meGate;
  int descriptionsRead = 0;
  @override
  Future<Map<String, dynamic>> description(String topic) async {
    descriptionsRead++;
    final result = await super.description(topic);
    await descriptionGate?.wait();
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> subscriptions({
    String topic = 'me',
  }) async {
    if (topic == 'me') await meGate?.wait();
    return super.subscriptions(topic: topic);
  }

  @override
  Future<List<Map<String, dynamic>>> history(
    String topic, {
    int? since,
    int? before,
    int limit = 40,
  }) async {
    final result = await super.history(
      topic,
      since: since,
      before: before,
      limit: limit,
    );
    await historyGate?.wait();
    return result;
  }

  void releaseAll() {
    descriptionGate?.finish();
    historyGate?.finish();
    meGate?.finish();
  }
}

void main() {
  late AppDatabase db;
  late _HeldGateway gateway;
  late ChatsRepository repo;
  var disposed = false;
  setUp(() async {
    disposed = false;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = _HeldGateway();
    repo = ChatsRepository(database: db, gateway: gateway, serverId: 'local');
    await repo.start('me');
  });
  tearDown(() async {
    gateway.releaseAll();
    if (!disposed) await repo.dispose();
    await gateway.dispose();
    await db.close();
  });

  Future<void> cache(int count, {int? head}) async {
    gateway.seed(head ?? count);
    await db.mergeTopic('local|me', 'usrPeer', {
      'seq': head ?? count,
      'public': {'fn': 'Cached'},
    });
    await db.batch(
      (batch) => batch.insertAll(db.messages, [
        for (var seq = 1; seq <= count; seq++)
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
    await db.recordCoverage('local|me', 'usrPeer', 1, count + 1);
  }

  test(
    'cached latest and durable pending return before metadata; sync joins',
    () async {
      await cache(60);
      await repo.send('usrPeer', 'durable offline');
      final pendingId = (await db.pendingOutbox('local|me')).single.clientId;
      final gate = gateway.descriptionGate = _Gate();
      gateway.ready = true;
      final opening = repo.openHistory('usrPeer');
      await gate.entered.future.timeout(const Duration(seconds: 2));
      final first = await opening.timeout(const Duration(seconds: 1));
      expect(first!.messages.last.id, pendingId);
      expect(first.messages, hasLength(40));
      final second = await repo
          .openHistory('usrPeer')
          .timeout(const Duration(seconds: 1));
      expect(second!.span, first.span);
      final refresh = repo.refreshTopics();
      await pumpEventQueue();
      expect(gateway.descriptionsRead, 1);
      gate.finish();
      await refresh;
      expect(
        gateway.requests,
        isEmpty,
        reason: 'covered tail is already cached',
      );
      expect((await db.topicRow('local|me', 'usrPeer'))!.readSeq, 0);
      expect((await db.pendingOutbox('local|me')).single.clientId, pendingId);
    },
  );

  test(
    'cached target does not await metadata or fill its page over network',
    () async {
      await cache(30);
      final gate = gateway.descriptionGate = _Gate();
      gateway.ready = true;
      final opening = repo.openHistory('usrPeer', aroundSeq: 20);
      await gate.entered.future.timeout(const Duration(seconds: 2));
      final window = await opening.timeout(const Duration(seconds: 1));
      expect(window!.messages.any((message) => message.seq == 20), isTrue);
      expect(window.messages, hasLength(30));
      expect(gateway.requests, isEmpty);
    },
  );

  test(
    'cached island returns during held gap fetch and never claims live end',
    () async {
      await cache(20, head: 200);
      final gate = gateway.historyGate = _Gate();
      gateway.ready = true;
      final opening = repo.openHistory('usrPeer');
      await gate.entered.future.timeout(const Duration(seconds: 2));
      final window = await opening.timeout(const Duration(seconds: 1));
      expect(
        window!.messages.map((m) => m.seq),
        List.generate(20, (i) => i + 1),
      );
      expect(window.newer.isExhausted, isFalse);
      expect(window.newer.gap, isNotNull);
      expect(gateway.requests.single.limit, lessThanOrEqualTo(40));
      final reconciled = repo.changesFor('usrPeer').firstWhere((e) => e.reset);
      gate.finish();
      await reconciled.timeout(const Duration(seconds: 3));
      final latest = await repo.openHistory('usrPeer');
      expect(latest!.messages.last.seq, 200);
      expect(latest.messages.first.seq, 161);
      expect(latest.older.isExhausted, isFalse);
    },
  );

  test(
    'missing target still waits for one bounded authoritative fetch',
    () async {
      await cache(20, head: 200);
      final gate = gateway.historyGate = _Gate();
      gateway.ready = true;
      var completed = false;
      final opening = repo.openHistory('usrPeer', aroundSeq: 100).then((value) {
        completed = true;
        return value;
      });
      await gate.entered.future.timeout(const Duration(seconds: 2));
      await pumpEventQueue();
      expect(completed, isFalse);
      gate.finish();
      final window = await opening;
      expect(window!.messages.any((m) => m.seq == 100), isTrue);
      expect(gateway.requests, hasLength(1));
      expect(gateway.requests.single.limit, lessThanOrEqualTo(40));
    },
  );

  test(
    'start returns local account before me sync, explicit refresh still awaits it',
    () async {
      await cache(60);
      await repo.stop();
      final gate = gateway.meGate = _Gate();
      gateway.ready = true;
      final starting = repo.start('me');
      await gate.entered.future.timeout(const Duration(seconds: 2));
      await starting.timeout(const Duration(seconds: 1));
      expect((await repo.watchTopics().first).single.title, 'Cached');
      var refreshed = false;
      final refresh = repo.refreshTopics().then((_) => refreshed = true);
      await pumpEventQueue();
      expect(refreshed, isFalse);
      gate.finish();
      await refresh;
      expect(refreshed, isTrue);
    },
  );

  for (final sameAccount in [true, false]) {
    test(
      'retired background metadata cannot change ${sameAccount ? 'relogged' : 'replacement'} account; dispose drains it',
      () async {
        await cache(60);
        gateway.descriptions['usrPeer'] = {
          'seq': 999,
          'public': {'fn': 'Stale'},
        };
        final gate = gateway.descriptionGate = _Gate();
        gateway.ready = true;
        final opening = repo.openHistory('usrPeer');
        await gate.entered.future.timeout(const Duration(seconds: 2));
        await opening.timeout(const Duration(seconds: 1));
        gateway.ready = false;
        await repo.stop().timeout(const Duration(seconds: 1));
        final user = sameAccount ? 'me' : 'other';
        gateway.userId = user;
        await repo.start(user);
        await db.mergeTopic('local|$user', 'usrPeer', {
          'public': {'fn': 'Current'},
        });
        final closing = repo.dispose().then((_) => disposed = true);
        await pumpEventQueue();
        expect(disposed, isFalse);
        gate.finish();
        await closing.timeout(const Duration(seconds: 3));
        expect((await db.topicRow('local|$user', 'usrPeer'))!.title, 'Current');
        expect((await db.topicRow('local|me', 'usrPeer'))!.serverSeq, 60);
        expect(gateway.requests, isEmpty);
        expect(gateway.notes, isEmpty);
      },
    );
  }
}
