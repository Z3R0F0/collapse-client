import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class _EnqueueGateDatabase extends AppDatabase {
  _EnqueueGateDatabase() : super.forTesting(NativeDatabase.memory());
  final entered = Completer<void>();
  final release = Completer<void>();
  int calls = 0;
  bool failFirst = false;

  @override
  Future<void> enqueue(
    String scope,
    ChatMessage message,
    List<PendingUpload> uploads, {
    String? clearDraft,
  }) async {
    if (++calls == 1) {
      entered.complete();
      await release.future;
      if (failFirst) throw StateError('Synthetic local storage failure');
    }
    await super.enqueue(scope, message, uploads, clearDraft: clearDraft);
  }
}

void main() {
  late _EnqueueGateDatabase database;
  late FakeGateway gateway;
  late ChatsRepository repository;
  setUp(() async {
    database = _EnqueueGateDatabase();
    gateway = FakeGateway();
    repository = ChatsRepository(
      database: database,
      gateway: gateway,
      serverId: 'local',
    );
    await repository.start('me');
    await database.mergeTopic('local|me', 'usrPeer', const {});
    await database.setDraft('local|me', 'usrPeer', 'Older saved draft');
  });
  tearDown(() async {
    await repository.dispose();
    await gateway.dispose();
    await database.close();
  });
  Future<List<Object?>> queuedContents(String scope) async => [
    for (final row in await database.pendingOutbox(scope))
      jsonDecode((await database.messageById(scope, row.clientId))!.content),
  ];

  test(
    'concurrent local sends preserve FIFO and captured nested payloads',
    () async {
      final content = <String, dynamic>{'txt': 'first'};
      final head = <String, dynamic>{
        'custom': {'value': 'original'},
      };
      final first = repository.send('usrPeer', content, head: head);
      content['txt'] = 'caller changed';
      (head['custom'] as Map)['value'] = 'caller changed';
      await database.entered.future;
      final second = repository.send('usrPeer', {'txt': 'second'});
      await Future<void>.delayed(Duration.zero);
      expect(
        database.calls,
        1,
        reason: 'second local transaction waits, not transport',
      );
      database.release.complete();
      await Future.wait([first, second]);
      expect(await queuedContents('local|me'), [
        {'txt': 'first'},
        {'txt': 'second'},
      ]);
      final id = (await database.pendingOutbox('local|me')).first.clientId;
      final saved = await database.messageById('local|me', id);
      expect((jsonDecode(saved!.head) as Map)['custom'], {'value': 'original'});
      expect(gateway.publishes, 0);
    },
  );

  test('validation errors remain asynchronous and do not enqueue', () async {
    // There is no entity0 to upload into. Calling send itself must not throw.
    final result = repository.send(
      'usrPeer',
      {'txt': 'invalid'},
      uploads: [
        PendingUpload(
          entityIndex: 0,
          bytes: Uint8List(1),
          name: 'x',
          mime: 'text/plain',
        ),
      ],
    );
    await expectLater(result, throwsArgumentError);
    expect(database.calls, 0);
    expect(await queuedContents('local|me'), isEmpty);
  });

  test(
    'enqueue atomically clears old debounce draft and preserves next write',
    () async {
      final sending = repository.send('usrPeer', {
        'txt': 'new text',
      }, clearDraft: true);
      await database.entered.future;
      final nextDraft = repository.updateDraft('usrPeer', 'Next typed draft');
      database.release.complete();
      await Future.wait([sending, nextDraft]);
      expect((await repository.getTopic('usrPeer'))!.draft, 'Next typed draft');
      expect(await queuedContents('local|me'), [
        {'txt': 'new text'},
      ]);
    },
  );

  test(
    'successful enqueue clears a persisted draft older than current input',
    () async {
      final sending = repository.send('usrPeer', {
        'txt': 'new text',
      }, clearDraft: true);
      await database.entered.future;
      database.release.complete();
      await sending;
      expect((await repository.getTopic('usrPeer'))!.draft, '');
    },
  );

  test(
    'failed local write preserves draft and does not poison later sends',
    () async {
      database.failFirst = true;
      final first = repository.send('usrPeer', {
        'txt': 'first',
      }, clearDraft: true);
      final failed = expectLater(first, throwsStateError);
      await database.entered.future;
      final second = repository.send('usrPeer', {'txt': 'second'});
      database.release.complete();
      await failed;
      await second;
      expect(await queuedContents('local|me'), [
        {'txt': 'second'},
      ]);
      expect(
        (await repository.getTopic('usrPeer'))!.draft,
        'Older saved draft',
      );
    },
  );

  for (final sameAccount in [false, true]) {
    test(
      'deferred intent rejects ${sameAccount ? 'same' : 'other'} new session',
      () async {
        final first = repository.send('usrPeer', {'txt': 'accepted locally'});
        await database.entered.future;
        final deferred = repository.send('usrPeer', {
          'txt': 'old queued intent',
        });
        final rejected = expectLater(deferred, throwsStateError);
        await repository.stop();
        await repository.start(sameAccount ? 'me' : 'other');
        database.release.complete();
        await first;
        await rejected;
        expect(await queuedContents('local|me'), [
          {'txt': 'accepted locally'},
        ]);
        expect(await queuedContents('local|other'), isEmpty);
      },
    );
  }

  test('outbox transaction rollback also preserves the draft', () async {
    await database.customStatement('''
      CREATE TRIGGER fail_outbox BEFORE INSERT ON outbox
      BEGIN SELECT RAISE(ABORT, 'synthetic outbox failure'); END
    ''');
    final sending = repository.send('usrPeer', {
      'txt': 'rollback',
    }, clearDraft: true);
    final failed = expectLater(sending, throwsA(isA<Exception>()));
    await database.entered.future;
    database.release.complete();
    await failed;
    expect(await database.page('local|me', 'usrPeer'), isEmpty);
    expect(await database.pendingOutbox('local|me'), isEmpty);
    expect((await repository.getTopic('usrPeer'))!.draft, 'Older saved draft');
  });
}
