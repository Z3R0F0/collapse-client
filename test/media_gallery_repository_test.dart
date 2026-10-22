import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse_tinode/tinode.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/media_gallery_fixture.dart';

void main() {
  late GalleryFixture f;
  setUp(() async {
    f = GalleryFixture();
    await f.start();
  });
  tearDown(() => f.dispose());

  test(
    'metadata page preserves chat rows, history coverage and receipts',
    () async {
      final topic = (await f.db.topicRow(galleryScope, galleryTopic))!;
      f.gateway.response = {
        'items': [galleryPacket(20, key: 3, clientId: 'untrusted-peer-id')],
        'snapshot': 200,
        'hasOlder': true,
        'hasNewer': false,
      };
      final page = await f.gallery.page(galleryTopic, MediaCategory.visual);
      expect(page.items.single.entityIndex, 3);
      expect(page.items.single.messageId, '$galleryTopic:20');
      expect(page.snapshot, 200);
      expect(page.hasOlder, isTrue);
      expect(await f.db.select(f.db.messages).get(), isEmpty);
      final after = (await f.db.topicRow(galleryScope, galleryTopic))!;
      expect(after.toJson(), topic.toJson());
      expect(f.gateway.requests, isEmpty);
      expect(f.gateway.notes, isEmpty);
      expect(f.media.requested, isEmpty);
      expect(f.gateway.mediaRequests.single['kind'], 'visual');
      f.gateway.ready = false;
      final offline = await f.gallery.page(galleryTopic, MediaCategory.visual);
      expect(offline.offline, isTrue);
      expect(offline.items.single.id, page.items.single.id);
      expect(f.gateway.mediaRequests, hasLength(1));
      expect(await f.db.select(f.db.messages).get(), isEmpty);
    },
  );

  test(
    'quoted/hidden entities stay excluded; keys and composite cursors survive',
    () async {
      final doc = DraftyCodec.reply(
        content: galleryPhoto(),
        quote: galleryPhoto(),
        authorId: 'peer',
        authorName: 'Peer',
      );
      await f.db.mergeMessage(galleryScope, galleryMessage(10, doc), 'me');
      await f.db.mergeMessage(
        galleryScope,
        galleryMessage(11, {
          'txt': '   ',
          'fmt': [
            {'at': 0, 'len': 1},
            {'at': 0, 'len': 1, 'tp': 'HD'},
            {'at': 1, 'len': 1, 'key': 2},
            {'at': 2, 'len': 1, 'key': 3},
          ],
          'ent': [
            {'tp': 'IM'},
            null,
            {
              'tp': 'VD',
              'data': {'ref': '/v0/file/s/v'},
            },
            {
              'tp': 'IM',
              'data': {'ref': '/v0/file/s/i'},
            },
          ],
        }),
        'me',
      );
      final page = await f.gallery.cached(galleryTopic, MediaCategory.visual);
      expect(page.items.map((i) => (i.seq, i.entityIndex)), [
        (10, 3),
        (11, 2),
        (11, 3),
      ]);
      final older = await f.gallery.cached(
        galleryTopic,
        MediaCategory.visual,
        before: const MediaCursor(11, 3),
        limit: 1,
      );
      expect((older.items.single.seq, older.items.single.entityIndex), (11, 2));
      final newer = await f.gallery.cached(
        galleryTopic,
        MediaCategory.visual,
        after: const MediaCursor(11, 2),
        limit: 1,
      );
      expect((newer.items.single.seq, newer.items.single.entityIndex), (11, 3));
      final absent = await f.gallery.cached(
        galleryTopic,
        MediaCategory.visual,
        around: const MediaCursor(11, 1),
      );
      expect(absent.anchorFound, isFalse);
      expect(await f.gallery.find(galleryTopic, 10, 1), isNull);
    },
  );

  test(
    'late previous-session response cannot populate either account cache',
    () async {
      final started = Completer<void>(), response = Completer<JsonMap>();
      f.gateway.onMedia = () {
        started.complete();
        return response.future;
      };
      final task = f.gallery.page(galleryTopic, MediaCategory.visual);
      final rejected = expectLater(task, throwsStateError);
      await started.future;
      await f.chats.stop();
      f.gateway.ready = false;
      f.gateway.userId = 'other';
      await f.chats.start('other');
      response.complete({
        'items': [galleryPacket(20)],
      });
      await rejected;
      expect(await f.db.select(f.db.mediaEntries).get(), isEmpty);
    },
  );

  test('cached anchor cannot bypass the requested media category', () async {
    final audio = MediaItem.fromJson(galleryTopic, {
      ...galleryPacket(10, type: 'AU'),
      'clientId': 'audio',
    });
    await f.db.cacheMedia(galleryScope, [audio, galleryItem(11)]);
    final result = await f.gallery.cached(
      galleryTopic,
      MediaCategory.visual,
      around: audio.cursor,
    );
    expect(result.anchorFound, isFalse);
    expect(result.items.every((item) => item.visual), isTrue);
  });

  test(
    'inline empty ref fetches exactly one original, then uses local bytes',
    () async {
      const bytes = [1, 2, 3, 4];
      f.gateway.rows.add({
        'topic': galleryTopic,
        'seq': 20,
        'from': 'peer',
        'ts': DateTime.utc(2026).toIso8601String(),
        'content': galleryPhoto(ref: '', value: base64Encode(bytes)),
      });
      f.gateway.response = {
        'items': [
          galleryPacket(
            20,
            key: 1,
            inline: true,
            data: {'ref': '', 'mime': 'image/png'},
          ),
        ],
      };
      final item = (await f.gallery.page(
        galleryTopic,
        MediaCategory.visual,
      )).items.single;
      expect(f.gateway.requests, isEmpty);
      expect(item.data.containsKey('val'), isFalse);
      expect(await f.gallery.bytes(item), bytes);
      expect(f.gateway.requests, [(since: 20, before: 21, limit: 1)]);
      expect(await f.gallery.bytes(item), bytes);
      expect(f.gateway.requests, hasLength(1));
      expect(f.gateway.notes.where((n) => n.what == 'read'), isEmpty);
    },
  );

  test(
    'ref plus inline preview stays metadata-only and preserves usable ref',
    () async {
      final doc = galleryPhoto(ref: '/v0/file/s/full', value: 'AQID');
      await f.db.mergeMessage(galleryScope, galleryMessage(20, doc), 'me');
      final item = (await f.gallery.cached(
        galleryTopic,
        MediaCategory.visual,
      )).items.single;
      expect(item.inline, isTrue);
      expect(item.data['ref'], '/v0/file/s/full');
      expect(item.data.containsKey('val'), isFalse);
      expect(f.media.draftyReference(item.data), '/v0/file/s/full');
      expect(f.gateway.requests, isEmpty);
      expect(f.media.requested, isEmpty);
    },
  );

  test(
    'late metadata never resurrects hidden rows or uncached deletion ranges',
    () async {
      await f.db.mergeMessage(
        galleryScope,
        galleryMessage(10, galleryPhoto()),
        'me',
      );
      await f.db.hide(galleryScope, galleryTopic, 10);
      await f.db.applyDeletions(galleryScope, galleryTopic, [
        {'low': 11, 'hi': 13},
      ], 1);
      f.gateway.response = {
        'items': [
          galleryPacket(10, key: 1),
          galleryPacket(11, key: 1),
          galleryPacket(13, key: 1),
        ],
        'hasOlder': true,
        'hasNewer': true,
        'delId': 1,
        'anchorFound': true,
      };
      final page = await f.gallery.page(
        galleryTopic,
        MediaCategory.visual,
        around: const MediaCursor(10, 1),
      );
      expect(
        page.anchorFound,
        isFalse,
        reason: 'a locally hidden target is unavailable, not its neighbour',
      );
      expect(page.items.map((item) => item.seq), [13]);
      expect(
        page.olderCursor!.seq,
        10,
      ); // Raw page progress survives filtering.
      expect(page.newerCursor!.seq, 13);
      expect((await f.db.select(f.db.mediaEntries).get()).map((r) => r.seq), [
        13,
      ]);
    },
  );

  test(
    'end-of-transaction generation guard rolls metadata writes back',
    () async {
      await f.db.cacheMedia(galleryScope, [galleryItem(1)]);
      var checks = 0;
      await expectLater(
        f.db.cacheMedia(
          galleryScope,
          [galleryItem(2), galleryItem(3)],
          check: () {
            if (++checks == 2) throw StateError('Closed session');
          },
        ),
        throwsStateError,
      );
      expect(checks, 2);
      expect((await f.db.select(f.db.mediaEntries).get()).map((r) => r.seq), [
        1,
      ]);
    },
  );

  test(
    'pending entity resolves durable bytes and retains exact identity on ACK',
    () async {
      f.gateway.ready = false;
      await f.chats.send(
        galleryTopic,
        galleryPhoto(ref: ''),
        uploads: [
          PendingUpload(
            entityIndex: 1,
            bytes: Uint8List.fromList([5, 6]),
            name: 'photo.png',
            mime: 'image/png',
          ),
        ],
      );
      final queued = (await f.db.pendingOutbox(galleryScope)).single;
      final message = f.db.toMessage(
        (await f.db.messageById(galleryScope, queued.clientId))!,
      );
      final item = (await f.gallery.find(
        galleryTopic,
        message.seq,
        1,
        messageId: message.id,
      ))!;
      expect(await f.gallery.bytes(item), [5, 6]);
      await f.db.mergeMessage(
        galleryScope,
        galleryMessage(201, galleryPhoto(), id: message.id, sender: 'me'),
        'me',
      );
      final acknowledged = (await f.gallery.retained(galleryTopic, [
        item,
      ])).single;
      expect(acknowledged.id, item.id);
      expect(acknowledged.seq, 201);
      expect(acknowledged.entityIndex, 1);
      expect(await f.db.pendingOutbox(galleryScope), isEmpty);
    },
  );

  test(
    'revoked membership removes stale gallery metadata, not cached messages',
    () async {
      await f.db.mergeMessage(
        galleryScope,
        galleryMessage(10, galleryPhoto()),
        'me',
      );
      f.gateway.onMedia = () async =>
          throw const TinodeException(403, 'revoked');
      await expectLater(
        f.gallery.page(galleryTopic, MediaCategory.visual),
        throwsA(isA<TinodeException>()),
      );
      expect(await f.db.select(f.db.mediaEntries).get(), isEmpty);
      expect(await f.db.select(f.db.messages).get(), hasLength(1));
    },
  );

  test(
    'schema2 upgrade preserves raw messages, FTS, draft and queued bytes',
    () async {
      await f.dispose();
      final dir = await Directory.systemTemp.createTemp(
        'collapse-media-migration-',
      );
      final file = File('${dir.path}/cache.sqlite');
      final old = GallerySchemaV2(NativeDatabase(file));
      var oldClosed = false;
      final raw = jsonEncode({...galleryPhoto(), 'txt': ' photo caption'});
      try {
        await old.mergeTopic(galleryScope, galleryTopic, {
          'seq': 20,
          'read': 7,
        });
        await old.setDraft(galleryScope, galleryTopic, 'unsent draft');
        await old
            .into(old.messages)
            .insert(
              MessagesCompanion.insert(
                scope: galleryScope,
                topicId: galleryTopic,
                seq: 20,
                clientId: 'old',
                senderId: 'peer',
                createdAtMs: 1,
                content: raw,
              ),
            );
        await old
            .into(old.outboxAttachments)
            .insert(
              OutboxAttachmentsCompanion.insert(
                scope: galleryScope,
                clientId: 'queued',
                entityIndex: 3,
                bytes: Uint8List.fromList([7, 8, 9]),
                name: 'pending',
                mime: 'image/png',
              ),
            );
        await old
            .into(old.outbox)
            .insert(
              OutboxCompanion.insert(
                scope: galleryScope,
                clientId: 'queued',
                topicId: galleryTopic,
                localSeq: 1,
              ),
            );
        await old.prepareSearch(galleryScope, galleryTopic);
        final before = await old.select(old.messageSearch).get();
        await old.close();
        oldClosed = true;
        final db = AppDatabase.forTesting(NativeDatabase(file));
        try {
          expect(
            (await db.messageRow(galleryScope, galleryTopic, 20))!.content,
            raw,
          );
          expect(
            (await db.topicRow(galleryScope, galleryTopic))!.draft,
            'unsent draft',
          );
          expect((await db.uploads(galleryScope, 'queued')).single.bytes, [
            7,
            8,
            9,
          ]);
          expect(
            (await db.pendingOutbox(galleryScope)).single.clientId,
            'queued',
          );
          expect(
            await db.searchMessages(galleryScope, galleryTopic, 'caption'),
            hasLength(1),
          );
          expect(
            (await db.select(db.messageSearch).get()).map((r) => r.toJson()),
            before.map((r) => r.toJson()),
          );
          expect(await db.select(db.mediaEntries).get(), isEmpty);
          expect(await db.prepareMedia(galleryScope, galleryTopic), isTrue);
          expect(
            (await db.mediaPage(
              galleryScope,
              galleryTopic,
              MediaCategory.visual,
            )).single.entityIndex,
            1,
          );
          expect(
            (await db.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version'),
            3,
          );
          expect(
            await db
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type='index' AND name='media_category'",
                )
                .get(),
            hasLength(1),
          );
        } finally {
          await db.close();
        }
      } finally {
        if (!oldClosed) await old.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
