import 'dart:async';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/core/theme.dart';
import 'package:collapse/l10n/app_localizations.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:collapse/src/presentation/chat/chat_cubit.dart';
import 'package:collapse/src/presentation/chat/chat_screen.dart';
import 'package:collapse/src/presentation/chat/drafty_content.dart';
import 'package:collapse/src/presentation/chat/message_arrival.dart';
import 'package:collapse/src/presentation/chat/message_list.dart';
import 'package:collapse_tinode/collapse_tinode.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as ui;
import 'package:flutter_list_view/flutter_list_view.dart' as anchored;
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _ScreenRepository extends ChatsRepository {
  _ScreenRepository(AppDatabase database, TinodeGateway gateway)
    : super(database: database, gateway: gateway, serverId: 'widget-test');

  Future<ChatTopic?>? topicResult;
  Future<void>? draftSaveResult;
  final savedDrafts = <String>[];
  String account = 'me';
  int generation = 0;
  @override
  String get currentUserId => account;
  @override
  int get sessionGeneration => generation;

  @override
  Future<ChatTopic?> getTopic(String id) async =>
      topicResult ??
      Future.value(
        ChatTopic(id: id, title: 'Chat', serverSeq: 500, readSeq: 0),
      );

  @override
  Future<void> updateDraft(String topicId, String text) async {
    savedDrafts.add(text);
    await draftSaveResult;
  }

  @override
  Future<void> clearDraftIfMatches(
    String topicId,
    String expected, {
    required String userId,
    required int sessionGeneration,
  }) async {
    if (account == userId &&
        generation == sessionGeneration &&
        (savedDrafts.lastOrNull ?? '') == expected) {
      savedDrafts.add('');
    }
  }
}

class _ScreenCubit extends ChatCubit {
  _ScreenCubit(super.repository);
  void showLoading() => emit(const ChatState(loading: true));
  final reads = <int>[];
  final sent = <Object>[];
  final following = <bool>[];
  int? jumpedTo;
  int olderRequests = 0;
  int newerRequests = 0;
  int latestRequests = 0;
  Future<void> Function()? olderAction;
  Future<void>? sendResult;
  Future<void> Function(int?)? openAction;

  void show(
    List<ChatMessage> messages, {
    bool live = false,
    bool hasOlder = true,
    bool hasNewer = true,
    int unreadCount = 0,
    Set<String> arrivalIds = const {},
    bool loadingOlder = false,
    bool loadingNewer = false,
    String? rebaseAnchorId,
  }) => emit(
    ChatState(
      window: HistoryWindow(
        List.unmodifiable(messages),
        span: HistorySpan(
          server: SequenceRange(
            messages.where((message) => message.seq > 0).firstOrNull?.seq ?? 1,
            (messages.where((message) => message.seq > 0).lastOrNull?.seq ??
                    0) +
                1,
          ),
        ),
        older: HistoryEdge(
          hasOlder
              ? HistoryAvailability.available
              : HistoryAvailability.exhausted,
        ),
        newer: HistoryEdge(
          live || !hasNewer
              ? HistoryAvailability.exhausted
              : HistoryAvailability.available,
        ),
        rebaseAnchorId: rebaseAnchorId,
      ),
      unreadCount: unreadCount,
      revision: state.revision + 1,
      arrivalIds: arrivalIds,
      paging: loadingOlder
          ? HistoryDirection.older
          : loadingNewer
          ? HistoryDirection.newer
          : null,
      navigationEpoch: state.navigationEpoch,
      targetId: state.targetId,
    ),
  );

  @override
  void setFollowingLive(bool value) {
    following.add(value);
    super.setFollowingLive(value);
  }

  @override
  Future<void> loadOlder() async {
    olderRequests++;
    await olderAction?.call();
  }

  @override
  Future<void> loadNewer() async {
    newerRequests++;
  }

  @override
  Future<void> markVisible(int seq) async {
    reads.add(seq);
  }

  @override
  Future<void> send(
    Object content, {
    Map<String, dynamic> head = const {},
    List<PendingUpload> uploads = const [],
    bool clearDraft = false,
  }) async {
    final source = repository as _ScreenRepository;
    final userId = source.currentUserId;
    final generation = source.sessionGeneration;
    final draft = source.savedDrafts.lastOrNull ?? '';
    sent.add(content);
    await sendResult;
    if (clearDraft) {
      // Model the repository's conditional local commit, not network delivery.
      // Real FIFO and transaction behavior is tested in local_enqueue_test.
      await source.clearDraftIfMatches(
        'usrPeer',
        draft,
        userId: userId,
        sessionGeneration: generation,
      );
    }
  }

  @override
  Future<void> open(String topicId, {int? aroundSeq, String? aroundId}) async {
    jumpedTo = aroundSeq;
    await openAction?.call(aroundSeq);
    final target = state.messages
        .where(
          (message) => aroundId != null
              ? message.id == aroundId
              : message.seq == aroundSeq,
        )
        .firstOrNull;
    emit(
      ChatState(
        window: state.window,
        revision: state.revision + 1,
        navigationEpoch: state.navigationEpoch + 1,
        targetId: target?.id,
      ),
    );
  }

  @override
  Future<void> jumpToLatest() async {
    latestRequests++;
    await open('usrPeer');
  }
}

