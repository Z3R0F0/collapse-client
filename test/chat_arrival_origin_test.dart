import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:collapse_tinode/collapse_tinode.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/arrival_gateway.dart';
import 'support/window_race_fixture.dart';

void main() {
  late AppDatabase database;
  late ArrivalGateway gateway;
  late ChatsRepository repository;
  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = ArrivalGateway();
    repository = ChatsRepository(
      database: database,
      gateway: gateway,
      serverId: 'local',
    );
    await repository.start('me');
  });
  tearDown(() async {
    await repository.dispose();
    await gateway.dispose();
    await database.close();
  });

  Future<ChatChange> receive(Map<String, dynamic> packet) {
    final changed = repository
        .changesFor(packet['topic'] as String)
        .firstWhere((change) => change.message?.seq == packet['seq']);
    gateway.controller.add(TinodeEvent('data', packet));
    return changed.timeout(const Duration(seconds: 3));
  }

  test(
    'local enqueue is arrival; ACK, echo and stored replay are updates',
    () async {
      final queued = repository.changesFor('usrPeer').first;
      await repository.send('usrPeer', 'local');
      expect((await queued).origin, ChatChangeOrigin.arrival);
      final ack = repository
          .changesFor('usrPeer')
          .firstWhere((change) => change.message?.seq == 1);
      gateway.ready = true;
      await repository.flushOutbox();
      expect((await ack).origin, ChatChangeOrigin.update);
      expect(
        (await receive(gateway.rows.single)).origin,
        ChatChangeOrigin.update,
      );
      gateway.ready = false;
      await repository.stop();
      await repository.start('me');
      expect(
        (await receive(gateway.rows.single)).origin,
        ChatChangeOrigin.update,
      );
      expect(
        (await receive(arrivalPacket(2))).origin,
        ChatChangeOrigin.arrival,
      );
    },
  );

  test('history delivered globally is not a live arrival', () async {
    gateway.seed(2);
    gateway.ready = true;
    gateway.emitHistory = true;
    await repository.ensureTopic('usrPeer');
    final changes = <ChatChange>[];
    final subscription = repository.changesFor('usrPeer').listen(changes.add);
    addTearDown(subscription.cancel);
    await repository.loadBefore('usrPeer', 3, limit: 2);
    final barrier = repository.changesFor('usrPeer').firstWhere((c) => c.reset);
    gateway.controller.add(
      const TinodeEvent('info', {
        'topic': 'usrPeer',
        'from': 'peer',
        'what': 'recv',
        'seq': 2,
      }),
    );
    await barrier.timeout(const Duration(seconds: 3));
    expect(changes.where((c) => c.message != null), isNotEmpty);
    expect(changes.every((c) => c.origin != ChatChangeOrigin.arrival), isTrue);
  });

  test('own echo reconciles a queued row without another arrival', () async {
    await repository.send('usrPeer', 'queued');
    final pending = (await repository.loadLatest('usrPeer')).single;
    final echoed = await receive({
      ...arrivalPacket(1),
      'from': 'me',
      'content': pending.content,
      'head': pending.head,
    });
    expect(echoed.message?.id, pending.id);
    expect(echoed.origin, ChatChangeOrigin.update);
  });

  test('failed history releases provenance suppression', () async {
    gateway.seed(1);
    gateway.ready = true;
    await repository.ensureTopic('usrPeer');
    final history = ReadGate<List<Map<String, dynamic>>>();
    gateway.historyGates.add(history);
    final failed = expectLater(
      repository.loadBefore('usrPeer', 2, limit: 1),
      throwsA(isA<TinodeException>()),
    );
    await history.captured.future;
    history.release.completeError(const TinodeException(0, 'disconnected'));
    await failed;
    expect((await receive(arrivalPacket(1))).origin, ChatChangeOrigin.arrival);
  });

  test(
    'history provenance is captured before a blocked realtime tail',
    () async {
      gateway.seed(1);
      gateway.ready = true;
      await repository.ensureTopic('usrPeer');
      final tail = gateway.deletionGate = ReadGate<Map<String, dynamic>>();
      gateway.controller.add(
        const TinodeEvent('pres', {'topic': 'usrPeer', 'what': 'del'}),
      );
      await tail.captured.future;
      final history = ReadGate<List<Map<String, dynamic>>>();
      gateway.historyGates.add(history);
      final fetched = repository.loadBefore('usrPeer', 2, limit: 1);
      await history.captured.future;
      final queued = receive(arrivalPacket(2));
      await Future<void>.delayed(Duration.zero);
      history.release.complete();
      await fetched;
      tail.release.complete();
      expect((await queued).origin, ChatChangeOrigin.history);
      expect(
        (await receive(arrivalPacket(3))).origin,
        ChatChangeOrigin.arrival,
      );
    },
  );

  for (final restart in [false, true]) {
    test(
      '${restart ? 'old generation' : 'overlapping request'} cannot clear active history',
      () async {
        gateway.seed(1);
        gateway.ready = true;
        await repository.ensureTopic('usrPeer');
        final first = ReadGate<List<Map<String, dynamic>>>();
        gateway.historyGates.add(first);
        final firstFetch = repository.loadBefore('usrPeer', 2, limit: 1);
        await first.captured.future;
        if (restart) {
          gateway.ready = false;
          await repository.stop();
          await repository.start('me');
          gateway.ready = true;
        }
        final second = ReadGate<List<Map<String, dynamic>>>();
        gateway.historyGates.add(second);
        final secondFetch = repository.loadBefore('usrPeer', 2, limit: 1);
        await second.captured.future;
        first.release.complete();
        await firstFetch;
        expect(
          (await receive(arrivalPacket(2))).origin,
          ChatChangeOrigin.history,
        );
        expect(
          (await receive(arrivalPacket(1, topic: 'usrOther'))).origin,
          ChatChangeOrigin.arrival,
        );
        second.release.complete();
        await secondFetch;
        expect(
          (await receive(arrivalPacket(3))).origin,
          ChatChangeOrigin.arrival,
        );
      },
    );
  }
}
