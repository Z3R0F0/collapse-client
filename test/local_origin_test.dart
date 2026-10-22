import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:collapse_tinode/collapse_tinode.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  late AppDatabase db;
  late FakeGateway gateway;
  late ChatsRepository repo;
  const scope = 'local|me', topic = 'usrPeer';
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = FakeGateway();
    repo = ChatsRepository(database: db, gateway: gateway, serverId: 'local');
    await repo.start('me');
  });
  tearDown(() async {
    await repo.dispose();
    await gateway.dispose();
    await db.close();
  });

  test(
    'peer or another device cannot forge this session local origin',
    () async {
      await repo.send(topic, 'local pending');
      final pending = (await db.pendingMessages(scope, topic)).single;
      final span = HistorySpan(
        server: const SequenceRange(1, 1),
        local: SequenceRange(pending.localSeq, pending.localSeq + 1),
        retainedLocalIds: {pending.id},
      );
      for (final sender in ['peer', 'me']) {
        final seq = sender == 'peer' ? 1 : 2;
        final change = repo
            .changesFor(topic)
            .firstWhere((e) => e.message?.seq == seq);
        gateway.controller.add(
          TinodeEvent('data', {
            'topic': topic,
            'seq': seq,
            'from': sender,
            'content': 'remote',
            'head': {
              'localSeq': pending.localSeq,
              'x-client-id': 'other-device-$seq',
            },
          }),
        );
        await change.timeout(const Duration(seconds: 3));
        final row = (await repo.getMessage(topic, seq))!;
        expect(row.localSeq, 0);
        expect(
          row.head['localSeq'],
          pending.localSeq,
          reason: 'wire head stays intact',
        );
      }
      final window = (await repo.inspectHistoryWindow(topic, span))!;
      expect(window.messages.map((m) => m.id), [pending.id]);
      expect(
        window.newer.canLoad,
        isTrue,
        reason: 'peer rows are not consumed ACKs',
      );
    },
  );

  test(
    'restart clears legacy positive origin metadata, not pending or wire head',
    () async {
      await repo.send(topic, 'queued');
      final pending = (await db.pendingMessages(scope, topic)).single;
      await db.mergeMessage(
        scope,
        ChatMessage(
          id: 'remote',
          topicId: topic,
          seq: 1,
          localSeq: 0,
          senderId: 'peer',
          createdAt: DateTime.utc(2026),
          content: 'remote',
          head: {'localSeq': pending.localSeq},
        ),
        'me',
      );
      await db.customStatement(
        'UPDATE messages SET local_seq=? WHERE scope=? AND seq=1',
        [pending.localSeq, scope],
      );
      await repo.stop();
      await repo.start('me');
      final remote = (await repo.getMessage(topic, 1))!;
      expect(remote.localSeq, 0);
      expect(remote.head['localSeq'], pending.localSeq);
      final restored = (await db.pendingMessages(scope, topic)).single;
      expect(restored.id, pending.id);
      expect(restored.localSeq, pending.localSeq);
      expect(await db.pendingOutbox(scope), hasLength(1));
    },
  );
}
