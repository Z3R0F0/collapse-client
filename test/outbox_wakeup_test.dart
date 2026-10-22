import 'dart:async';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class _ReadGateDatabase extends AppDatabase {
  _ReadGateDatabase() : super.forTesting(NativeDatabase.memory());
  int reads = 0;
  int? blockRead;
  final captured = Completer<void>();
  final release = Completer<void>();

  @override
  Future<List<OutboxRow>> pendingOutbox(String scope) async {
    final rows = await super.pendingOutbox(scope);
    if (++reads == blockRead) {
      captured.complete();
      await release.future;
    }
    return rows;
  }
}

void main() {
  late _ReadGateDatabase database;
  late FakeGateway gateway;
  late ChatsRepository repository;
  setUp(() async {
    database = _ReadGateDatabase();
    gateway = FakeGateway();
    repository = ChatsRepository(
      database: database,
      gateway: gateway,
      serverId: 'local',
    );
    await repository.start('me');
    database.reads = 0;
    await repository.send('usrPeer', {'txt': 'first'});
    gateway.ready = true;
  });
  tearDown(() async {
    await repository.dispose();
    await gateway.dispose();
    await database.close();
  });

  test(
    'enqueue during publish drains without waiting for retry timer',
    () async {
      final publishing = Completer<void>();
      final release = Completer<void>();
      gateway.beforePublish = (call) async {
        if (call == 1) {
          publishing.complete();
          await release.future;
        }
      };
      final flushing = repository.flushOutbox();
      await publishing.future;
      await repository.send('usrPeer', {'txt': 'second'});
      release.complete();
      await flushing;
      expect(gateway.rows.map((row) => row['content']), [
        {'txt': 'first'},
        {'txt': 'second'},
      ]);
    },
  );

  test('enqueue after final empty snapshot cannot lose its wakeup', () async {
    database.blockRead = 2;
    final flushing = repository.flushOutbox();
    await database.captured.future;
    await repository.send('usrPeer', {'txt': 'second'});
    database.release.complete();
    await flushing;
    expect(gateway.rows.map((row) => row['content']), [
      {'txt': 'first'},
      {'txt': 'second'},
    ]);
    expect(await database.pendingOutbox('local|me'), isEmpty);
  });
}
