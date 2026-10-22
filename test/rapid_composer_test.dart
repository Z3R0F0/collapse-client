import 'dart:async';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/core/theme.dart';
import 'package:collapse/l10n/app_localizations.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:collapse/src/presentation/chat/chat_cubit.dart';
import 'package:collapse/src/presentation/chat/chat_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'support/fake_gateway.dart';

class _ComposerRepository extends ChatsRepository {
  _ComposerRepository(AppDatabase database, FakeGateway gateway)
    : super(database: database, gateway: gateway, serverId: 'local');
  String account = 'me';
  int generation = 0;
  final retried = <Object>[];
  final drafts = <String>[];
  @override
  String get currentUserId => account;
  @override
  int get sessionGeneration => generation;
  @override
  Future<ChatTopic?> getTopic(String id) async => ChatTopic(id: id, title: id);
  @override
  Future<void> updateDraft(String topicId, String text) async =>
      drafts.add(text);
  @override
  Future<void> send(
    String topicId,
    Object content, {
    Map<String, dynamic> head = const {},
    List<PendingUpload> uploads = const [],
    bool clearDraft = false,
  }) async {
    expect(
      clearDraft,
      isFalse,
      reason: 'retry never clears a replacement draft',
    );
    retried.add(content);
  }
}

class _ComposerCubit extends ChatCubit {
  _ComposerCubit(super.repository);
  final contents = <Object>[];
  final pending = <Completer<void>>[];
  @override
  Future<void> send(
    Object content, {
    Map<String, dynamic> head = const {},
    List<PendingUpload> uploads = const [],
    bool clearDraft = false,
  }) {
    expect(clearDraft, isTrue);
    contents.add(content);
    final commit = Completer<void>();
    pending.add(commit);
    return commit.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late FakeGateway gateway;
  late _ComposerRepository repository;
  late _ComposerCubit cubit;
  late GlobalKey<NavigatorState> navigator;
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (call) async => null,
        );
    database = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = FakeGateway();
    repository = _ComposerRepository(database, gateway);
    cubit = _ComposerCubit(repository);
    navigator = GlobalKey<NavigatorState>();
  });
  tearDown(() async {
    for (final pending in cubit.pending) {
      if (!pending.isCompleted) pending.complete();
    }
    await cubit.close();
    await repository.dispose();
    await gateway.dispose();
    await database.close();
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
  });
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      RepositoryProvider<ChatsRepository>.value(
        value: repository,
        child: BlocProvider<ChatCubit>.value(
          value: cubit,
          child: MaterialApp(
            navigatorKey: navigator,
            theme: appTheme(Brightness.light),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChatScreen(
              topicId: 'usrPeer',
              userId: 'me',
              title: 'Peer',
              onProfile: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String input(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;
  Future<void> submit(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    expect(
      input(tester),
      isEmpty,
      reason: 'capture/clear is synchronous, not commit-dependent',
    );
  }

  testWidgets(
    'web Enter preference leaves clearing with the send transaction',
    (tester) async {
      await mount(tester);
      final composer = tester.widget<ui.Composer>(find.byType(ui.Composer));
      expect(composer.sendOnEnter, kIsWeb);
      expect(composer.inputClearMode, ui.InputClearMode.never);
      expect(composer.textInputAction, TextInputAction.newline);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'keyboard submits capture and clear without waiting for commits',
    (tester) async {
      await mount(tester);
      for (var i = 1; i <= 3; i++) {
        await tester.enterText(find.byType(TextField), 'Keyboard $i');
        await tester.pump();
        // Native keeps the existing binding; real web Enter/Shift+Enter is also
        // covered by the browser acceptance test against the actual composer.
        if (!kIsWeb) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        if (!kIsWeb) {
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        }
        expect(input(tester), isEmpty);
        expect(cubit.contents.length, i);
      }
      expect(cubit.contents, [
        for (var i = 1; i <= 3; i++) {'txt': 'Keyboard $i'},
      ]);
      for (final pending in cubit.pending) {
        pending.complete();
      }
      await tester.pumpAndSettle();
      expect(input(tester), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    '20 submits remain independent while all local commits are pending',
    (tester) async {
      await mount(tester);
      for (var i = 1; i <= 20; i++) {
        await submit(tester, 'Rapid $i complete tail');
      }
      expect(cubit.contents, [
        for (var i = 1; i <= 20; i++) {'txt': 'Rapid $i complete tail'},
      ]);
      for (final pending in cubit.pending) {
        pending.complete();
      }
      await tester.pumpAndSettle();
      expect(input(tester), isEmpty);
      expect(
        repository.drafts,
        isEmpty,
        reason: 'no stale empty debounce write',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed local commit restores untouched composer without duplicate Retry action',
    (tester) async {
      await mount(tester);
      await submit(tester, 'Keep failed text');
      cubit.pending.single.completeError(StateError('Synthetic write failure'));
      await tester.pumpAndSettle();
      expect(input(tester), 'Keep failed text');
      expect(find.text('Retry'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed older send keeps new draft and Retry captures only failed payload',
    (tester) async {
      await mount(tester);
      await submit(tester, 'Failed first');
      await tester.enterText(find.byType(TextField), 'Newer draft');
      cubit.pending.single.completeError(StateError('Synthetic write failure'));
      await tester.pumpAndSettle();
      expect(input(tester), 'Newer draft');
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repository.retried, [
        {'txt': 'Failed first'},
      ]);
      expect(input(tester), 'Newer draft');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('failed intent remains retryable after its route is disposed', (
    tester,
  ) async {
    await mount(tester);
    await submit(tester, 'Failed after leaving');
    unawaited(
      navigator.currentState!.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Next route')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    cubit.pending.single.completeError(StateError('Synthetic write failure'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.retried, [
      {'txt': 'Failed after leaving'},
    ]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final sameAccount in [false, true]) {
    testWidgets(
      'late failure cannot restore into a ${sameAccount ? 'relogged' : 'different'} session',
      (tester) async {
        await mount(tester);
        await submit(tester, 'Old session intent');
        repository.account = sameAccount ? 'me' : 'other';
        repository.generation++;
        cubit.pending.single.completeError(
          StateError('Synthetic write failure'),
        );
        await tester.pumpAndSettle();
        expect(input(tester), isEmpty);
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(
          repository.retried,
          sameAccount
              ? [
                  {'txt': 'Old session intent'},
                ]
              : isEmpty,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
