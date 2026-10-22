import 'dart:async';

import 'package:collapse/src/presentation/chat/chat_screen.dart';
import 'package:collapse/src/presentation/chat/search/message_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/router_fixture.dart';

void main() {
  void routerTest(
    String name,
    Future<void> Function(WidgetTester, RouterFixture) body, {
    String location = '/chats/usrPeer?message=5',
  }) => testWidgets(name, (tester) async {
    final fixture = (await tester.runAsync(() async => RouterFixture()))!;
    await tester.runAsync(() => fixture.initialize(location: location));
    try {
      await fixture.mount(tester, width: 1600);
      await body(tester, fixture);
    } finally {
      await fixture.dispose(tester);
    }
  });

  routerTest(
    'URL target removal and return each navigate once with one owner',
    (tester, fixture) async {
      final chat = fixture.chats.single;
      final screen = tester.state(find.byType(ChatScreen));
      expect(chat.state.targetId, 'usrPeer:5');
      expect(chat.opens, 1);
      fixture.navigation.router.go('/chats/usrPeer');
      await fixture.pump(tester);
      expect(chat.state.targetId, isNull);
      expect(chat.state.messages.last.seq, 200);
      expect(chat.opens, 2);
      fixture.navigation.router.go('/chats/usrPeer?message=5');
      await fixture.pump(tester);
      expect(chat.state.targetId, 'usrPeer:5');
      expect(chat.opens, 3);
      expect(fixture.chats, [chat]);
      expect(tester.state(find.byType(ChatScreen)), same(screen));
      await fixture.pump(tester);
      expect(chat.opens, 3);
      expect(tester.takeException(), isNull);
    },
  );

  routerTest('Latest clears the URL without a duplicate open', (
    tester,
    fixture,
  ) async {
    final chat = fixture.chats.single;
    await tester.tap(find.byKey(const ValueKey('latest-messages')));
    await fixture.pump(tester);
    expect(fixture.uri.toString(), '/chats/usrPeer');
    expect(chat.state.targetId, isNull);
    expect(chat.state.messages.last.seq, 200);
    expect(chat.opens, 2);
    await fixture.pump(tester);
    expect(chat.opens, 2);
    expect(tester.takeException(), isNull);
  });

  routerTest('send from a URL target clears it without a duplicate open', (
    tester,
    fixture,
  ) async {
    final chat = fixture.chats.single;
    await tester.runAsync(() => chat.send('sent from history'));
    await fixture.pump(tester);
    expect(fixture.uri.toString(), '/chats/usrPeer');
    expect(chat.state.targetId, isNull);
    expect(chat.state.messages.last.text, 'sent from history');
    expect(chat.opens, 2);
    await fixture.pump(tester);
    expect(chat.opens, 2);
    expect(tester.takeException(), isNull);
  });

  routerTest(
    'editing search preserves its independent message target',
    (tester, fixture) async {
      final chat = fixture.chats.single;
      final screen = tester.state(find.byType(ChatScreen));
      await tester.enterText(
        find.descendant(
          of: find.byType(MessageSearchScreen),
          matching: find.byType(TextField),
        ),
        'updated query',
      );
      await fixture.pump(tester);
      expect(fixture.uri.queryParameters['q'], 'updated query');
      expect(fixture.uri.queryParameters['message'], '5');
      expect(chat.state.targetId, 'usrPeer:5');
      expect(chat.opens, 1);
      expect(tester.state(find.byType(ChatScreen)), same(screen));
      expect(tester.takeException(), isNull);
    },
    location: '/chats/usrPeer/search?q=Message&message=5',
  );

  routerTest(
    'native explicit Back returns to the contact which opened the chat',
    (tester, fixture) async {
      await tester.tap(find.text('Start chat'));
      await fixture.pump(tester);
      expect(fixture.uri.path, '/chats/usrPeer');
      await tester.tap(
        find.descendant(
          of: find.byType(ChatScreen),
          matching: find.byType(BackButton),
        ),
      );
      await fixture.pump(tester);
      expect(fixture.uri.path, '/contacts/usrPeer');
      expect(find.text('Start chat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    location: '/contacts/usrPeer',
  );

  routerTest(
    'Back invalidates an unfinished target read without a stale error',
    (tester, fixture) async {
      final chat = fixture.chats.single;
      late Completer<void> entered, release;
      late Future<void> locked;
      await tester.runAsync(() async {
        entered = Completer<void>();
        release = Completer<void>();
        locked = fixture.db.transaction(() async {
          entered.complete();
          await release.future;
        });
        await entered.future;
      });
      try {
        fixture.navigation.router.go('/chats/usrPeer?message=5');
        await fixture.pump(tester);
        expect(chat.state.loading, isTrue);
        fixture.navigation.router.go('/chats/usrPeer');
        await fixture.pump(tester);
      } finally {
        await tester.runAsync(() async {
          release.complete();
          await locked;
        });
      }
      await fixture.pump(tester);
      expect(chat.state.targetId, isNull);
      expect(chat.state.messages.last.seq, 200);
      expect(chat.opens, 3);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
    location: '/chats/usrPeer',
  );

  routerTest(
    'missing cold URL target is not an empty chat and Retry opens latest',
    (tester, fixture) async {
      final chat = fixture.chats.single;
      expect(chat.state.loading, isFalse);
      expect(chat.state.error, 'message_unavailable');
      expect(find.text('Say hello'), findsNothing);
      expect(find.text('This message is unavailable.'), findsOneWidget);
      expect(chat.opens, 1);
      await tester.tap(find.text('Retry'));
      await fixture.pump(tester);
      expect(fixture.uri.toString(), '/chats/usrPeer');
      expect(chat.state.error, isNull);
      expect(chat.state.messages.last.seq, 200);
      expect(chat.opens, 2);
      expect(find.text('Say hello'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    location: '/chats/usrPeer?local=missing',
  );

  routerTest(
    'send during a held target read ends at latest without a stale error',
    (tester, fixture) async {
      final chat = fixture.chats.single;
      late Completer<void> entered, release;
      late Future<void> locked, sent;
      await tester.runAsync(() async {
        entered = Completer<void>();
        release = Completer<void>();
        locked = fixture.db.transaction(() async {
          entered.complete();
          await release.future;
        });
        await entered.future;
      });
      try {
        fixture.navigation.router.go('/chats/usrPeer?message=5');
        await fixture.pump(tester);
        expect(chat.state.loading, isTrue);
        await tester.runAsync(() async {
          sent = chat.send('sent during target read');
        });
      } finally {
        await tester.runAsync(() async {
          release.complete();
          await locked;
        });
      }
      await fixture.pump(tester);
      await tester.runAsync(() => sent.timeout(const Duration(seconds: 3)));
      await fixture.pump(tester);
      expect(fixture.uri.toString(), '/chats/usrPeer');
      expect(chat.state.targetId, isNull);
      expect(chat.state.messages.last.text, 'sent during target read');
      expect(chat.opens, 3);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
    location: '/chats/usrPeer',
  );
}
