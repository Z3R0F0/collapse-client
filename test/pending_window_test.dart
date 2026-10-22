import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/presentation/chat/chat_cubit.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  late AppDatabase database;
  late FakeGateway gateway;
  late ChatsRepository repository;
  late ChatCubit cubit;
  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = FakeGateway();
    repository = ChatsRepository(
      database: database,
      gateway: gateway,
      serverId: 'local',
    );
    await repository.start('me');
    cubit = ChatCubit(repository);
  });
  tearDown(() async {
    await cubit.close();
    await repository.dispose();
    await gateway.dispose();
    await database.close();
  });

  Future<void> queue(int count) async {
    for (var i = 1; i <= count; i++) {
      await repository.send('usrPeer', 'queued $i');
    }
  }

  test(
    'reopening shows the newest pending messages, not the first 20',
    () async {
      await queue(55);
      await cubit.open('usrPeer');
      expect(cubit.state.messages, hasLength(40));
      expect(cubit.state.messages.first.text, 'queued 16');
      expect(cubit.state.messages.last.text, 'queued 55');
      expect(cubit.state.atLiveEdge, isTrue);
      expect(cubit.state.hasNewer, isFalse);
      expect(cubit.state.hasOlder, isTrue);
    },
  );

  test('pending-only history pages both ways with a 120-row limit', () async {
    await queue(165);
    await cubit.open('usrPeer');
    final seen = <String>{};
    for (var i = 0; i < 6; i++) {
      seen.addAll(cubit.state.messages.map((message) => message.text));
      if (!cubit.state.hasOlder) break;
      await cubit.loadOlder();
      expect(cubit.state.messages.length, lessThanOrEqualTo(120));
    }
    expect(seen, hasLength(165));
    expect(cubit.state.messages.first.text, 'queued 1');
    expect(cubit.state.hasNewer, isTrue);
    for (var i = 0; i < 6 && cubit.state.hasNewer; i++) {
      await cubit.loadNewer();
      expect(cubit.state.messages.length, lessThanOrEqualTo(120));
    }
    expect(cubit.state.messages.last.text, 'queued 165');
    expect(cubit.state.atLiveEdge, isTrue);
    expect(await database.pendingOutbox('local|me'), hasLength(165));
  });

  test(
    'pagination crosses server history and pending queue without a gap',
    () async {
      gateway.seed(45);
      gateway.ready = true;
      await repository.ensureTopic('usrPeer');
      await repository.loadBefore('usrPeer', 46);
      await repository.loadBefore('usrPeer', 6, limit: 5);
      gateway.ready = false;
      await queue(135);
      await cubit.open('usrPeer');
      expect(cubit.state.atLiveEdge, isTrue);
      expect(cubit.state.hasNewer, isFalse);
      final seen = <String>{};
      for (var i = 0; i < 8; i++) {
        seen.addAll(cubit.state.messages.map((message) => message.text));
        if (!cubit.state.hasOlder) break;
        await cubit.loadOlder();
        expect(cubit.state.messages.length, lessThanOrEqualTo(120));
      }
      expect(seen, hasLength(180));
      expect(cubit.state.messages.first.seq, 1);
      for (var i = 0; i < 8 && cubit.state.hasNewer; i++) {
        await cubit.loadNewer();
        expect(cubit.state.messages.length, lessThanOrEqualTo(120));
      }
      expect(cubit.state.messages.last.text, 'queued 135');
      expect(cubit.state.atLiveEdge, isTrue);
      expect(gateway.publishes, 0);
    },
  );
}