List<ChatMessage> _messages(
  int first,
  int count, {
  bool reply = false,
}) => List.generate(count, (index) {
  final seq = first + index;
  // Deliberately different text extents and day/timestamp group boundaries.
  final lines = 1 + seq % 6;
  return ChatMessage(
    id: 'message-$seq',
    topicId: 'usrPeer',
    seq: seq,
    localSeq: 0,
    senderId: 'peer',
    createdAt: DateTime(2026, 1, 1).add(Duration(hours: seq * 2)),
    content: {
      'txt':
          'Message $seq\n${List.filled(lines, 'Variable-height message body').join('\n')}',
    },
    head: reply && index == count - 1 ? {'reply': 7} : const {},
  );
});

Finder _bubble(String id) => find.byWidgetPredicate(
  (widget) => widget is ui.ChatMessage && widget.message.id == id,
  skipOffstage: false,
);

Finder _arrival(String id) => find.descendant(
  of: _bubble(id),
  matching: find.byType(MessageArrival, skipOffstage: false),
  skipOffstage: false,
);

(String, double) _firstVisible(WidgetTester tester) {
  final viewport = tester.getRect(find.byType(ui.Chat));
  for (final element
      in find.byType(ui.ChatMessage, skipOffstage: false).evaluate()) {
    final widget = element.widget as ui.ChatMessage;
    final finder = _bubble(widget.message.id);
    final rect = tester.getRect(finder);
    if (rect.bottom > viewport.top + 1 && rect.top < viewport.bottom - 100) {
      return (widget.message.id, rect.top - viewport.top);
    }
  }
  throw StateError('No visible message');
}

int _visibleReadBound(WidgetTester tester) {
  final viewport = tester.getRect(find.byType(ui.Chat));
  final composerTop = tester.getRect(find.byType(ui.Composer)).top;
  var result = 0;
  for (final element
      in find.byType(ui.ChatMessage, skipOffstage: false).evaluate()) {
    final widget = element.widget as ui.ChatMessage;
    final rect = tester.getRect(_bubble(widget.message.id));
    final bottom = rect.bottom < composerTop ? rect.bottom : composerTop;
    final top = rect.top > viewport.top ? rect.top : viewport.top;
    final visible = bottom - top;
    if (visible > rect.height * .5 || visible > 120) {
      final seq = int.parse(widget.message.id.substring('message-'.length));
      if (seq > result) result = seq;
    }
  }
  return result;
}

