import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_gateway.dart';
import 'support/window_race_fixture.dart';

class _BeforeCursorDatabase extends AppDatabase {
  _BeforeCursorDatabase() : super.forTesting(NativeDatabase.memory());
  ReadGate<bool>? beforeCursor;

  @override
  Future<MessageRow?> messageById(String scope, String id) async {
    final gate = beforeCursor;
    beforeCursor = null;
    // Pause outside the DB transaction: ACK may finish before cursor resolution.
    if (gate != null) await gate.pause(true);
    return super.messageById(scope, id);
  }
}

void main() {
  late _BeforeCursorDatabase database;
  late FakeGateway gateway;
  late ChatsRepository repository;
  setUp(() async {
    database = _BeforeCursorDatabase();
    gateway = FakeGateway();
    repository = ChatsRepository(
      database: database,
      gateway: gateway,
      serverId: 'local',
    );
    await repository.start('me');
    for (var i = 1; i <= 4; i++) {
      await repository.send('usrPeer', 'queued $i');
    }
  });
  tearDown(() async {
    await repository.dispose();
    await gateway.dispose();
    await database.close();
  });

  for (final older in [true, false]) {
    for (final inFlight in [true, false]) {
      test(
        '${older ? 'older' : 'newer'} cursor follows ACK ${inFlight ? 'before atomic snapshot' : 'before navigation'}',
        () async {
          final cursor = (await database.pendingMessages(
            'local|me',
            'usrPeer',
          ))[1];
          Future<MessagePage> load() => older
              ? repository.loadBeforeMessage(cursor)
              : repository.loadAfterMessage(cursor);
          Future<MessagePage>? page;
          ReadGate<bool>? gate;
          if (inFlight) {
            gate = database.beforeCursor = ReadGate<bool>();
            page = load();
            await gate.captured.future;
          }
          gateway.ready = true;
          await repository.flushOutbox();
          gate?.release.complete();
          final result = await (page ?? load());
          expect(result.messages.map((m) => m.seq), older ? [1] : [3, 4]);
          expect(
            result.messages.every((m) => m.delivery == Delivery.sent),
            isTrue,
          );
        },
      );
    }
  }
}
