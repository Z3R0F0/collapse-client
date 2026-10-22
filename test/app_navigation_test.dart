import 'package:collapse/src/presentation/chat/chat_screen.dart';
import 'package:collapse/src/presentation/navigation/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/router_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void navigationTest(
    String name,
    Future<void> Function(WidgetTester, RouterFixture) body, {
    String location = AppRoutes.contacts,
  }) {
    testWidgets(name, (tester) async {
      final fixture = (await tester.runAsync(() async => RouterFixture()))!;
      await tester.runAsync(() => fixture.initialize(location: location));
      try {
        await fixture.mount(tester);
        await body(tester, fixture);
      } finally {
        await fixture.dispose(tester);
      }
    });
  }

  Future<void> tab(
    WidgetTester tester,
    RouterFixture fixture,
    IconData icon,
  ) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(icon),
      ),
    );
    await fixture.pump(tester);
  }

  Future<void> back(WidgetTester tester, RouterFixture fixture) async {
    await tester.tap(
      find.descendant(
        of: find.byType(ChatScreen),
        matching: find.byType(BackButton),
      ),
    );
    await fixture.pump(tester);
  }

  navigationTest(
    'narrow Chats selection opens the list and drops a stale contact return hint',
    (tester, fixture) async {
      await tester.tap(find.byTooltip('Message'));
      await fixture.pump(tester);
      expect(fixture.uri.path, '/chats/usrPeer');
      final screen = tester.state(find.byType(ChatScreen));
      final chat = fixture.chats.single;
      final window = chat.state.window!.span;
      final composer = find.descendant(
        of: find.byType(ChatScreen),
        matching: find.byType(TextField),
      );
      await tester.enterText(composer, 'retained desktop draft');
      await fixture.pump(tester);

      await tab(tester, fixture, Icons.people_outline);
      tester.view.physicalSize = const Size(390, 900);
      await fixture.pump(tester);
      await tab(tester, fixture, Icons.person_outline);
      expect(fixture.chats, [chat]);
      expect(chat.opens, 1);
      expect(chat.state.window!.span, window);
      expect(
        tester.state(find.byType(ChatScreen, skipOffstage: false)),
        same(screen),
      );

      await tab(tester, fixture, Icons.chat_bubble_outline);
      expect(
        fixture.uri.path,
        AppRoutes.chats,
        reason: 'An explicit mobile tab selection must expose the chat list.',
      );
      expect(find.byType(ChatScreen), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('usrPeer')));
      await fixture.pump(tester);
      expect(fixture.uri.path, '/chats/usrPeer');
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'retained desktop draft',
      );
      await back(tester, fixture);
      expect(fixture.uri.path, AppRoutes.chats);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  navigationTest(
    'direct contact-profile start-chat still returns to its source',
    (tester, fixture) async {
      await tester.tap(find.text('Start chat'));
      await fixture.pump(tester);
      expect(fixture.uri.path, '/chats/usrPeer');
      await back(tester, fixture);
      expect(fixture.uri.path, '/contacts/usrPeer');
      expect(find.text('Start chat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    location: '/contacts/usrPeer',
  );

  navigationTest(
    'tapping the active Chats tab opens its canonical list',
    (tester, fixture) async {
      await tab(tester, fixture, Icons.chat_bubble_outline);
      expect(fixture.uri.path, AppRoutes.chats);
      expect(find.byType(ChatScreen), findsNothing);
      tester.view.physicalSize = const Size(390, 900);
      await fixture.pump(tester);
      expect(fixture.uri.path, AppRoutes.chats);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    location: '/chats/usrPeer',
  );
}