Future<void> _settleFrames(WidgetTester tester) async {
  // endOfFrame-based controller updates need separate frame/microtask turns.
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late TinodeGateway gateway;
  late _ScreenRepository repository;
  late _ScreenCubit cubit;

  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (call) async => null,
        );
    database = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = TinodeGateway(
      endpoint: Uri.parse('http://localhost:6060'),
      apiKey: 'test',
    );
    repository = _ScreenRepository(database, gateway);
    cubit = _ScreenCubit(repository);
  });

  tearDown(() async {
    await cubit.close();
    await repository.dispose();
    await gateway.dispose();
    await database.close();
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
  });

  Future<void> mount(
    WidgetTester tester, {
    String topicId = 'usrPeer',
    double width = 600,
    double scale = 1,
    String locale = 'en',
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepositoryProvider<ChatsRepository>.value(
        value: repository,
        child: BlocProvider<ChatCubit>.value(
          value: cubit,
          child: MaterialApp(
            theme: appTheme(Brightness.light),
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: ChatScreen(
              topicId: topicId,
              userId: 'me',
              title: 'Chat',
              onProfile: () {},
            ),
          ),
        ),
      ),
    );
    await _settleFrames(tester);
  }

  testWidgets('initial loading never shows the empty conversation invitation', (
    tester,
  ) async {
    cubit.showLoading();
    await mount(tester);
    expect(find.text('Say hello'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    cubit.show(_messages(1, 1), live: true, hasOlder: false, hasNewer: false);
    await _settleFrames(tester);
    expect(_bubble('message-1'), findsOneWidget);
    expect(find.text('Say hello'), findsNothing);
    cubit.show([], live: true, hasOlder: false, hasNewer: false);
    await _settleFrames(tester);
    expect(find.text('Say hello'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('preloaded Cubit state appears on first mount', (tester) async {
    cubit.show(_messages(1, 120), live: true, hasNewer: false);
    await mount(tester);
    expect(find.byType(ui.ChatMessage, skipOffstage: false), findsWidgets);
    expect(_bubble('message-120'), findsOneWidget);
    expect(cubit.reads, isNotEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'prepending preserves first-row height when it becomes interior',
    (tester) async {
      cubit.show(_messages(561, 40));
      await mount(tester);
      final list = tester.widget<MessageList>(find.byType(MessageList));
      list.controller.sliverController.jumpToIndex(0);
      await tester.pumpAndSettle();
      final before = tester.getRect(_bubble('message-561'));
      final neighborTop = tester.getTopLeft(_bubble('message-562')).dy;
      cubit.show(_messages(521, 80));
      await tester.pumpAndSettle();
      final after = tester.getRect(_bubble('message-561'));
      expect(after.height, before.height);
      expect(after.top, closeTo(before.top, .5));
      expect(
        tester.getTopLeft(_bubble('message-562')).dy,
        closeTo(neighborTop, .5),
      );
      expect(cubit.olderRequests + cubit.newerRequests, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('coalesced rebase metadata preserves the painted anchor', (
    tester,
  ) async {
    cubit.show(_messages(1, 120), live: true);
    await mount(tester);
    expect(cubit.following.last, isTrue);
    final before = _firstVisible(tester);
    final replacement = _messages(81, 120);
    cubit.show(replacement, rebaseAnchorId: before.$1);
    cubit.show(replacement); // ACK/receipt refresh before the next UI frame.
    await tester.pumpAndSettle();
    final after = _firstVisible(tester);
    expect(after.$1, before.$1);
    expect(after.$2, closeTo(before.$2, 2));
    expect(cubit.latestRequests + cubit.olderRequests + cubit.newerRequests, 0);

    cubit.openAction = (_) async => cubit.show(replacement, live: true);
    await cubit.jumpToLatest();
    await tester.pumpAndSettle();
    expect(cubit.following.last, isTrue);
    cubit.show(_messages(82, 120), live: true);
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(_bubble('message-201')).dy,
      closeTo(tester.getTopLeft(find.byType(ui.Composer)).dy, 2),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('a coalesced live burst cannot retain an evicted rebase marker', (
    tester,
  ) async {
    cubit.show(_messages(1, 120), live: true);
    await mount(tester);
    final anchor = _firstVisible(tester).$1;
    cubit.show(_messages(81, 120), rebaseAnchorId: anchor);
    cubit.show(_messages(203, 120), live: true);
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(_bubble('message-322')).dy,
      closeTo(tester.getTopLeft(find.byType(ui.Composer)).dy, 2),
    );
    expect(
      tester.widget<MessageList>(find.byType(MessageList)).rebaseAnchorId,
      isNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('explicit latest invalidates an unpainted rebase marker', (
    tester,
  ) async {
    cubit.show(_messages(1, 120), live: true);
    await mount(tester);
    final anchor = _firstVisible(tester).$1;
    final replacement = _messages(81, 120);
    cubit.show(replacement, rebaseAnchorId: anchor);
    cubit.show(replacement);
    cubit.openAction = (_) async => cubit.show(replacement, live: true);
    await cubit.jumpToLatest();
    await tester.pumpAndSettle();
    expect(cubit.following.last, isTrue);
    expect(
      tester.getBottomLeft(_bubble('message-200')).dy,
      closeTo(tester.getTopLeft(find.byType(ui.Composer)).dy, 2),
    );
    expect(
      tester.widget<MessageList>(find.byType(MessageList)).rebaseAnchorId,
      isNull,
    );
    expect(cubit.olderRequests + cubit.newerRequests, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('composer sends canonical Markdown and clears the input', (
    tester,
  ) async {
    cubit.show([], live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    await tester.enterText(find.byType(TextField), '**bold** and _italic_');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(cubit.sent, [
      {
        'txt': 'bold and italic',
        'fmt': [
          {'at': 0, 'len': 4, 'tp': 'ST'},
          {'at': 9, 'len': 6, 'tp': 'EM'},
        ],
      },
    ]);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('narrow large-text reply and composer keep usable layout', (
    tester,
  ) async {
    cubit.show(
      _messages(1, 2, reply: true),
      live: true,
      hasOlder: false,
      hasNewer: false,
    );
    await mount(tester, width: 360, scale: 2, locale: 'ru');
    await tester.enterText(find.byType(TextField), 'Сообщение');
    await tester.pumpAndSettle();
    final send = find.ancestor(
      of: find.byIcon(Icons.send),
      matching: find.byType(IconButton),
    );
    expect(tester.getSize(send).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('a late saved draft cannot overwrite text already being typed', (
    tester,
  ) async {
    final topic = Completer<ChatTopic?>();
    repository.topicResult = topic.future;
    cubit.show([], live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'New typed draft');
    topic.complete(
      const ChatTopic(id: 'usrPeer', title: 'Chat', draft: 'Old saved draft'),
    );
    await _settleFrames(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'New typed draft',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('finishing a queued send cannot erase the next draft', (
    tester,
  ) async {
    final queued = Completer<void>();
    cubit.sendResult = queued.future;
    cubit.show([], live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'First message');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    await tester.enterText(find.byType(TextField), 'Next draft');
    queued.complete();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Next draft',
    );
    expect(repository.savedDrafts.last, 'Next draft');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'enqueue failure restores unchanged input without duplicate send',
    (tester) async {
      final queued = Completer<void>();
      cubit.sendResult = queued.future;
      cubit.show([], live: true, hasOlder: false, hasNewer: false);
      await mount(tester);
      await tester.enterText(find.byType(TextField), 'Keep this text');
      await tester.pump();
      final send = tester.widget<ui.Chat>(find.byType(ui.Chat)).onMessageSend!;
      send('Keep this text');
      send('Keep this text');
      await tester.pump();
      expect(cubit.sent, hasLength(1));
      expect(
        tester.widget<ui.Composer>(find.byType(ui.Composer)).sendButtonDisabled,
        isFalse,
      );
      queued.completeError(StateError('Synthetic enqueue failure'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Keep this text',
      );
      expect(
        tester.widget<ui.Composer>(find.byType(ui.Composer)).sendButtonDisabled,
        isFalse,
      );
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('a second distinct submit is accepted before the first commits', (
    tester,
  ) async {
    final queued = Completer<void>();
    cubit.sendResult = queued.future;
    cubit.show([], live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    for (final text in ['First', 'Second']) {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
    }
    expect(cubit.sent, [
      DraftyCodec.markdown('First'),
      DraftyCodec.markdown('Second'),
    ]);
    queued.complete();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('successful enqueue clears the submitted draft after leaving', (
    tester,
  ) async {
    final queued = Completer<void>();
    cubit.sendResult = queued.future;
    cubit.show([], live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'Sent while leaving');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(cubit.sent, [DraftyCodec.markdown('Sent while leaving')]);
    expect(repository.savedDrafts, isEmpty);
    queued.complete();
    await tester.pump();
    expect(repository.savedDrafts.last, '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing then cancelling reply prevents failed intent restore', (
    tester,
  ) async {
    final queued = Completer<void>();
    cubit.sendResult = queued.future;
    cubit.show(_messages(1, 1), live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'Failed old intent');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.longPress(_bubble('message-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    queued.completeError(StateError('Synthetic enqueue failure'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('quick send replaces and clears an older saved draft', (
    tester,
  ) async {
    repository.savedDrafts.add('Older draft');
    repository.topicResult = Future.value(
      const ChatTopic(id: 'usrPeer', title: 'Chat', draft: 'Older draft'),
    );
    cubit.show([], live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'Quick new message');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(repository.savedDrafts.last, '');
    expect(cubit.sent, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('submit captures before a delayed draft save or route disposal', (
    tester,
  ) async {
    cubit.show([], live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    final saved = Completer<void>();
    repository.draftSaveResult = saved.future;
    await tester.enterText(find.byType(TextField), 'Accepted text');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byIcon(Icons.send));
    expect(cubit.sent, [DraftyCodec.markdown('Accepted text')]);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    saved.complete();
    await tester.pump();
    expect(cubit.sent, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed enqueue after disposing the whole app is safe', (
    tester,
  ) async {
    final queued = Completer<void>();
    cubit.sendResult = queued.future;
    cubit.show([], live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'Retry after leaving');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpWidget(const SizedBox.shrink());
    queued.completeError(StateError('Synthetic enqueue failure'));
    await tester.pump();
    expect(cubit.sent, [DraftyCodec.markdown('Retry after leaving')]);
    expect(repository.savedDrafts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late send cannot clear the replacement route draft', (
    tester,
  ) async {
    final queued = Completer<void>();
    cubit.sendResult = queued.future;
    cubit.show([], live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'Old submitted text');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpWidget(const SizedBox.shrink());
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'Replacement route draft');
    await tester.pump(const Duration(milliseconds: 400));
    queued.complete();
    await tester.pump();
    expect(repository.savedDrafts.last, 'Replacement route draft');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Replacement route draft',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('covered sender never schedules an unconditional empty save', (
    tester,
  ) async {
    final queued = Completer<void>();
    cubit.sendResult = queued.future;
    cubit.show([], live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'Old submitted text');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    unawaited(
      Navigator.of(
        tester.element(find.byType(ChatScreen)),
      ).push(MaterialPageRoute<void>(builder: (_) => const Scaffold())),
    );
    await tester.pumpAndSettle();
    await repository.updateDraft('usrPeer', 'New route draft');
    queued.complete();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    expect(repository.savedDrafts.last, 'New route draft');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final relogin in [false, true]) {
    testWidgets(
      'late send preserves the ${relogin ? 'relogged-in' : 'other'} account draft',
      (tester) async {
        final queued = Completer<void>();
        cubit.sendResult = queued.future;
        cubit.show([], live: true, hasOlder: false, hasNewer: false);
        await mount(tester);
        await tester.enterText(find.byType(TextField), 'Same draft text');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpWidget(const SizedBox.shrink());
        repository.account = relogin ? 'me' : 'another-account';
        repository.generation++;
        await repository.updateDraft('usrPeer', 'Same draft text');
        queued.complete();
        await tester.pump();
        expect(repository.savedDrafts.last, 'Same draft text');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('focus alone does not prevent restoring a saved draft', (
    tester,
  ) async {
    final topic = Completer<ChatTopic?>();
    repository.topicResult = topic.future;
    cubit.show([], live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    final input = tester.widget<TextField>(find.byType(TextField)).controller!;
    input.selection = const TextSelection.collapsed(offset: 0);
    topic.complete(
      const ChatTopic(id: 'usrPeer', title: 'Chat', draft: 'Saved draft'),
    );
    await _settleFrames(tester);
    expect(input.text, 'Saved draft');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('restoring a draft cannot re-save it after send cleanup', (
    tester,
  ) async {
    final topic = Completer<ChatTopic?>();
    repository.topicResult = topic.future;
    repository.savedDrafts.add('Submitted draft');
    cubit.show([], live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    topic.complete(
      const ChatTopic(id: 'usrPeer', title: 'Chat', draft: 'Submitted draft'),
    );
    await tester.pump();
    await repository.clearDraftIfMatches(
      'usrPeer',
      'Submitted draft',
      userId: 'me',
      sessionGeneration: repository.sessionGeneration,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(repository.savedDrafts.last, '');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('leaving before draft debounce flushes only the same account', (
    tester,
  ) async {
    cubit.show([], live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'Fast departure');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(repository.savedDrafts.last, 'Fast departure');
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'Do not leak');
    repository.account = 'another-account';
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(repository.savedDrafts, isNot(contains('Do not leak')));
  });

  testWidgets('background flushes pending draft without waiting for timer', (
    tester,
  ) async {
    cubit.show([], live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'Before background');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(repository.savedDrafts.last, 'Before background');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  for (final restoring in [false, true]) {
    testWidgets(
      'old session cannot ${restoring ? 'restore' : 'save'} a draft after same-account relogin',
      (tester) async {
        final topic = Completer<ChatTopic?>();
        if (restoring) repository.topicResult = topic.future;
        cubit.show([], live: true, hasOlder: false, hasNewer: false);
        await mount(tester);
        if (!restoring) {
          await tester.enterText(find.byType(TextField), 'Old session draft');
        }
        repository.generation++;
        if (restoring) {
          topic.complete(
            const ChatTopic(
              id: 'usrPeer',
              title: 'Chat',
              draft: 'Old session draft',
            ),
          );
        }
        await tester.pump(const Duration(milliseconds: 500));
        expect(repository.savedDrafts, isEmpty);
        if (restoring) {
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            '',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(repository.savedDrafts, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a picker completing after chat disposal remains safe', (
    tester,
  ) async {
    const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
    final result = Completer<List<Map<String, Object>>>();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var requested = false;
    messenger.setMockMethodCallHandler(channel, (call) {
      requested = true;
      expect(call.arguments['withData'], isFalse);
      return result.future;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    cubit.show([], live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();
    expect(requested, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    result.complete([
      {
        'name': 'gone.mp4',
        'path': '/nonexistent/collapse-picker-test/gone.mp4',
        'size': 100,
      },
    ]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('oversized selection shows the limit before opening the file', (
    tester,
  ) async {
    const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.arguments['withData'], isFalse);
      return [
        {
          'name': 'huge.mp4',
          'path': '/nonexistent/collapse-picker-test/huge.mp4',
          'size': 20 * 1024 * 1024,
        },
      ];
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    cubit.show([], live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();
    // Opening this deliberately absent file would instead show operationError.
    expect(
      find.text('The attachment exceeds the 10 MB limit.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'same message ID refreshes queued to sent to read and uploaded media ref',
    (tester) async {
      ChatMessage attachment(Delivery delivery, {String ref = ''}) =>
          ChatMessage(
            id: 'stable-upload',
            topicId: 'usrPeer',
            seq: delivery == Delivery.queued ? -10 : 1,
            localSeq: 10,
            senderId: 'me',
            createdAt: DateTime(2026),
            delivery: delivery,
            content: {
              'txt': 'Document',
              'ent': [
                {
                  'tp': 'EX',
                  'data': {'name': 'document.bin', 'ref': ref},
                },
              ],
            },
          );
      cubit.show(
        [attachment(Delivery.queued)],
        live: true,
        hasNewer: false,
        hasOlder: false,
      );
      await mount(tester);
      expect(find.byTooltip('Queued', skipOffstage: false), findsOneWidget);
      final bubbleKey = tester
          .widget<ui.ChatMessage>(_bubble('stable-upload'))
          .key;
      final appended = ChatMessage(
        id: 'appended-message',
        topicId: 'usrPeer',
        seq: 2,
        localSeq: 0,
        senderId: 'peer',
        createdAt: DateTime(2026).add(const Duration(seconds: 1)),
        content: 'Appended item',
      );
      for (final item in [
        (Delivery.sent, 'Sent'),
        (Delivery.received, 'Delivered'),
        (Delivery.read, 'Read'),
      ]) {
        // Update only, then update + append, then update + trim in one emission.
        final withAppended = item.$1 == Delivery.received;
        final ref = '/v0/file/s/uploaded-${item.$1.name}';
        cubit.show(
          [attachment(item.$1, ref: ref), if (withAppended) appended],
          live: true,
          hasNewer: false,
          hasOlder: false,
        );
        await _settleFrames(tester);
        expect(find.byTooltip(item.$2, skipOffstage: false), findsOneWidget);
        expect(find.byTooltip('Queued', skipOffstage: false), findsNothing);
        expect(
          tester
              .widget<AttachmentView>(
                find.byType(AttachmentView, skipOffstage: false),
              )
              .data['ref'],
          ref,
        );
        expect(_bubble('stable-upload'), findsOneWidget);
        expect(
          _bubble('appended-message'),
          withAppended ? findsOneWidget : findsNothing,
        );
        expect(
          tester.widget<ui.ChatMessage>(_bubble('stable-upload')).key,
          bubbleKey,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('group messages show their author', (tester) async {
    cubit.show(_messages(1, 2), live: true, hasNewer: false);
    await mount(tester, topicId: 'grpTest');
    await tester.pumpAndSettle();
    expect(find.byType(ui.Username, skipOffstage: false), findsWidgets);
    expect(find.text('peer', skipOffstage: false), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('coalesced ACK and arrivals retain identity and entry age', (
    tester,
  ) async {
    ChatMessage outgoing(Delivery delivery) => ChatMessage(
      id: 'outgoing',
      topicId: 'usrPeer',
      seq: delivery == Delivery.queued ? -1 : 1,
      localSeq: 1,
      senderId: 'me',
      createdAt: DateTime(2026),
      content: 'Queued then acknowledged',
      delivery: delivery,
    );
    cubit.show([], live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    cubit.show(
      [outgoing(Delivery.queued)],
      live: true,
      hasOlder: false,
      hasNewer: false,
      arrivalIds: {'outgoing'},
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    final originalState = tester.state(_arrival('outgoing'));
    final enteredAt = tester
        .widget<MessageArrival>(_arrival('outgoing'))
        .enteredAt;
    expect(enteredAt, isNotNull);
    final key = tester.widget<ui.ChatMessage>(_bubble('outgoing')).key;

    // Three emissions before rendering: the ACK must not erase either arrival
    // or restart the first animation. Delivery stays independent of effects.
    cubit.show(
      [outgoing(Delivery.sent), ..._messages(2, 1)],
      live: true,
      hasOlder: false,
      hasNewer: false,
      arrivalIds: {'message-2'},
    );
    cubit.show(
      [outgoing(Delivery.read), ..._messages(2, 2)],
      live: true,
      hasOlder: false,
      hasNewer: false,
      arrivalIds: {'message-3'},
    );
    cubit.show(
      [outgoing(Delivery.read), ..._messages(2, 2)],
      live: true,
      hasOlder: false,
      hasNewer: false,
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(tester.state(_arrival('outgoing')), same(originalState));
    expect(tester.widget<ui.ChatMessage>(_bubble('outgoing')).key, key);
    expect(
      tester.widget<MessageArrival>(_arrival('outgoing')).enteredAt,
      enteredAt,
    );
    expect(
      tester.widget<MessageArrival>(_arrival('message-2')).enteredAt,
      isNotNull,
    );
    expect(
      tester.widget<MessageArrival>(_arrival('message-3')).enteredAt,
      isNotNull,
    );
    expect(find.byTooltip('Read', skipOffstage: false), findsOneWidget);
    await _settleFrames(tester);
    expect(cubit.following.last, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('window eviction and history reentry do not replay arrival', (
    tester,
  ) async {
    cubit.show(_messages(1, 1), live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    cubit.show(
      _messages(1, 2),
      live: true,
      hasOlder: false,
      hasNewer: false,
      arrivalIds: {'message-2'},
    );
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(
      tester.widget<MessageArrival>(_arrival('message-2')).enteredAt,
      isNotNull,
    );
    cubit.show(_messages(1, 1));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(_bubble('message-2'), findsNothing);
    cubit.show(_messages(1, 2));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(
      tester.widget<MessageArrival>(_arrival('message-2')).enteredAt,
      isNull,
    );
    final fade = tester.widget<FadeTransition>(
      find
          .descendant(
            of: _arrival('message-2'),
            matching: find.byType(FadeTransition, skipOffstage: false),
            skipOffstage: false,
          )
          .first,
    );
    expect(fade.opacity.value, 1);
    await _settleFrames(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('background arrival resumes as a quiet snapshot', (tester) async {
    cubit.show(_messages(1, 1), live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    cubit.reads.clear();
    cubit.show(
      _messages(1, 2),
      live: true,
      hasOlder: false,
      hasNewer: false,
      arrivalIds: {'message-2'},
    );
    await tester.pump();
    expect(cubit.reads, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    VisibilityDetectorController.instance.notifyNow();
    await _settleFrames(tester);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MessageArrival>(_arrival('message-2')).enteredAt,
      isNull,
    );
    expect(cubit.reads, contains(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('continuous arrivals do not starve settled visible receipts', (
    tester,
  ) async {
    cubit.show(_messages(1, 1), live: true, hasOlder: false, hasNewer: false);
    await mount(tester);
    cubit.reads.clear();
    cubit.show(
      _messages(1, 2),
      live: true,
      hasOlder: false,
      hasNewer: false,
      arrivalIds: {'message-2'},
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(cubit.reads, isNot(contains(2)));
    cubit.show(
      _messages(1, 3),
      live: true,
      hasOlder: false,
      hasNewer: false,
      arrivalIds: {'message-3'},
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(cubit.reads, contains(2));
    expect(cubit.reads, isNot(contains(3)));
    await _settleFrames(tester);
    expect(cubit.reads, contains(3));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'reply invalidates an in-flight page even for a retained target',
    (tester) async {
      cubit.show(_messages(1, 120, reply: true), live: true, hasNewer: false);
      await mount(tester);
      cubit.show(
        _messages(1, 120, reply: true),
        live: true,
        hasNewer: false,
        loadingOlder: true,
      );
      await _settleFrames(tester);
      var opens = 0;
      cubit.openAction = (seq) async {
        opens++;
        cubit.show(_messages(1, 40));
      };
      await tester.tap(
        find.text('Replying to a message', skipOffstage: false).first,
      );
      await _settleFrames(tester);
      await tester.pumpAndSettle();
      expect(opens, 1);
      expect(cubit.jumpedTo, 7);
      expect(
        tester
            .getRect(_bubble('message-7'))
            .overlaps(tester.getRect(find.byType(ui.Chat))),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'outside-window reply loads once and positions the exact target',
    (tester) async {
      cubit.show(_messages(81, 120, reply: true), live: true, hasNewer: false);
      await mount(tester);
      var opens = 0;
      cubit.openAction = (seq) async {
        opens++;
        expect(seq, 7);
        cubit.show(_messages(1, 40));
      };
      await tester.tap(
        find.text('Replying to a message', skipOffstage: false).first,
      );
      await _settleFrames(tester);
      await tester.pumpAndSettle();
      expect(opens, 1);
      expect(cubit.jumpedTo, 7);
      expect(
        tester
            .getRect(_bubble('message-7'))
            .overlaps(tester.getRect(find.byType(ui.Chat))),
        isTrue,
      );
      expect(
        tester.widget<MessageArrival>(_arrival('message-7')).enteredAt,
        isNull,
      );
      Color outline() =>
          ((tester.widget<MessageArrival>(_arrival('message-7')).child
                          as AnimatedContainer)
                      .foregroundDecoration
                  as BoxDecoration)
              .border!
              .top
              .color;
      expect(outline(), isNot(Colors.transparent));
      final retainedList = tester.widget(find.byType(anchored.FlutterListView));
      final targetTop = tester.getTopLeft(_bubble('message-7')).dy;
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(outline(), Colors.transparent);
      expect(
        tester.widget(find.byType(anchored.FlutterListView)),
        same(retainedList),
      );
      expect(tester.getTopLeft(_bubble('message-7')).dy, targetTop);
      expect(cubit.following.last, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    '120-to-120 older and newer replacements retain visible anchor offset',
    (tester) async {
      await mount(tester);
      cubit.show(_messages(81, 120));
      await _settleFrames(tester);
      final controller = tester
          .widget<MessageList>(find.byType(MessageList))
          .controller;
      // Scroll into overlapping retained rows; vary heights rather than estimates.
      controller.sliverController.jumpToIndex(40);
      await _settleFrames(tester);
      final olderAnchor = _firstVisible(tester);
      cubit.show(_messages(41, 120));
      await _settleFrames(tester);
      expect(_bubble(olderAnchor.$1), findsOneWidget);
      final olderRect = tester.getRect(_bubble(olderAnchor.$1));
      final viewport = tester.getRect(find.byType(ui.Chat));
      expect(olderRect.top - viewport.top, closeTo(olderAnchor.$2, 2));
      expect(cubit.state.messages, hasLength(120));

      controller.sliverController.jumpToIndex(70);
      await _settleFrames(tester);
      final newerAnchor = _firstVisible(tester);
      cubit.reads.clear();
      cubit.show(_messages(81, 120));
      await _settleFrames(tester);
      expect(_bubble(newerAnchor.$1), findsOneWidget);
      final newerRect = tester.getRect(_bubble(newerAnchor.$1));
      expect(
        newerRect.top - tester.getRect(find.byType(ui.Chat)).top,
        closeTo(newerAnchor.$2, 2),
      );
      expect(cubit.state.messages, hasLength(120));
      final visibleReadBound = _visibleReadBound(tester);
      expect(cubit.reads.every((seq) => seq <= visibleReadBound), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('unchanged scrollable snapshot completes without extra frames', (
    tester,
  ) async {
    cubit.show(_messages(1, 120));
    await mount(tester);
    final scroll = tester
        .widget<MessageList>(find.byType(MessageList))
        .controller;
    scroll.sliverController.jumpToIndex(50);
    await _settleFrames(tester);
    // Reading is a user gesture; indexed positioning is only fixture setup.
    await tester.drag(find.byType(MessageList), const Offset(0, 32));
    await _settleFrames(tester);
    final before = _firstVisible(tester);
    final following = List<bool>.of(cubit.following);
    expect(
      following.last,
      isFalse,
      reason:
          'History anchor $before, remaining ${scroll.position.extentAfter}; '
          'follow callbacks $following',
    );
    cubit.show(_messages(1, 120));
    // Do not manufacture frames after the framework becomes idle: metadata
    // updates must complete even when restoring the anchor is a no-op.
    await tester.pumpAndSettle();
    // The new viewport reports changes, not redundant identical follow states.
    expect(cubit.following, following);
    final after = _firstVisible(tester);
    expect(after.$1, before.$1);
    expect(after.$2, closeTo(before.$2, .5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'returning from a covered route reads visible incoming without another event',
    (tester) async {
      cubit.show(_messages(1, 20), live: true);
      await mount(tester);
      // A retained web list may not issue another geometry callback on return.
      VisibilityDetectorController.instance.updateInterval = const Duration(
        hours: 1,
      );
      final navigator = Navigator.of(tester.element(find.byType(ChatScreen)));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Covered route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      cubit.reads.clear();
      cubit.show(_messages(1, 21), live: true, arrivalIds: {'message-21'});
      await tester.pumpAndSettle();
      expect(cubit.reads, isEmpty);

      navigator.pop();
      await tester.pumpAndSettle();
      expect(cubit.reads, contains(21));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      VisibilityDetectorController.instance.notifyNow();
      await tester.pump();
    },
  );

  testWidgets(
    'background never marks read; retained reply uses explicit snapshot navigation',
    (tester) async {
      await mount(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      cubit.reads.clear();
      cubit.show(_messages(1, 120, reply: true), live: true, hasNewer: false);
      await _settleFrames(tester);
      expect(cubit.reads, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      VisibilityDetectorController.instance.notifyNow();
      await _settleFrames(tester);
      // Resuming permits visible read receipts, not unread rows outside layout.
      await tester.pumpAndSettle(const Duration(milliseconds: 20));
      expect(cubit.reads, isNotEmpty);
      expect(
        cubit.reads.every((seq) => seq <= _visibleReadBound(tester)),
        isTrue,
      );
      await tester.tap(
        find.text('Replying to a message', skipOffstage: false).first,
      );
      await _settleFrames(tester);
      await tester.pumpAndSettle();
      expect(cubit.jumpedTo, 7);
      expect(
        tester
            .getRect(_bubble('message-7'))
            .overlaps(tester.getRect(find.byType(ui.Chat))),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'following live never flashes Latest while queued sends lag behind the DB',
    (tester) async {
      final messages = _messages(1, 40);
      cubit.show(messages, live: true);
      await mount(tester);
      final latest = find.byKey(const ValueKey('latest-messages'));
      expect(cubit.following.last, isTrue);
      expect(latest, findsNothing);

      for (var i = 1; i <= 20; i++) {
        // ACKs and the next local write can be ahead of the Cubit's event.
        // This is history availability, not a change of the user's intent.
        cubit.show(messages, unreadCount: i);
        for (var frame = 0; frame < 3; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(latest, findsNothing, reason: 'send $i, frame $frame');
        }
        messages.add(
          ChatMessage(
            id: 'own-$i',
            topicId: 'usrPeer',
            seq: 40 + i,
            localSeq: i,
            senderId: 'me',
            createdAt: DateTime(2026, 2, 1),
            content: 'Own message $i',
          ),
        );
        cubit.show(messages, live: true, arrivalIds: {'own-$i'});
        for (var frame = 0; frame < 3; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(latest, findsNothing, reason: 'arrival $i, frame $frame');
        }
      }
      expect(cubit.following, isNot(contains(false)));
      expect(cubit.latestRequests + cubit.newerRequests, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'new-message notice while reading history preserves viewport and never reads unseen arrivals',
    (tester) async {
      await mount(tester);
      final history = _messages(81, 120);
      cubit.show(history);
      await _settleFrames(tester);
      final list = tester.widget<MessageList>(find.byType(MessageList));
      list.controller.sliverController.jumpToIndex(50);
      await _settleFrames(tester);
      final before = _firstVisible(tester);
      cubit.reads.clear();
      cubit.show(history, unreadCount: 150);
      await _settleFrames(tester);
      expect(find.byKey(const ValueKey('latest-messages')), findsOneWidget);
      expect(find.text('150 new messages'), findsOneWidget);
      final after = _firstVisible(tester);
      expect(after.$1, before.$1);
      expect(after.$2, closeTo(before.$2, 2));
      expect(cubit.reads.every((seq) => seq <= 200), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'actual older-page callback preserves offset while growing 40 to 80',
    (tester) async {
      await mount(tester);
      cubit.show(_messages(161, 40), live: true, hasNewer: false);
      await _settleFrames(tester);
      final list = tester.widget<MessageList>(find.byType(MessageList));
      final scroll = list.controller;
      scroll.sliverController.jumpToIndex(1);
      await _settleFrames(tester);
      final release = Completer<void>();
      cubit.olderAction = () async {
        await release.future;
        cubit.show(_messages(121, 80), live: true, hasNewer: false);
      };
      await tester.drag(find.byType(ui.Chat), const Offset(0, 40));
      await _settleFrames(tester);
      expect(cubit.olderRequests, greaterThan(0));
      final before = _firstVisible(tester);
      release.complete();
      await _settleFrames(tester);
      expect(_bubble(before.$1), findsOneWidget);
      final rect = tester.getRect(_bubble(before.$1));
      expect(
        rect.top - tester.getRect(find.byType(ui.Chat)).top,
        closeTo(before.$2, 2),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('Latest semantic action navigates directly without paging', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    cubit.show(_messages(1, 40), hasOlder: false);
    await cubit.open('usrPeer', aroundSeq: 20);
    await mount(tester);
    cubit.openAction = (seq) async {
      expect(seq, isNull);
      cubit.show(_messages(561, 40), live: true, hasNewer: false);
    };
    final latest = find.byKey(const ValueKey('latest-messages'));
    expect(
      tester.getSemantics(latest),
      matchesSemantics(
        label: 'Latest messages',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(latest);
    await _settleFrames(tester);
    expect(cubit.latestRequests, 1);
    expect(cubit.olderRequests + cubit.newerRequests, 0);
    final last = tester.getRect(_bubble('message-600'));
    final composer = tester.getRect(find.byType(ui.Composer));
    expect(last.bottom, lessThanOrEqualTo(composer.top));
    expect(last.bottom, greaterThan(composer.top - 30));
    expect(last.top, lessThan(composer.top));
    expect(find.byKey(const ValueKey('latest-messages')), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
