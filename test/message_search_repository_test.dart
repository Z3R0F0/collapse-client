import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/search_fixture.dart';
import 'support/window_race_fixture.dart';

class _PausedSearchDatabase extends AppDatabase {
  _PausedSearchDatabase() : super.forTesting(NativeDatabase.memory());
  ReadGate<bool>? gate;
  @override
  Future<bool> prepareSearch(String scope, String topicId) async {
    final paused = gate;
    gate = null;
    final ready = await super.prepareSearch(scope, topicId);
    return paused == null ? ready : paused.pause(ready);
  }
}

class _PausedSearchGateway extends FakeGateway {
  ReadGate<List<Map<String, dynamic>>>? historyGate;
  @override
  Future<List<Map<String, dynamic>>> history(
    String topic, {
    int? since,
    int? before,
    int limit = 40,
  }) async {
    final gate = historyGate;
    historyGate = null;
    final rows = await super.history(
      topic,
      since: since,
      before: before,
      limit: limit,
    );
    return gate == null ? rows : gate.pause(rows);
  }
}

void main() {
  late _PausedSearchDatabase db;
  late _PausedSearchGateway gateway;
  late ChatsRepository repo;
  setUp(() async {
    db = _PausedSearchDatabase();
    gateway = _PausedSearchGateway();
    repo = ChatsRepository(database: db, gateway: gateway, serverId: 'local');
    await repo.start('me');
    await db.mergeTopic(searchScope, searchTopic, {'seq': 0});
  });
  tearDown(() async {
    await repo.dispose();
    await gateway.dispose();
    await db.close();
  });

  test(
    'cached preparation and result cursors stay bounded with no network',
    () async {
      for (var i = 1; i <= 85; i++) {
        await legacySearchMessage(db, i, 'Привет $i');
      }
      await db.mergeTopic(searchScope, searchTopic, {'seq': 100});
      var page = (await repo.searchMessages(searchTopic, 'ПРИВ'))!;
      expect(page.cacheIndexed, isFalse);
      expect(page.hits, hasLength(40));
      expect(page.nextCursor, isNull);
      page = (await repo.searchMessages(searchTopic, 'ПРИВ'))!;
      expect(page.cacheIndexed, isFalse);
      page = (await repo.searchMessages(searchTopic, 'ПРИВ'))!;
      expect(page.cacheIndexed, isTrue);
      expect(page.historyComplete, isFalse);
      expect(page.canLoadHistory, isFalse);
      final next = (await repo.searchMessages(
        searchTopic,
        'ПРИВ',
        before: page.nextCursor,
      ))!;
      expect(next.hits.map((h) => h.seq), List.generate(40, (i) => 45 - i));
      expect(gateway.requests, isEmpty);
      expect(gateway.notes, isEmpty);
    },
  );

  test(
    'load more fetches one missing range and reports actual coverage',
    () async {
      gateway.seed(200);
      gateway.ready = true;
      await repo.ensureTopic(searchTopic);
      await repo.loadBefore(searchTopic, 201);
      var page = (await repo.searchMessages(searchTopic, 'message'))!;
      expect(page.historyComplete, isFalse);
      expect(page.canLoadHistory, isTrue);
      final start = gateway.requests.length;
      expect(await repo.loadMoreSearchHistory(searchTopic), isTrue);
      expect(gateway.requests.length, start + 1);
      expect(gateway.requests.last, (since: 121, before: 161, limit: 40));
      // Deleted coverage counts, but an internal unfilled interval still does not.
      await db.applyDeletions(searchScope, searchTopic, [
        {'low': 1, 'hi': 81},
      ], 1);
      page = (await repo.searchMessages(searchTopic, 'message'))!;
      expect(page.historyComplete, isFalse);
      expect(await repo.loadMoreSearchHistory(searchTopic), isTrue);
      expect(gateway.requests.last, (since: 81, before: 121, limit: 40));
      page = (await repo.searchMessages(searchTopic, 'message'))!;
      expect(page.historyComplete, isTrue);
      expect(page.canLoadHistory, isFalse);
      expect(await repo.loadMoreSearchHistory(searchTopic), isFalse);
      expect(gateway.notes.where((n) => n.what == 'read'), isEmpty);
    },
  );

  test(
    'empty history advances one interval only, without crawling deletions',
    () async {
      gateway.ready = true;
      gateway.descriptions[searchTopic] = {'seq': 1000};
      await repo.ensureTopic(searchTopic);
      expect(await repo.loadMoreSearchHistory(searchTopic), isTrue);
      expect(gateway.requests, [(since: 961, before: 1001, limit: 40)]);
      expect(
        (await repo.searchMessages(searchTopic, 'missing'))!.historyComplete,
        isFalse,
      );
      expect(await repo.loadMoreSearchHistory(searchTopic), isTrue);
      expect(gateway.requests.last, (since: 921, before: 961, limit: 40));
      expect(gateway.requests, hasLength(2));
    },
  );

  test('same-account relogin invalidates a pending cached result', () async {
    await legacySearchMessage(db, 1, 'Private');
    final gate = db.gate = ReadGate<bool>();
    final future = repo.searchMessages(searchTopic, 'private');
    await gate.captured.future;
    await repo.stop();
    await repo.start('me');
    gate.release.complete();
    expect(await future, isNull);
  });

  test(
    'late history cannot populate another account or return stale success',
    () async {
      gateway.seed(80);
      gateway.ready = true;
      await repo.ensureTopic(searchTopic);
      final gate = gateway.historyGate = ReadGate<List<Map<String, dynamic>>>();
      final future = repo.loadMoreSearchHistory(searchTopic);
      await gate.captured.future;
      await repo.start('other');
      gate.release.complete();
      expect(await future, isNull);
      expect(await db.page('local|other', searchTopic), isEmpty);
      expect(gateway.notes.where((n) => n.what == 'read'), isEmpty);
    },
  );
}
