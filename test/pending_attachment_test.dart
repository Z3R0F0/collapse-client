import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'support/pending_attachment_fixture.dart';

void main() {
  late PreviewFixture fixture;
  setUp(() => fixture = PreviewFixture());
  tearDown(() => fixture.dispose());

  Future<ChatMessage> queue() => fixture.queue(
    {
      'txt': ' ',
      'ent': [
        null,
        {
          'tp': 'IM',
          'data': {'ref': ''},
        },
      ],
    },
    [
      PendingUpload(
        entityIndex: 1,
        bytes: Uint8List.fromList([1, 2, 3]),
        name: 'image.png',
        mime: 'image/png',
      ),
    ],
  );

  test(
    'one original entity index reads durable offline bytes without network',
    () async {
      final message = await queue();
      expect(await fixture.repo.pendingAttachmentBytes(message, 1), [1, 2, 3]);
      expect(await fixture.repo.pendingAttachmentBytes(message, 0), isNull);
      expect(await fixture.repo.pendingAttachmentBytes(message, -1), isNull);
      expect(fixture.gateway.uploads, 0);
      expect(fixture.gateway.publishes, 0);
      expect(jsonEncode(message.content), isNot(contains('AQID')));
    },
  );

  test(
    'uploaded pending bytes remain available, then ACK removes local source',
    () async {
      final message = await queue();
      final uploaded = {
        'txt': ' ',
        'ent': [
          null,
          {
            'tp': 'IM',
            'data': {'ref': '/v0/file/s/image'},
          },
        ],
      };
      await fixture.db.uploaded(
        'test|me',
        message.id,
        1,
        '/v0/file/s/image',
        uploaded,
      );
      expect(await fixture.repo.pendingAttachmentBytes(message, 1), [1, 2, 3]);
      final acknowledged = await fixture.db.mergeMessage(
        'test|me',
        previewMessage(message, seq: 1, content: uploaded),
        'me',
      );
      expect(acknowledged.id, message.id);
      expect(await fixture.repo.pendingAttachmentBytes(message, 1), isNull);
      expect(
        await fixture.repo.pendingAttachmentBytes(acknowledged, 1),
        isNull,
      );
    },
  );

  test(
    'cancelled rows and other accounts cannot provide preview bytes',
    () async {
      final message = await queue();
      await fixture.repo.stop();
      await fixture.repo.start('other');
      expect(await fixture.repo.pendingAttachmentBytes(message, 1), isNull);
      await fixture.repo.stop();
      await fixture.repo.start('me');
      await fixture.repo.hideMessage(message);
      expect(await fixture.repo.pendingAttachmentBytes(message, 1), isNull);
    },
  );

  test(
    'same-account logout/relogin invalidates an in-flight SQLite read',
    () async {
      final message = await queue();
      fixture.db.readGate = Completer<void>();
      fixture.db.readStarted = Completer<void>();
      final pending = fixture.repo.pendingAttachmentBytes(message, 1);
      await fixture.db.readStarted!.future;
      await fixture.repo.stop();
      await fixture.repo.start('me');
      fixture.db.readGate!.complete();
      expect(await pending, isNull);
    },
  );

  test('SQL excludes an oversized stored blob before returning it', () async {
    final message = await queue();
    await fixture.db.customUpdate(
      'UPDATE outbox_attachments SET bytes = zeroblob(?) WHERE scope = ? AND client_id = ?',
      variables: [
        const Variable(10485761),
        const Variable('test|me'),
        Variable(message.id),
      ],
    );
    expect(await fixture.repo.pendingAttachmentBytes(message, 1), isNull);
  });

  test(
    'playable bytes reuse scoped native inline cache with no wire/base64',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final first = await fixture.media.playableBytes(bytes, 'audio/wav');
      expect(first.scheme, 'file');
      expect(await fixture.media.playableBytes(bytes, 'audio/wav'), first);
      expect(fixture.cache.writes, hasLength(1));
      expect(fixture.cache.writes.single, bytes);
      fixture.media.userId = 'other';
      await fixture.media.playableBytes(bytes, 'audio/wav');
      expect(fixture.cache.writes, hasLength(2));
      expect(fixture.cache.networkReads, 0);
    },
  );

  test(
    'native source preparation cannot complete into a new account generation',
    () async {
      fixture.cache.readGate = Completer<void>();
      final pending = fixture.media.playableBytes(
        Uint8List.fromList([1]),
        'audio/wav',
      );
      fixture.media.userId = null;
      fixture.media.userId = 'me';
      fixture.cache.readGate!.complete();
      await expectLater(pending, throwsStateError);
      expect(fixture.cache.writes, isEmpty);
    },
  );
}
