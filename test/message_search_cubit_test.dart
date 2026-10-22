import 'dart:async';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/presentation/chat/search/message_search_cubit.dart';
import 'package:collapse_tinode/collapse_tinode.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

SearchPage _page(String text, {bool indexed = true, SearchCursor? next}) =>
    SearchPage(
      hits: [
        SearchHit(
          id: text,
          topicId: 'peer',
          seq: 10,
          localSeq: 0,
          senderId: 'peer',
          createdAt: DateTime(2026),
          snippet: text,
        ),
      ],
      cacheIndexed: indexed,
      historyComplete: false,
      canLoadHistory: true,
      nextCursor: next,
    );

class _Repository extends ChatsRepository {
  _Repository(AppDatabase database, TinodeGateway gateway)
    : super(database: database, gateway: gateway, serverId: 'search-test');
  String account = 'me';
  final calls = <(String, SearchCursor?)>[];
  Future<SearchPage?> Function(String, SearchCursor?)? answer;
  int loads = 0;

  @override
  String get currentUserId => account;

  @override
  Future<SearchPage?> searchMessages(
    String topicId,
    String query, {
    SearchCursor? before,
    int limit = 40,
  }) async {
    calls.add((query, before));
    return answer == null ? _page(query) : answer!(query, before);
  }

  @override
  Future<bool?> loadMoreSearchHistory(String topicId) async {
    loads++;
    return true;
  }
}

void main() {
  late AppDatabase database;
  late TinodeGateway gateway;
  late _Repository repository;
  late MessageSearchCubit cubit;
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = TinodeGateway(
      endpoint: Uri.parse('ws://localhost:6060'),
      apiKey: 'test',
    );
    repository = _Repository(database, gateway);
    cubit = MessageSearchCubit(repository, 'peer');
  });
  tearDown(() async {
    await cubit.close();
    await repository.dispose();
    await gateway.dispose();
    await database.close();
  });

  Future<void> idle() => cubit.stream
      .firstWhere((state) => !state.loading && !state.loadingHistory)
      .timeout(const Duration(seconds: 2));

  test('late query response cannot replace a newer query', () async {
    final old = Completer<SearchPage>();
    repository.answer = (query, _) async =>
        query == 'old' ? old.future : _page(query);
    cubit.search('old', immediate: true);
    final ready = idle();
    cubit.search('new', immediate: true);
    await ready;
    old.complete(_page('old'));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.page!.hits.single.snippet, 'new');
  });

  test(
    'cached preparation yields bounded calls and exposes progress',
    () async {
      repository.answer = (query, _) async =>
          _page(query, indexed: repository.calls.length == 3);
      final states = <MessageSearchState>[];
      final subscription = cubit.stream.listen(states.add);
      final ready = idle();
      cubit.search('text', immediate: true);
      await ready;
      expect(repository.calls, hasLength(3));
      expect(
        states.any(
          (state) => state.page?.cacheIndexed == false && state.loading,
        ),
        isTrue,
      );
      expect(cubit.state.page!.cacheIndexed, isTrue);
      await subscription.cancel();
    },
  );

  test(
    'result pagination replaces one page and remembers only cursors',
    () async {
      const next = (pending: false, order: 10);
      repository.answer = (_, cursor) async => _page(
        cursor == null ? 'newer' : 'older',
        next: cursor == null ? next : null,
      );
      final ready = idle();
      cubit.search('word', immediate: true);
      await ready;
      await cubit.next();
      expect(cubit.state.page!.hits.single.snippet, 'older');
      expect(cubit.state.canPrevious, isTrue);
      await cubit.previous();
      expect(cubit.state.page!.hits.single.snippet, 'newer');
      expect(cubit.state.canPrevious, isFalse);
      expect(repository.calls.map((call) => call.$2), [null, next, null]);
    },
  );

  test('history action fetches once then refreshes cached results', () async {
    final ready = idle();
    cubit.search('word', immediate: true);
    await ready;
    await cubit.loadHistory();
    expect(repository.loads, 1);
    expect(repository.calls, hasLength(2));
    expect(cubit.state.busy, isFalse);
  });

  test('failed Next rolls back its cursor before retry and Previous', () async {
    const next = (pending: false, order: 10);
    var fail = true;
    repository.answer = (_, cursor) async {
      if (cursor != null && fail) {
        fail = false;
        throw StateError('Temporary failure');
      }
      return _page(
        cursor == null ? 'first' : 'second',
        next: cursor == null ? next : null,
      );
    };
    final ready = idle();
    cubit.search('word', immediate: true);
    await ready;
    await cubit.next();
    expect(cubit.state.error, isTrue);
    expect(cubit.state.canPrevious, isFalse);
    expect(cubit.state.page!.hits.single.snippet, 'first');
    await cubit.next();
    expect(cubit.state.page!.hits.single.snippet, 'second');
    await cubit.previous();
    expect(cubit.state.page!.hits.single.snippet, 'first');
    expect(cubit.state.canPrevious, isFalse);
  });

  test(
    'failed Previous can retry without losing the first-page cursor',
    () async {
      const next = (pending: false, order: 10);
      var fail = false;
      repository.answer = (_, cursor) async {
        if (cursor == null && fail) {
          fail = false;
          throw StateError('Temporary failure');
        }
        return _page(
          cursor == null ? 'first' : 'second',
          next: cursor == null ? next : null,
        );
      };
      final ready = idle();
      cubit.search('word', immediate: true);
      await ready;
      await cubit.next();
      fail = true;
      await cubit.previous();
      expect(cubit.state.page!.hits.single.snippet, 'second');
      expect(cubit.state.canPrevious, isTrue);
      await cubit.previous();
      expect(cubit.state.page!.hits.single.snippet, 'first');
      expect(cubit.state.canPrevious, isFalse);
    },
  );

  test('clearing or closing cancels a debounced query', () async {
    cubit.search('cancelled');
    cubit.search('');
    await Future<void>.delayed(const Duration(milliseconds: 280));
    expect(repository.calls, isEmpty);
    cubit.search('closed');
    await cubit.close();
    await Future<void>.delayed(const Duration(milliseconds: 280));
    expect(repository.calls, isEmpty);
  });

  test(
    'a stale repository response becomes retryable rather than hanging',
    () async {
      repository.answer = (_, _) async => null;
      final ready = idle();
      cubit.search('word', immediate: true);
      await ready;
      expect(cubit.state.error, isTrue);
      expect(cubit.state.busy, isFalse);
    },
  );

  test('account change rejects an in-flight response', () async {
    final response = Completer<SearchPage>();
    repository.answer = (_, _) => response.future;
    cubit.search('private', immediate: true);
    repository.account = 'other';
    response.complete(_page('private'));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.page, isNull);
  });
}
