import 'dart:io';
import 'dart:typed_data';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse_tinode/collapse_tinode.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/search_fixture.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.mergeTopic(searchScope, searchTopic, {'seq': 100});
  });
  tearDown(() => db.close());

  test(
    'spoiler text and URLs stay out of live and rebuilt search indexes',
    () async {
      final content = DraftyCodec.markdown(
        'Public ||**PrivateWord** [hidden](https://privateword.example)||',
      );
      await db.mergeMessage(searchScope, searchMessage(1, content), 'me');
      await legacySearchMessage(db, 2, content);
      expect(await db.prepareSearch(searchScope, searchTopic), isTrue);
      expect(
        await db.searchMessages(searchScope, searchTopic, 'Public'),
        hasLength(2),
      );
      for (final query in ['PrivateWord', 'hidden', 'example']) {
        expect(
          await db.searchMessages(searchScope, searchTopic, query),
          isEmpty,
        );
      }
      expect((await db.select(db.messageSearch).get()).map((row) => row.body), [
        'Public',
        'Public',
      ]);
    },
  );

  test('native FTS5 supports RU/EN case and prefix without stemming', () async {
    final version = await db
        .customSelect('SELECT sqlite_version() AS version')
        .getSingle();
    expect(version.read<String>('version'), '3.53.4');
    await db.mergeMessage(
      searchScope,
      searchMessage(1, 'ПрИвЕт Hello ЁЛКА'),
      'me',
    );
    for (final query in ['ПРИВ', 'привет', 'hello', 'HEL', 'ёлк']) {
      expect(
        await db.searchMessages(searchScope, searchTopic, query),
        hasLength(1),
      );
    }
    for (final query in ['рив', 'елка', 'приветствие', '" OR NOT * :']) {
      expect(await db.searchMessages(searchScope, searchTopic, query), isEmpty);
    }
    expect(await db.searchMessages(searchScope, searchTopic, '!!!'), isEmpty);
    await db.customStatement('VACUUM');
    expect(
      await db.searchMessages(searchScope, searchTopic, 'прив'),
      hasLength(1),
    );
  });

  test(
    'legacy preparation is 40 rows, isolated and cursor-paginated',
    () async {
      for (var i = 1; i <= 85; i++) {
        await legacySearchMessage(db, i, 'Привет Hello $i');
      }
      await legacySearchMessage(db, 1, 'Привет', scope: 'local|other');
      await legacySearchMessage(db, 1, 'Привет', topic: 'grpOther');
      expect(await db.prepareSearch(searchScope, searchTopic), isFalse);
      expect(await db.select(db.messageSearch).get(), hasLength(40));
      expect(await db.prepareSearch(searchScope, searchTopic), isFalse);
      expect(await db.prepareSearch(searchScope, searchTopic), isTrue);
      final first = await db.searchMessages(searchScope, searchTopic, 'прив');
      expect(first.map((h) => h.seq), List.generate(40, (i) => 85 - i));
      final second = await db.searchMessages(
        searchScope,
        searchTopic,
        'прив',
        before: first.last.cursor,
      );
      expect(second.map((h) => h.seq), List.generate(40, (i) => 45 - i));
      final third = await db.searchMessages(
        searchScope,
        searchTopic,
        'прив',
        before: second.last.cursor,
      );
      expect(third.map((h) => h.seq), [5, 4, 3, 2, 1]);
    },
  );

  test('one large token cannot produce an unbounded search snippet', () async {
    final content = 'Long${'x' * 128000}';
    await db.mergeMessage(searchScope, searchMessage(1, content), 'me');
    final result = (await db.searchMessages(
      searchScope,
      searchTopic,
      'long',
    )).single;
    expect(result.snippet.length, 512);
    expect(
      (await db.messageRow(searchScope, searchTopic, 1))!.content.length,
      content.length + 2,
    );
  });

  test(
    'projection omits media bytes and matches visible Drafty semantics',
    () async {
      final content = DraftyCodec.reply(
        content: DraftyCodec.markdown('Visible **Привет**\nworld'),
        quote: DraftyCodec.text('QuotedSecret'),
        authorId: 'peer',
        authorName: 'Peer',
      );
      (content['ent'] as List).add({
        'tp': 'IM',
        'data': {'val': 'BinarySecret' * 100000},
      });
      await legacySearchMessage(db, 1, content);
      await legacySearchMessage(db, 2, {
        'txt': 'HiddenSecret shown',
        'fmt': [
          {'tp': 'HD', 'at': 0, 'len': 12},
        ],
      });
      await legacySearchMessage(db, 3, {
        'txt': 'safe',
        'fmt': [null, 4],
        'ent': 'bad',
      });
      expect(await db.prepareSearch(searchScope, searchTopic), isTrue);
      final rows = await db.select(db.messageSearch).get();
      expect(
        rows.firstWhere((r) => r.seq == 1).body,
        DraftyCodec.previewText(content),
      );
      expect(rows.every((r) => r.body.length < 100), isTrue);
      expect(
        await db.searchMessages(searchScope, searchTopic, 'прив'),
        hasLength(1),
      );
      for (final query in ['QuotedSecret', 'BinarySecret', 'HiddenSecret']) {
        expect(
          await db.searchMessages(searchScope, searchTopic, query),
          isEmpty,
        );
      }
    },
  );

  test(
    'malformed format/entity fields never project nested binary payloads',
    () async {
      final binary = {'bytes': 'BinarySecret' * 100000};
      final content = <String, dynamic>{
        'txt': 'Malformed Visible',
        'fmt': [
          {'at': binary, 'len': 9, 'tp': 'HD'},
          {'at': 0, 'len': binary, 'tp': 'HD'},
          {'at': 0, 'len': 9, 'tp': binary},
          {'at': 0, 'len': 9, 'key': binary},
          {'at': 0, 'len': 9, 'key': 0},
        ],
        'ent': [
          {'tp': binary},
        ],
      };
      await legacySearchMessage(db, 1, content);
      expect(await db.prepareSearch(searchScope, searchTopic), isTrue);
      expect(
        (await db.select(db.messageSearch).get()).single.body,
        DraftyCodec.previewText(content),
      );
      expect(
        (await db.searchMessages(
          searchScope,
          searchTopic,
          'malformed',
        )).single.snippet,
        'Malformed Visible',
      );
    },
  );

  test(
    'enqueue ACK content updates deletion and scope clear stay synchronized',
    () async {
      final pending = searchMessage(-1, 'Queue Привет', id: 'stable');
      await db.enqueue(searchScope, pending, []);
      expect(
        (await db.searchMessages(
          searchScope,
          searchTopic,
          'queue',
        )).single.pending,
        isTrue,
      );
      await db.mergeMessage(
        searchScope,
        searchMessage(1, 'Queue Привет', id: 'stable'),
        'me',
      );
      final hits = await db.searchMessages(searchScope, searchTopic, 'queue');
      expect(hits.single.id, 'stable');
      expect(hits.single.seq, 1);
      expect(await db.select(db.messageSearch).get(), hasLength(1));
      await db.mergeMessage(
        searchScope,
        searchMessage(1, 'Changed', id: 'stable'),
        'me',
      );
      expect(
        await db.searchMessages(searchScope, searchTopic, 'queue'),
        isEmpty,
      );
      expect(
        await db.searchMessages(searchScope, searchTopic, 'change'),
        hasLength(1),
      );
      await db.hide(searchScope, searchTopic, 1);
      expect(
        await db.searchMessages(searchScope, searchTopic, 'change'),
        isEmpty,
      );
      await db.mergeMessage(searchScope, searchMessage(2, 'Deleted'), 'me');
      await db.applyDeletions(searchScope, searchTopic, [
        {'low': 2},
      ], 1);
      expect(
        await db.searchMessages(searchScope, searchTopic, 'delete'),
        isEmpty,
      );
      await db.mergeMessage('local|other', searchMessage(1, 'Retained'), 'me');
      await db.clearScope(searchScope);
      expect(
        (await db.select(db.messageSearch).get()).single.scope,
        'local|other',
      );
      await db.customStatement(
        "INSERT INTO message_fts(message_fts, rank) VALUES('integrity-check', 1)",
      );
    },
  );

  test(
    'schema1 upgrades without rewriting raw messages or pending bytes',
    () async {
      await db.close();
      final dir = await Directory.systemTemp.createTemp(
        'collapse-search-migration-',
      );
      final file = File('${dir.path}/cache.sqlite');
      final old = SearchSchemaV1(NativeDatabase(file));
      await legacySearchMessage(old, 1, {
        'txt': 'Старая история',
        'custom': 'preserved',
      });
      await old.customStatement(
        'INSERT INTO outbox_attachments VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          searchScope,
          'pending',
          0,
          Uint8List.fromList([1, 2, 3]),
          'image.png',
          'image/png',
          null,
        ],
      );
      await old.close();
      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      try {
        expect(
          (await migrated.messageRow(searchScope, searchTopic, 1))!.content,
          '{"txt":"Старая история","custom":"preserved"}',
        );
        expect(await migrated.select(migrated.messageSearch).get(), isEmpty);
        expect((await migrated.uploads(searchScope, 'pending')).single.bytes, [
          1,
          2,
          3,
        ]);
        expect(await migrated.prepareSearch(searchScope, searchTopic), isTrue);
        expect(
          await migrated.searchMessages(searchScope, searchTopic, 'СТАР'),
          hasLength(1),
        );
        expect(
          (await migrated.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          3,
        );
      } finally {
        await migrated.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
