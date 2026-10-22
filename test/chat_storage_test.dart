import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/core/database/message_seq_cache.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

ChatMessage message(
  int seq, {
  String id = '',
  String sender = 'me',
  String topic = 'usrPeer',
  Delivery delivery = Delivery.sent,
  Object content = 'hello',
  int localSeq = 0,
  DateTime? createdAt,
}) => ChatMessage(
  id: id.isEmpty ? '$topic:$seq' : id,
  topicId: topic,
  seq: seq,
  localSeq: localSeq,
  senderId: sender,
  createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(1000 + seq.abs()),
  content: content,
  delivery: delivery,
);

void main() {
  // Tests intentionally use independent memory/file executors simultaneously.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.mergeTopic('server|me', 'usrPeer', {
      'public': {'fn': 'Peer'},
    });
  });
  tearDown(() => db.close());

  test('cache compresses sequence ranges and ignores pending sequence', () {
    final cache = MessageSeqCache();
    for (final seq in [3, 1, 2, 5, 4, 4, -1]) {
      cache.add('chat', seq);
    }
    expect(
      List.generate(5, (i) => cache.contains('chat', i + 1)),
      everyElement(isTrue),
    );
    expect(cache.contains('other', 1), isFalse);
    expect(cache.contains('chat', -1), isFalse);
    cache.clear();
    expect(cache.contains('chat', 1), isFalse);
  });

  test('account/server scopes isolate identical topic ids', () async {
    await db.mergeTopic('another|me', 'usrPeer', {
      'public': {'fn': 'Other server'},
    });
    await db.mergeMessage('server|me', message(1), 'me');
    expect(await db.page('another|me', 'usrPeer'), isEmpty);
    await db.clearScope('server|me');
    expect((await db.topicRow('another|me', 'usrPeer'))?.title, 'Other server');
  });

  test(
    'pending cancellation stays hidden across late acknowledgements',
    () async {
      final pending = message(
        -1,
        id: 'cancelled',
        localSeq: 1,
        delivery: Delivery.queued,
      );
      await db.enqueue('server|me', pending, []);
      await db.cancelPending('server|me', pending);
      await db.mergeMessage('server|me', message(1, id: 'cancelled'), 'me');
      expect(await db.page('server|me', 'usrPeer'), isEmpty);

      final racing = message(
        -2,
        id: 'ack-race',
        localSeq: 2,
        delivery: Delivery.queued,
      );
      await db.enqueue('server|me', racing, []);
      await db.mergeMessage('server|me', message(2, id: 'ack-race'), 'me');
      await db.cancelPending('server|me', racing);
      expect(await db.page('server|me', 'usrPeer'), isEmpty);
      expect(await db.pendingOutbox('server|me'), isEmpty);
    },
  );

  test(
    'avatar accepts refs and inline data, preserves partials and clears explicit removal',
    () async {
      Future<void> photo(Object? value) =>
          db.mergeTopic('server|me', 'usrPeer', {
            'public': {'photo': value},
          });
      Future<String?> avatar() async =>
          (await db.topicRow('server|me', 'usrPeer'))?.avatarRef;

      await photo({'ref': '/v0/file/s/avatar', 'data': 'ignored'});
      expect(await avatar(), '/v0/file/s/avatar');
      await db.mergeTopic('server|me', 'usrPeer', {'seq': 10});
      await db.mergeTopic('server|me', 'usrPeer', {
        'public': {'fn': 'Renamed'},
      });
      expect(await avatar(), '/v0/file/s/avatar');

      for (final type in ['png', 'image/png']) {
        await photo({'data': 'AQID', 'type': type});
        expect(await avatar(), 'data:image/png;base64,AQID');
      }
      await photo({'data': 'AQID'});
      expect(await avatar(), 'data:image/jpeg;base64,AQID');

      for (final removed in [
        null,
        <String, dynamic>{},
        {'ref': ''},
        {'data': ''},
      ]) {
        await photo({'ref': '/v0/file/s/previous'});
        await photo(removed);
        expect(await avatar(), isNull);
      }
    },
  );

  test(
    'ACK replaces optimistic row atomically and echo preserves stable identity',
    () async {
      final pending = message(
        -900,
        id: 'client-id',
        localSeq: 900,
        delivery: Delivery.queued,
      );
      await db.enqueue('server|me', pending, []);
      final accepted = await db.mergeMessage(
        'server|me',
        message(12, id: 'client-id', localSeq: 900),
        'me',
      );
      expect(accepted.id, 'client-id');
      expect(await db.messageRow('server|me', 'usrPeer', -900), isNull);
      expect(await db.pendingOutbox('server|me'), isEmpty);
      await db.mergeMessage(
        'server|me',
        message(12, id: 'client-id', localSeq: 900),
        'me',
      );
      expect(await db.page('server|me', 'usrPeer'), hasLength(1));
    },
  );

  test(
    'read/received counters never regress or mutate incoming ownership',
    () async {
      await db.mergeMessage('server|me', message(10), 'me');
      await db.mergeMessage('server|me', message(11, sender: 'peer'), 'me');
      await db.receipts('server|me', 'usrPeer', 'me', peerRead: 12, read: 11);
      await db.receipts('server|me', 'usrPeer', 'me', peerRecv: 8, read: 3);
      expect(
        (await db.messageRow('server|me', 'usrPeer', 10))?.delivery,
        Delivery.read.index,
      );
      expect(
        (await db.messageRow('server|me', 'usrPeer', 11))?.delivery,
        Delivery.sent.index,
      );
      expect((await db.topicRow('server|me', 'usrPeer'))?.readSeq, 11);
      await db.mergeMessage('server|me', message(10), 'me');
      expect(
        (await db.messageRow('server|me', 'usrPeer', 10))?.delivery,
        Delivery.read.index,
      );
    },
  );

  test(
    'history cannot roll back latest summary, even with later timestamps',
    () async {
      await db.mergeMessage('server|me', message(20, content: 'latest'), 'me');
      await db.mergeMessage(
        'server|me',
        message(10, content: 'history', createdAt: DateTime(2099)),
        'me',
      );
      expect(
        (await db.topicRow('server|me', 'usrPeer'))?.lastPreview,
        'latest',
      );
    },
  );

  test(
    'deletion tombstone survives late history and local hide survives echo',
    () async {
      await db.applyDeletions('server|me', 'usrPeer', [
        {'low': 10, 'hi': 13},
      ], 1);
      await db.mergeMessage('server|me', message(11), 'me');
      await db.mergeMessage('server|me', message(13), 'me');
      expect((await db.page('server|me', 'usrPeer')).map((m) => m.seq), [13]);
      await db.hide('server|me', 'usrPeer', 13);
      await db.mergeMessage('server|me', message(13), 'me');
      expect(await db.page('server|me', 'usrPeer'), isEmpty);
    },
  );

  test(
    'pending Drafty, headers, full media bytes survive database restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'collapse-outbox-test-',
      );
      final file = File('${directory.path}/test.sqlite');
      final disk = AppDatabase.forTesting(NativeDatabase(file));
      final content = {
        'txt': 'caption',
        'ent': [
          {
            'tp': 'AU',
            'data': {'duration': 1200, 'preview': 'AQI='},
          },
        ],
      };
      final pending = ChatMessage(
        id: 'voice',
        topicId: 'usrPeer',
        seq: -123,
        localSeq: 123,
        senderId: 'me',
        createdAt: DateTime(2026),
        content: content,
        head: {'reply': '4', 'forwarded': 'usrOther:8', 'x-client-id': 'voice'},
        delivery: Delivery.queued,
      );
      await disk.enqueue('server|me', pending, [
        PendingUpload(
          entityIndex: 0,
          bytes: Uint8List.fromList([1, 2, 255]),
          name: 'voice.m4a',
          mime: 'audio/mp4',
        ),
      ]);
      await disk.close();
      final reopened = AppDatabase.forTesting(NativeDatabase(file));
      final stored = (await reopened.messageById('server|me', 'voice'))!;
      expect(jsonDecode(stored.content), content);
      expect(jsonDecode(stored.head), pending.head);
      expect((await reopened.uploads('server|me', 'voice')).single.bytes, [
        1,
        2,
        255,
      ]);
      expect(await reopened.pendingOutbox('server|me'), hasLength(1));
      await reopened.close();
      await directory.delete(recursive: true);
    },
  );
}
