import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/search_fixture.dart';
import 'support/window_race_fixture.dart';

class _PausedSearchDatabase extends AppDatabase {
  _PausedSearchDatabase() : super.forTesting(NativeDatabase.memory());

  ReadGate<bool>? beforeSnapshot;

  @override
  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool requireNew = false,
  }) async {
    final gate = beforeSnapshot;
    beforeSnapshot = null;
    // Cached-first open has captured its account/generation, but no SQLite
    // transaction is held yet. ACK/deletion writes may finish before the
    // snapshot without relying on a deliberately bypassed network attachment.
    if (gate != null) await gate.pause(true);
    return super.transaction(action, requireNew: requireNew);
  }
}

void main() {
  late _PausedSearchDatabase db;
  late FakeGateway gateway;
  late ChatsRepository repo;
  setUp(() async {
    db = _PausedSearchDatabase();
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
    'stable-ID jump reaches queued results beyond the 120-row window',
    () async {
      for (var i = 1; i <= 165; i++) {
        await repo.send(searchTopic, 'Queued item $i');
      }
      final matches = (await repo.searchMessages(
        searchTopic,
        '"item 20"',
      ))!.hits;
      final target = matches.single;
      final rows = await repo.loadAroundId(searchTopic, target.id);
      expect(rows, hasLength(40));
      expect(rows.any((m) => m.id == target.id), isTrue);
      expect(rows.first.text, 'Queued item 1');
      expect(rows.last.text, 'Queued item 40');
      expect(await repo.hasCachedMessageAfter(rows.last), isTrue);
      expect(gateway.requests, isEmpty);
      expect(gateway.notes, isEmpty);
    },
  );

  test(
    'jump refreshes a pending ID which was ACKed before selection',
    () async {
      for (var i = 1; i <= 6; i++) {
        await repo.send(searchTopic, 'queued $i');
      }
      final target = (await repo.searchMessages(
        searchTopic,
        '"queued 3"',
      ))!.hits.single;
      gateway.ready = true;
      await repo.flushOutbox();
      final rows = await repo.loadAroundId(searchTopic, target.id);
      expect(rows.where((m) => m.id == target.id).single.seq, 3);
      expect(rows.every((m) => !m.pending), isTrue);
    },
  );

  for (final ack in [true, false]) {
    test(
      'pending jump ${ack ? 'follows ACK' : 'rejects deletion'} during page read',
      () async {
        for (var i = 1; i <= 6; i++) {
          await repo.send(searchTopic, 'queued $i');
        }
        final target = (await repo.searchMessages(
          searchTopic,
          '"queued 3"',
        ))!.hits.single;
        final gate = db.beforeSnapshot = ReadGate<bool>();
        final future = repo.loadAroundId(searchTopic, target.id);
        await gate.captured.future;
        if (ack) {
          gateway.ready = true;
          await repo.flushOutbox();
        } else {
          final row = await db.messageById(searchScope, target.id);
          await db.cancelPending(searchScope, db.toMessage(row!));
        }
        gate.release.complete();
        final rows = await future;
        if (ack) {
          expect(rows.where((m) => m.id == target.id).single.seq, 3);
          expect(rows.map((m) => m.id).toSet().length, rows.length);
        } else {
          expect(rows, isEmpty);
        }
      },
    );
  }

  test(
    'jump ignores another topic and rejects same-user session replacement',
    () async {
      await repo.send(searchTopic, 'queued');
      final target = (await repo.searchMessages(
        searchTopic,
        'queued',
      ))!.hits.single;
      expect(await repo.loadAroundId('grpOther', target.id), isEmpty);
      final gate = db.beforeSnapshot = ReadGate<bool>();
      final future = repo.loadAroundId(searchTopic, target.id);
      await gate.captured.future;
      await repo.stop();
      await repo.start('me');
      gate.release.complete();
      expect(await future, isEmpty);
    },
  );
}
