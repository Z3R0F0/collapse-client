import 'package:collapse/src/data/auth/auth_repository.dart';
import 'package:collapse/src/presentation/chat/chat_screen.dart';
import 'package:collapse/src/presentation/chat/search/message_search_screen.dart';
import 'package:collapse/src/presentation/navigation/app_routes.dart';
import 'package:collapse_tinode/collapse_tinode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/link.dart';

import 'support/router_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void routerTest(
    String description,
    Future<void> Function(WidgetTester, RouterFixture) body, {
    String location = '/chats/usrPeer',
    bool signedIn = true,
    bool restoring = false,
  }) {
    testWidgets(description, (tester) async {
      final fixture = (await tester.runAsync(() async => RouterFixture()))!;
      await tester.runAsync(
        () => fixture.initialize(
          location: location,
          signedIn: signedIn,
          restoring: restoring,
        ),
      );
      try {
        await fixture.mount(tester);
        await body(tester, fixture);
      } finally {
        // Drain Drift's stream-cancel timers before testWidgets checks its
        // frame/clock invariants, not in the later package tearDown phase.
        await fixture.dispose(tester);
      }
    });
  }

  Finder input() => find.descendant(
    of: find.byType(ChatScreen),
    matching: find.byType(TextField),
  );

  Future<void> branch(
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

  routerTest(
    'cached session restore keeps the requested URL without a login detour',
    (tester, fixture) async {
      const destination = '/chats/usrPeer/search?q=Window';
      expect(fixture.uri.toString(), destination);
      expect(fixture.chats, isEmpty);
      expect(find.byType(ChatScreen), findsNothing);
      expect(find.byKey(const Key('auth-username')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      fixture.auth.show(const SessionState(SessionPhase.offline, userId: 'me'));
      await fixture.pump(tester);
      expect(fixture.uri.toString(), destination);
      expect(fixture.chats, hasLength(1));
      expect(fixture.searches, hasLength(1));
      expect(fixture.chats.single.state.messages, isNotEmpty);
      expect(
        fixture.locations.where((uri) => uri.path == AppRoutes.login),
        isEmpty,
        reason:
            'Local session restore must not insert a login URL into '
            'browser history before the cached account becomes available.',
      );
      expect(tester.takeException(), isNull);
    },
    location: '/chats/usrPeer/search?q=Window',
    restoring: true,
  );

  routerTest(
    'sign in and out replace auth history but ordinary navigation still pushes',
    (tester, fixture) async {
      final reports = <Map<Object?, Object?>>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.navigation, (
        call,
      ) async {
        if (call.method == 'routeInformationUpdated') {
          reports.add(Map<Object?, Object?>.from(call.arguments as Map));
        }
        return null;
      });
      try {
        fixture.auth.show(
          const SessionState(SessionPhase.offline, userId: 'me'),
        );
        await fixture.pump(tester);
        expect(fixture.uri.path, '/chats/usrPeer');
        expect(reports, isNotEmpty);
        expect(reports.last['replace'], isTrue, reason: '$reports');

        reports.clear();
        await branch(tester, fixture, Icons.people_outline);
        expect(fixture.uri.path, AppRoutes.contacts);
        expect(reports, isNotEmpty);
        expect(reports.last['replace'], isFalse, reason: '$reports');

        reports.clear();
        fixture.auth.show(const SessionState(SessionPhase.signedOut));
        await fixture.pump(tester);
        expect(fixture.uri.path, AppRoutes.login);
        expect(reports, isNotEmpty);
        expect(reports.last['replace'], isTrue, reason: '$reports');
        expect(find.byKey(const Key('auth-username')), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        messenger.setMockMethodCallHandler(SystemChannels.navigation, null);
      }
    },
    signedIn: false,
  );

  routerTest(
    'deep link goes through login then canonical conversation target',
    (tester, fixture) async {
      expect(fixture.uri.path, AppRoutes.login);
      expect(
        fixture.uri.queryParameters['from'],
        '/chats/usrPeer/info?member=usrOther',
      );
      expect(find.byKey(const Key('auth-username')), findsOneWidget);
      expect(fixture.chats, isEmpty);

      fixture.auth.show(const SessionState(SessionPhase.offline, userId: 'me'));
      await fixture.pump(tester);
      expect(fixture.uri.toString(), '/chats/usrPeer/info?member=usrOther');
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(fixture.chats, hasLength(1));
      expect(fixture.chats.single.state.messages, isNotEmpty);
      expect(tester.takeException(), isNull);
    },
    location: '/chats/usrPeer/info?member=usrOther&discard=yes',
    signedIn: false,
  );

  routerTest(
    'contacts search accepts a physical tap after leaving a focused chat',
    (tester, fixture) async {
      await tester.tap(input());
      await fixture.pump(tester);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: input(), matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );

      for (var attempt = 0; attempt < 2; attempt++) {
        await branch(tester, fixture, Icons.people_outline);
        final field = find.byKey(const Key('contact-search'));
        final editable = find.descendant(
          of: field,
          matching: find.byType(EditableText),
        );
        final node = tester.widget<EditableText>(editable).focusNode;
        expect(node.canRequestFocus, isTrue);
        expect(
          node.ancestors.where((ancestor) => !ancestor.descendantsAreFocusable),
          isEmpty,
          reason: node.ancestors.map((node) => node.toString()).join('\n'),
        );
        await tester.tap(field);
        await fixture.pump(tester);
        expect(
          node.hasFocus,
          isTrue,
          reason: FocusManager.instance.toStringDeep(),
        );
        expect(fixture.uri.path, AppRoutes.contacts);
        await branch(tester, fixture, Icons.chat_bubble_outline);
      }
      expect(tester.takeException(), isNull);
    },
  );

  routerTest(
    'contacts semantic focus survives route settling and keyboard insets',
    (tester, fixture) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.tap(input());
        await fixture.pump(tester);
        await branch(tester, fixture, Icons.people_outline);
        final editable = find.descendant(
          of: find.byKey(const Key('contact-search')),
          matching: find.byType(EditableText),
        );
        final node = tester.widget<EditableText>(editable).focusNode;
        final semanticNode = tester.getSemantics(editable);
        expect(
          semanticNode.getSemanticsData().hasAction(SemanticsAction.focus),
          isTrue,
        );
        tester
            .renderObject(editable)
            .owner!
            .semanticsOwner!
            .performAction(semanticNode.id, SemanticsAction.focus);
        await fixture.pump(tester);
        expect(
          node.hasFocus,
          isTrue,
          reason: FocusManager.instance.toStringDeep(),
        );
        for (final inset in [260.0, 0.0]) {
          tester.view.viewInsets = FakeViewPadding(bottom: inset);
          await fixture.pump(tester);
          expect(node.hasFocus, isTrue, reason: 'viewInsets.bottom=$inset');
          expect(tester.widget<EditableText>(editable).focusNode, same(node));
        }
        expect(fixture.uri.path, AppRoutes.contacts);
        expect(tester.takeException(), isNull);
      } finally {
        tester.view.resetViewInsets();
        semantics.dispose();
      }
    },
  );

  routerTest(
    'branch navigation preserves the retained conversation owner and draft',
    (tester, fixture) async {
      final screen = tester.state(find.byType(ChatScreen));
      final chat = fixture.chats.single;
      final span = chat.state.window!.span;
      await tester.enterText(input(), 'branch draft');
      await fixture.pump(tester);

      await branch(tester, fixture, Icons.people_outline);
      expect(fixture.uri.path, AppRoutes.contacts);
      expect(find.byType(ChatScreen), findsNothing);
      expect(
        tester.state(find.byType(ChatScreen, skipOffstage: false)),
        same(screen),
      );
      await branch(tester, fixture, Icons.person_outline);
      expect(fixture.uri.path, AppRoutes.profile);
      await branch(tester, fixture, Icons.chat_bubble_outline);
      expect(fixture.uri.path, '/chats/usrPeer');
      expect(fixture.chats, [chat]);
      expect(tester.state(find.byType(ChatScreen)), same(screen));
      expect(chat.state.window!.span, span);
      expect(
        tester.widget<TextField>(input()).controller!.text,
        'branch draft',
      );
      expect(tester.takeException(), isNull);
    },
  );

  routerTest('chat info and start-chat repeatedly reuse one actual ChatCubit', (
    tester,
    fixture,
  ) async {
    final screen = tester.state(find.byType(ChatScreen));
    final chat = fixture.chats.single;
    final epoch = chat.state.navigationEpoch;
    for (var i = 0; i < 3; i++) {
      await tester.tap(
        find.descendant(
          of: find.byType(ChatScreen),
          matching: find.text('Peer'),
        ),
      );
      await fixture.pump(tester);
      expect(fixture.uri.path, '/chats/usrPeer/info');
      await tester.tap(find.text('Start chat'));
      await fixture.pump(tester);
      expect(fixture.uri.path, '/chats/usrPeer');
      expect(fixture.chats, [chat]);
      expect(tester.state(find.byType(ChatScreen)), same(screen));
      expect(chat.state.navigationEpoch, epoch);
      expect(chat.opens, 1);
    }
    expect(tester.takeException(), isNull);
  });

  routerTest(
    'desktop-mobile resize keeps actual screen, Cubit, window and typed draft',
    (tester, fixture) async {
      final screen = tester.state(find.byType(ChatScreen));
      final chat = fixture.chats.single;
      final span = chat.state.window!.span;
      final ids = chat.state.messages.map((m) => m.id).toList();
      await tester.enterText(input(), 'unsent while resizing');
      await fixture.pump(tester);
      for (final width in [390.0, 839.0, 840.0, 1200.0]) {
        tester.view.physicalSize = Size(width, 900);
        await fixture.pump(tester);
        expect(tester.state(find.byType(ChatScreen)), same(screen));
        expect(fixture.chats, [chat]);
        expect(chat.opens, 1);
        expect(chat.state.window!.span, span);
        expect(chat.state.messages.map((m) => m.id), ids);
        expect(
          tester.widget<TextField>(input()).controller!.text,
          'unsent while resizing',
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  routerTest(
    'wide search selection retains panel, query and the actual conversation owner',
    (tester, fixture) async {
      final chat = fixture.chats.single;
      final screen = tester.state(find.byType(ChatScreen));
      final search = fixture.searches.single;
      final panel = tester.state(find.byType(MessageSearchScreen));
      final semantics = tester.ensureSemantics();
      try {
        for (var i = 0; i < 20 && search.state.busy; i++) {
          await fixture.pump(tester);
        }
        expect(search.state.error, isFalse);
        final hit = search.state.page!.hits.first;
        await tester.tap(
          find.descendant(
            of: find.byType(MessageSearchScreen),
            matching: find.byKey(ValueKey(hit.id)),
          ),
        );
        await fixture.pump(tester);
        expect(fixture.uri.path, '/chats/usrPeer/search');
        expect(fixture.uri.queryParameters, {
          'q': 'Message 15',
          'message': '${hit.seq}',
        });
        expect(fixture.chats, [chat]);
        expect(fixture.searches, [search]);
        expect(tester.state(find.byType(ChatScreen)), same(screen));
        expect(tester.state(find.byType(MessageSearchScreen)), same(panel));
        expect(chat.state.targetId, hit.id);
        expect(
          chat.state.messages.any((message) => message.id == hit.id),
          isTrue,
        );
        expect(chat.opens, 2);
        expect(search.state.query, 'Message 15');
        expect(
          tester
              .getSemantics(
                find.descendant(
                  of: find.byType(ChatScreen),
                  matching: find.byType(EditableText),
                ),
              )
              .getSemanticsData()
              .flagsCollection
              .isTextField,
          isTrue,
        );
        final sidebar = find.byWidgetPredicate(
          (widget) =>
              widget is Link && widget.uri == Uri.parse('/chats/usrPeer'),
        );
        expect(tester.getSemantics(sidebar).toStringDeep(), contains('Peer'));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
    location: '/chats/usrPeer/search?q=Message%2015',
  );

  routerTest('compact peer tile exposes an actionable accessible link', (
    tester,
    fixture,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      fixture.settings.setSidebarWidth(72);
      await fixture.pump(tester);
      final link = find.byWidgetPredicate(
        (widget) => widget is Link && widget.uri == Uri.parse('/chats/usrPeer'),
      );
      expect(link, findsOneWidget);
      final node = tester.getSemantics(link);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await fixture.pump(tester);
      expect(fixture.uri.path, '/chats/usrPeer');
      expect(fixture.chats, hasLength(1));
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  }, location: '/chats');

  routerTest(
    'hidden retained branch receives new messages but never marks them read',
    (tester, fixture) async {
      final chat = fixture.chats.single;
      await branch(tester, fixture, Icons.people_outline);
      fixture.gateway.ready = true;
      fixture.gateway.notes.clear();
      final received = fixture.repository
          .watchTopic('usrPeer')
          .firstWhere((t) => t?.recvSeq == 201);
      fixture.gateway.controller.add(
        const TinodeEvent('data', {
          'topic': 'usrPeer',
          'seq': 201,
          'from': 'peer',
          'content': 'while hidden',
        }),
      );
      await fixture.pump(tester);
      await tester.runAsync(() => received.timeout(const Duration(seconds: 3)));
      expect(
        fixture.gateway.notes.where((n) => n.what == 'recv' && n.seq == 201),
        hasLength(1),
      );
      expect(fixture.gateway.notes.where((n) => n.what == 'read'), isEmpty);
      final topic = await tester.runAsync(
        () => fixture.repository.getTopic('usrPeer'),
      );
      expect(topic!.readSeq, 200);
      expect(topic.unreadCount, 1);
      expect(fixture.chats, [chat]);
      expect(tester.takeException(), isNull);
    },
  );
}
