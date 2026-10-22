import 'dart:async';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class _SnapshotDatabase extends AppDatabase {
  _SnapshotDatabase() : super.forTesting(NativeDatabase.memory());
  Future<void> Function()? afterRows;

  @override
  Future<List<ChatMessage>> historyRows(
    String scope,
    String topicId,
    HistorySpan span, {
    HistoryDirection retain = HistoryDirection.older,
    int limit = 121,
  }) async {
    final result = await super.historyRows(
      scope,
      topicId,
      span,
      retain: retain,
      limit: limit,
    );
    final hook = afterRows;
    afterRows = null;
    await hook?.call();
    return result;
  }
}

void main() {
  late AppDatabase database;
  late FakeGateway gateway;
  late ChatsRepository repository;
  const scope = 'local|me', topic = 'usrPeer';

  setUp(() async {
    database = _SnapshotDatabase();
    gateway = FakeGateway();
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

  Future<void> cache(int first, int last, {int? serverSeq}) async {
    await database.mergeTopic(scope, topic, {'seq': serverSeq ?? last});
    for (var seq = first; seq <= last; seq++) {
      await database.mergeMessage(
        scope,
        ChatMessage(
          id: '$topic:$seq',
          topicId: topic,
          seq: seq,
          localSeq: 0,
          senderId: 'peer',
          createdAt: DateTime.utc(2026).add(Duration(seconds: seq)),
          content: 'message $seq',
        ),
        'me',
      );
    }
    await database.recordCoverage(scope, topic, first, last + 1);
  }

  test('offline forward page cannot jump across a cache hole', () async {
    await cache(1, 40, serverSeq: 240);
    await cache(201, 240);
    final page = await repository.loadAfter(topic, 40);
    expect(page.messages, isEmpty);
    expect(
      page.hasMore,
      isFalse,
      reason: 'offline gap is blocked, not loadable',
    );
  });

  test(
    'offline empty page cannot advertise endlessly repeatable work',
    () async {
      await cache(1, 40, serverSeq: 240);
      final page = await repository.loadAfter(topic, 40);
      expect(page.messages, isEmpty);
      expect(page.hasMore, isFalse);
    },
  );

  test('covered older page is cache-first and never re-fetches', () async {
    await cache(1, 80);
    gateway.seed(80);
    gateway.ready = true;
    final first = await repository.loadBefore(topic, 81);
    final again = await repository.loadBefore(topic, 81);
    expect(first.messages.map((m) => m.seq), List.generate(40, (i) => i + 41));
    expect(again.messages, first.messages);
    expect(gateway.requests, isEmpty);
  });

  test(
    'known deleted prefix is a proved end without any API request',
    () async {
      await cache(200, 205);
      await database.applyDeletions(scope, topic, [
        {'low': 1, 'hi': 200},
      ], 1);
      gateway.rows.addAll([
        for (var seq = 200; seq <= 205; seq++)
          {
            'topic': topic,
            'seq': seq,
            'from': 'peer',
            'content': 'message $seq',
          },
      ]);
      gateway.ready = true;
      final page = await repository.loadBefore(topic, 200);
      expect(page.messages, isEmpty);
      expect(page.hasMore, isFalse);
      expect(gateway.requests, isEmpty);
    },
  );

  test('one action cannot crawl an unbounded empty history', () async {
    await database.mergeTopic(scope, topic, {'seq': 1000});
    gateway.ready = true;
    await repository.loadBefore(topic, 1001);
    expect(gateway.requests.length, lessThanOrEqualTo(1));
    expect(gateway.requests.single.limit, lessThanOrEqualTo(40));
  });

  test(
    'typed latest exposes an offline gap instead of joining islands',
    () async {
      await cache(1, 10, serverSeq: 240);
      await cache(231, 240);
      final window = (await repository.openHistory(topic))!;
      expect(
        window.messages.map((m) => m.seq),
        List.generate(10, (i) => i + 231),
      );
      expect(window.span.server, const SequenceRange(231, 241));
      expect(window.older.isBlocked, isTrue);
      final again = (await repository.extendHistory(
        topic,
        window.span,
        direction: HistoryDirection.older,
      ))!;
      expect(again.span, window.span);
      expect(again.messages, window.messages);
      expect(gateway.requests, isEmpty);
    },
  );

  test('inspect picks only the requested connected component', () async {
    await cache(1, 10, serverSeq: 240);
    await cache(231, 240);
    const span = HistorySpan(server: SequenceRange(1, 241));
    final first = (await repository.inspectHistoryWindow(topic, span))!;
    final last = (await repository.inspectHistoryWindow(
      topic,
      span,
      retain: HistoryDirection.newer,
    ))!;
    expect(first.span.server, const SequenceRange(1, 11));
    expect(first.newer.isBlocked, isTrue);
    expect(last.span.server, const SequenceRange(231, 241));
    expect(last.older.isBlocked, isTrue);
  });

  test(
    'empty completed intervals advance span exactly once per action',
    () async {
      await database.mergeTopic(scope, topic, {'seq': 1000});
      gateway.ready = true;
      final first = (await repository.openHistory(topic))!;
      expect(first.messages, isEmpty);
      expect(first.span.server, const SequenceRange(961, 1001));
      expect(first.older.canLoad, isTrue);
      expect(first.newer.isExhausted, isTrue);
      expect(gateway.requests, hasLength(1));
      final next = (await repository.extendHistory(
        topic,
        first.span,
        direction: HistoryDirection.older,
      ))!;
      expect(next.messages, isEmpty);
      expect(next.span.server, const SequenceRange(921, 1001));
      expect(gateway.requests, hasLength(2));
      expect(gateway.requests.last, (since: 921, before: 961, limit: 40));
    },
  );

  test('typed open preserves a proved deleted prefix end', () async {
    await cache(200, 205);
    await database.applyDeletions(scope, topic, [
      {'low': 1, 'hi': 200},
    ], 1);
    gateway.ready = true;
    final first = (await repository.openHistory(topic))!;
    expect(first.span.server, const SequenceRange(1, 206));
    expect(first.older.isExhausted, isTrue);
    expect(first.newer.isExhausted, isTrue);
    await repository.extendHistory(
      topic,
      first.span,
      direction: HistoryDirection.older,
    );
    await repository.openHistory(topic);
    expect(gateway.requests, isEmpty);
  });

  test(
    'inspection queries the span, not a stale list of message IDs',
    () async {
      await cache(1, 40);
      const span = HistorySpan(server: SequenceRange(1, 41));
      final first = (await repository.inspectHistoryWindow(topic, span))!;
      await database.hide(scope, topic, 20);
      final next = (await repository.inspectHistoryWindow(topic, span))!;
      expect(first.messages, hasLength(40));
      expect(next.messages, hasLength(39));
      expect(next.messages.any((m) => m.seq == 20), isFalse);
      expect(next.span, first.span);
    },
  );

  test(
    'atomic snapshot cannot split a retained local ACK between reads',
    () async {
      await repository.send(topic, 'queued');
      final pending = (await database.pendingMessages(scope, topic)).single;
      final span = HistorySpan(
        server: const SequenceRange(1, 1),
        local: SequenceRange(pending.localSeq, pending.localSeq + 1),
        retainedLocalIds: {pending.id},
      );
      final captured = Completer<void>(), release = Completer<void>();
      (database as _SnapshotDatabase).afterRows = () async {
        captured.complete();
        await release.future;
      };
      final reading = repository.inspectHistoryWindow(topic, span);
      await captured.future;
      var committed = false;
      final ack = database
          .mergeMessage(
            scope,
            ChatMessage(
              id: pending.id,
              topicId: topic,
              seq: 1,
              localSeq: pending.localSeq,
              senderId: 'me',
              createdAt: pending.createdAt,
              content: pending.content,
            ),
            'me',
          )
          .then((_) => committed = true);
      await pumpEventQueue();
      expect(
        committed,
        isFalse,
        reason: 'ACK write must wait for the read snapshot',
      );
      release.complete();
      final old = (await reading)!;
      await ack;
      expect(old.messages.single.id, pending.id);
      expect(old.messages.single.pending, isTrue);
      final current = (await repository.inspectHistoryWindow(topic, span))!;
      expect(current.messages.single.id, pending.id);
      expect(current.messages.single.seq, 1);
      expect(current.span, span, reason: 'ACK must not redefine paging bounds');
    },
  );

  test('retained local ACKs do not manufacture a newer page', () async {
    for (var i = 1; i <= 4; i++) {
      await repository.send(topic, 'queued $i');
    }
    final first = (await repository.openHistory(topic))!;
    gateway.ready = true;
    await repository.flushOutbox();
    final next = (await repository.inspectHistoryWindow(topic, first.span))!;
    expect(next.messages.map((m) => m.id), first.messages.map((m) => m.id));
    expect(next.messages.map((m) => m.seq), [1, 2, 3, 4]);
    expect(next.span, first.span);
    expect(next.newer.isExhausted, isTrue);
    expect(next.older.isExhausted, isTrue);
  });

  test(
    'canonicalized or evicted IDs cannot re-enter the retained suffix',
    () async {
      for (var i = 1; i <= 4; i++) {
        await repository.send(topic, 'queued $i');
      }
      final pending = (await repository.openHistory(topic))!;
      expect(
        () => pending.span.retainedLocalIds.add('foreign'),
        throwsUnsupportedError,
      );
      gateway.ready = true;
      await repository.flushOutbox();
      final expanded = HistorySpan(
        server: const SequenceRange(1, 5),
        local: pending.span.local,
        retainedLocalIds: pending.span.retainedLocalIds,
      );
      final window = (await repository.inspectHistoryWindow(
        topic,
        expanded,
        capacity: 2,
        retain: HistoryDirection.newer,
      ))!;
      expect(window.messages.map((m) => m.seq), [3, 4]);
      expect(window.span.retainedLocalIds, isEmpty);
      final again = (await repository.inspectHistoryWindow(
        topic,
        window.span,
        capacity: 2,
        retain: HistoryDirection.newer,
      ))!;
      expect(again.messages, window.messages);
      final equivalent = HistorySpan(
        server: pending.span.server,
        local: pending.span.local,
        retainedLocalIds: pending.span.retainedLocalIds
            .toList()
            .reversed
            .toSet(),
      );
      expect(equivalent, pending.span);
      expect(equivalent.hashCode, pending.span.hashCode);
    },
  );

  test(
    'late retained ACK below an opened server span keeps its stable ID',
    () async {
      await repository.send(topic, 'accepted before peer, ACK delayed');
      final pending = (await database.pendingMessages(scope, topic)).single;
      await cache(2, 2);
      final first = (await repository.openHistory(topic))!;
      expect(first.span.server, const SequenceRange(2, 3));
      expect(first.messages.any((m) => m.id == pending.id), isTrue);
      await database.mergeMessage(
        scope,
        ChatMessage(
          id: pending.id,
          topicId: topic,
          seq: 1,
          localSeq: pending.localSeq,
          senderId: 'me',
          createdAt: pending.createdAt,
          content: pending.content,
        ),
        'me',
      );
      final next = (await repository.inspectHistoryWindow(topic, first.span))!;
      expect(next.messages.where((m) => m.id == pending.id).single.seq, 1);
      expect(
        next.span.server,
        first.span.server,
        reason: 'a retained ACK is not a request to navigate',
      );
    },
  );

  test(
    'ACK of an evicted local origin is older than a pending window',
    () async {
      for (var i = 1; i <= 165; i++) {
        await repository.send(topic, 'queued $i');
      }
      final first = (await repository.openHistory(topic))!;
      final old = (await database.pendingMessages(
        scope,
        topic,
        limit: 165,
      )).first;
      await database.mergeMessage(
        scope,
        ChatMessage(
          id: old.id,
          topicId: topic,
          seq: 1,
          localSeq: old.localSeq,
          senderId: 'me',
          createdAt: old.createdAt,
          content: old.content,
        ),
        'me',
      );
      final next = (await repository.inspectHistoryWindow(topic, first.span))!;
      expect(next.messages, first.messages);
      expect(next.newer.isExhausted, isTrue);
      expect(next.older.canLoad, isTrue);
    },
  );

  test(
    'older navigation crosses an ACKed suffix at its first local row',
    () async {
      for (var i = 1; i <= 165; i++) {
        await repository.send(topic, 'queued $i');
      }
      final first = (await repository.openHistory(topic))!;
      gateway.ready = true;
      await repository.flushOutbox();
      final next = (await repository.extendHistory(
        topic,
        first.span,
        direction: HistoryDirection.older,
      ))!;
      expect(next.rebaseAnchorId, first.messages.first.id);
      expect(next.messages.any((m) => m.id == first.messages.first.id), isTrue);
      expect(next.messages.length, lessThanOrEqualTo(120));
      expect(next.newer.isExhausted, isTrue);
      expect(gateway.requests, isEmpty);
    },
  );

  test(
    'interleaved ACK/peer traversal has no holes or resurrected IDs',
    () async {
      for (var i = 1; i <= 165; i++) {
        await repository.send(topic, 'queued $i');
      }
      var window = (await repository.openHistory(topic))!;
      final queued = await database.pendingMessages(scope, topic, limit: 165);
      for (var i = 0; i < queued.length; i++) {
        final local = queued[i];
        await database.mergeMessage(
          scope,
          ChatMessage(
            id: local.id,
            topicId: topic,
            seq: i * 2 + 1,
            localSeq: local.localSeq,
            senderId: 'me',
            createdAt: local.createdAt,
            content: local.content,
          ),
          'me',
        );
        await cache(i * 2 + 2, i * 2 + 2);
      }
      final seen = window.messages.map((m) => m.id).toSet();
      for (var i = 0; i < 12 && window.older.canLoad; i++) {
        window = (await repository.extendHistory(
          topic,
          window.span,
          direction: HistoryDirection.older,
        ))!;
        seen.addAll(window.messages.map((m) => m.id));
      }
      expect(window.older.isExhausted, isTrue);
      for (var i = 0; i < 20 && window.newer.canLoad; i++) {
        window = (await repository.extendHistory(
          topic,
          window.span,
          direction: HistoryDirection.newer,
        ))!;
        final inspected = (await repository.inspectHistoryWindow(
          topic,
          window.span,
          retain: HistoryDirection.newer,
        ))!;
        expect(
          inspected.messages.map((m) => m.id),
          window.messages.map((m) => m.id),
          reason: 'rehydrating a span must not resurrect evicted ACKs',
        );
        expect(window.messages.length, lessThanOrEqualTo(120));
        seen.addAll(window.messages.map((m) => m.id));
      }
      expect(window.newer.isExhausted, isTrue);
      expect(seen, hasLength(330));
      expect(gateway.requests, isEmpty);
    },
  );

  test('later ACK never drops an earlier failed pending origin', () async {
    await repository.send(topic, 'failed earlier');
    await repository.send(topic, 'sent later');
    final local = await database.pendingMessages(scope, topic);
    await database.mergeMessage(
      scope,
      ChatMessage(
        id: local.last.id,
        topicId: topic,
        seq: 1,
        localSeq: local.last.localSeq,
        senderId: 'me',
        createdAt: local.last.createdAt,
        content: local.last.content,
      ),
      'me',
    );
    await cache(2, 2);
    final span = HistorySpan(
      server: const SequenceRange(1, 3),
      local: SequenceRange(local.first.localSeq, local.last.localSeq + 1),
      retainedLocalIds: local.map((m) => m.id).toSet(),
    );
    final window = (await repository.inspectHistoryWindow(
      topic,
      span,
      retain: HistoryDirection.newer,
    ))!;
    expect(window.messages.map((m) => m.id), [
      local.last.id,
      '$topic:2',
      local.first.id,
    ]);
    expect(window.messages.last.pending, isTrue);
    final again = (await repository.inspectHistoryWindow(
      topic,
      window.span,
      retain: HistoryDirection.newer,
    ))!;
    expect(again.messages, window.messages);
  });

  test('live include crosses a known ACK prefix without a duplicate', () async {
    await repository.send(topic, 'queued 1');
    await repository.send(topic, 'queued 2');
    final first = (await repository.openHistory(topic))!;
    final ack = first.messages.first;
    await database.mergeMessage(
      scope,
      ChatMessage(
        id: ack.id,
        topicId: topic,
        seq: 1,
        localSeq: ack.localSeq,
        senderId: 'me',
        createdAt: ack.createdAt,
        content: ack.content,
      ),
      'me',
    );
    await cache(2, 2);
    final peer = (await repository.getMessage(topic, 2))!;
    final window = (await repository.inspectHistoryWindow(
      topic,
      first.span,
      include: peer,
      retain: HistoryDirection.newer,
    ))!;
    expect(window.messages.map((m) => m.id), [
      ack.id,
      peer.id,
      first.messages.last.id,
    ]);
    expect(window.newer.isExhausted, isTrue);
    expect(window.older.isExhausted, isTrue);
  });

  test(
    'retry ACK rebase keeps the selected ID, not distant old neighbors',
    () async {
      await repository.send(topic, 'retry later');
      await repository.send(topic, 'accepted first');
      final first = (await repository.openHistory(topic))!;
      final local = first.messages;
      for (var i = 0; i < local.length; i++) {
        final message = local[i];
        await database.mergeMessage(
          scope,
          ChatMessage(
            id: message.id,
            topicId: topic,
            seq: i == 0 ? 300 : 1,
            localSeq: message.localSeq,
            senderId: 'me',
            createdAt: message.createdAt,
            content: message.content,
          ),
          'me',
        );
      }
      await cache(2, 299, serverSeq: 300);
      gateway.ready = true;
      for (final anchor in local) {
        final next = (await repository.extendHistory(
          topic,
          first.span,
          direction: HistoryDirection.older,
          anchorId: anchor.id,
        ))!;
        expect(next.rebaseAnchorId, anchor.id);
        expect(next.messages.any((m) => m.id == anchor.id), isTrue);
        expect(
          next.span.local,
          isNull,
          reason: 'distant ACKs cannot leak through suffix',
        );
        expect(next.messages.length, lessThanOrEqualTo(120));
        expect(
          next.messages.map((m) => m.seq).toList(),
          orderedEquals([...next.messages.map((m) => m.seq)]..sort()),
        );
      }
      expect(
        gateway.requests,
        isEmpty,
        reason: 'rebase is strictly cache-only',
      );
    },
  );

  test('cached target open never selects an unrelated newer island', () async {
    await cache(50, 50, serverSeq: 70);
    await cache(60, 70);
    final next = (await repository.openHistory(topic, aroundId: '$topic:50'))!;
    expect(next.messages.single.seq, 50);
    expect(next.newer.isBlocked, isTrue);
  });

  test(
    'cached bidirectional windows stay capped and return to the tail',
    () async {
      await cache(1, 240);
      var window = (await repository.openHistory(topic))!;
      for (var i = 0; i < 5; i++) {
        window = (await repository.extendHistory(
          topic,
          window.span,
          direction: HistoryDirection.older,
        ))!;
        expect(window.messages.length, lessThanOrEqualTo(120));
      }
      expect(window.messages.first.seq, 1);
      expect(window.older.isExhausted, isTrue);
      for (var i = 0; i < 5 && window.newer.canLoad; i++) {
        window = (await repository.extendHistory(
          topic,
          window.span,
          direction: HistoryDirection.newer,
        ))!;
        expect(window.messages.length, lessThanOrEqualTo(120));
      }
      expect(window.messages.last.seq, 240);
      expect(window.newer.isExhausted, isTrue);
      expect(gateway.requests, isEmpty);
    },
  );
}
