import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/core/theme.dart';
import 'package:collapse/l10n/app_localizations.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/presentation/chat/search/message_search_cubit.dart';
import 'package:collapse/src/presentation/chat/search/message_search_screen.dart';
import 'package:collapse_tinode/collapse_tinode.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Cubit extends MessageSearchCubit {
  _Cubit(ChatsRepository repository) : super(repository, 'peer');
  int historyLoads = 0;
  void show({bool busy = false, bool complete = false}) => emit(
    MessageSearchState(
      query: 'word',
      loading: busy,
      page: SearchPage(
        hits: [
          SearchHit(
            id: 'stable',
            topicId: 'peer',
            seq: -1,
            localSeq: 1,
            senderId: 'me',
            createdAt: DateTime(2026),
            snippet: 'Matching word',
          ),
        ],
        cacheIndexed: !busy,
        historyComplete: complete,
        canLoadHistory: !complete,
      ),
    ),
  );
  @override
  Future<void> loadHistory() async {
    historyLoads++;
  }
}

void main() {
  late AppDatabase database;
  late TinodeGateway gateway;
  late ChatsRepository repository;
  late _Cubit cubit;
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = TinodeGateway(
      endpoint: Uri.parse('ws://localhost:6060'),
      apiKey: 'test',
    );
    repository = ChatsRepository(
      database: database,
      gateway: gateway,
      serverId: 'screen-test',
    );
    cubit = _Cubit(repository);
  });
  tearDown(() async {
    await cubit.close();
    await repository.dispose();
    await gateway.dispose();
    await database.close();
  });

  Future<void> mount(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      BlocProvider<MessageSearchCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const MessageSearchScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('partial cache is explicit and history action respects loading', (
    tester,
  ) async {
    cubit.show(busy: true);
    await mount(tester);
    final load = find.widgetWithText(TextButton, 'Load more history');
    expect(find.text('Preparing saved messages…'), findsOneWidget);
    expect(tester.widget<TextButton>(load).onPressed, isNull);
    cubit.show();
    await tester.pump();
    expect(
      find.text('Searching saved messages; some history is not downloaded'),
      findsOneWidget,
    );
    expect(find.byTooltip('Queued'), findsOneWidget);
    await tester.tap(load);
    expect(cubit.historyLoads, 1);
    cubit.show(complete: true);
    await tester.pump();
    expect(
      find.text('All chat history is available for search'),
      findsOneWidget,
    );
    expect(load, findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('search status fits a narrow screen with large text', (
    tester,
  ) async {
    cubit.show();
    await mount(tester, scale: 2);
    await tester.pumpAndSettle();
    expect(find.text('Matching word'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
