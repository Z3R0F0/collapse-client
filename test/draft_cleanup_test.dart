import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  late AppDatabase database;
  late FakeGateway gateway;
  late ChatsRepository repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = FakeGateway();
    repository = ChatsRepository(
      database: database,
      gateway: gateway,
      serverId: 'local',
    );
    await repository.start('me');
    for (final scope in ['local|me', 'local|other']) {
      await database.mergeTopic(scope, 'peer', const {});
      await database.setDraft(scope, 'peer', 'Submitted draft');
    }
  });

  tearDown(() async {
    await repository.dispose();
    await gateway.dispose();
    await database.close();
  });

  test('conditional cleanup matches both expected text and account', () async {
    final generation = repository.sessionGeneration;
    await repository.updateDraft('peer', 'Newer draft');
    await repository.clearDraftIfMatches(
      'peer',
      'Submitted draft',
      userId: 'me',
      sessionGeneration: generation,
    );
    expect((await repository.getTopic('peer'))?.draft, 'Newer draft');
    await repository.clearDraftIfMatches(
      'peer',
      'Newer draft',
      userId: 'me',
      sessionGeneration: generation,
    );
    expect((await repository.getTopic('peer'))?.draft, '');
    expect(
      (await database.topicRow('local|other', 'peer'))?.draft,
      'Submitted draft',
    );
  });

  for (final relogin in [false, true]) {
    test(
      'cleanup rejects ${relogin ? 'same' : 'different'} account session',
      () async {
        final generation = repository.sessionGeneration;
        await repository.stop();
        await repository.start(relogin ? 'me' : 'other');
        await repository.clearDraftIfMatches(
          'peer',
          'Submitted draft',
          userId: 'me',
          sessionGeneration: generation,
        );
        for (final scope in ['local|me', 'local|other']) {
          expect(
            (await database.topicRow(scope, 'peer'))?.draft,
            'Submitted draft',
          );
        }
      },
    );
  }
}
