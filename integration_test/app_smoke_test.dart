import 'dart:convert';
import 'dart:io';

import 'package:collapse/core/config.dart';
import 'package:collapse/dependency_injection.dart';
import 'package:collapse/main.dart' as app;
import 'package:collapse/src/data/auth/auth_repository.dart';
import 'package:collapse/src/data/auth/session_store.dart';
import 'package:collapse/src/presentation/app/settings_cubit.dart';
import 'package:collapse_tinode/tinode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Run only on an isolated simulator/emulator with the local development server.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native registration, keychain, tabs and session restore', (
    tester,
  ) async {
    final config = AppConfig.environment();
    expect(config.endpoint.host, isIn(['127.0.0.1', '10.0.2.2']));
    expect(config.endpoint.scheme, 'ws');
    await app.main();
    final auth = locator<AuthRepository>();
    await auth.restore();
    // A platform storage error must not be hidden behind a rendered login page.
    expect(auth.state.error, isNull);
    expect(
      auth.state.authenticated,
      isFalse,
      reason: 'Use a fresh test installation; never sign out an existing user.',
    );
    await locator<SettingsCubit>().setLocale('en');
    await tester.pumpAndSettle();

    final suffix = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final username = 'native$suffix';
    final password = 'test-$suffix-1234';
    String? user;
    String? token;
    addTearDown(() async {
      await auth.signOut();
      await locator.reset();
      if (user != null && token != null) {
        await _deleteFixture(config, user, token);
      }
    });

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auth-username')), username);
    await tester.enterText(find.byKey(const Key('auth-password')), password);
    await tester.enterText(find.byKey(const Key('auth-name')), 'Native smoke');
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await _until(
      tester,
      () => auth.state.authenticated || auth.state.error != null,
    );
    expect(auth.state.error, isNull);
    expect(auth.state.phase, SessionPhase.online);
    final gateway = locator<TinodeGateway>();
    user = gateway.userId;
    token = gateway.token;
    final saved = await locator<SessionStore>().read();
    expect(saved?.userId, user);
    expect(saved?.token, isNotEmpty);

    for (final label in ['Contacts', 'Profile', 'Chats']) {
      await tester.tap(find.widgetWithText(NavigationDestination, label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    // Exercise the actual native secure-storage token path, not a mocked vault.
    await gateway.disconnect();
    await auth.restore();
    await _until(tester, () => auth.state.phase == SessionPhase.online);
    expect(auth.state.userId, user);
    expect(auth.state.error, isNull);
    token = gateway.token;
    await auth.signOut();
    await tester.pumpAndSettle();
    expect(await locator<SessionStore>().read(), isNull);
    expect(find.byKey(const Key('auth-submit')), findsOneWidget);
  });
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Native app did not reach the expected state.');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

Future<void> _deleteFixture(AppConfig config, String user, String token) async {
  final socket = await WebSocket.connect(
    config.endpoint
        .replace(queryParameters: {'apikey': config.apiKey})
        .toString(),
  );
  final packets = socket
      .map((data) => jsonDecode(data as String) as Map)
      .asBroadcastStream();
  var counter = 0;
  Future<void> request(String kind, Map<String, dynamic> body) async {
    final id = '${++counter}';
    final response = packets
        .firstWhere((packet) => (packet['ctrl'] as Map?)?['id'] == id)
        .timeout(const Duration(seconds: 10));
    socket.add(
      jsonEncode({
        kind: {...body, 'id': id},
      }),
    );
    expect((await response)['ctrl']['code'] as int, lessThan(400));
  }

  try {
    await request('hi', {'ver': '0.25.3', 'ua': 'collapse-native-test'});
    await request('login', {'scheme': 'token', 'secret': token});
    await request('del', {'what': 'user', 'user': user, 'hard': true});
  } finally {
    await socket.close();
  }
}
