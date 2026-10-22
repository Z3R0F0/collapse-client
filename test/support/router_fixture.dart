import 'dart:async';

import 'package:collapse/core/config.dart';
import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/core/notifications/push_service.dart';
import 'package:collapse/core/theme.dart';
import 'package:collapse/dependency_injection.dart';
import 'package:collapse/l10n/app_localizations.dart';
import 'package:collapse/src/data/auth/auth_repository.dart';
import 'package:collapse/src/data/auth/session_store.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/data/media/media_repository.dart';
import 'package:collapse/src/data/media/media_gallery_repository.dart';
import 'package:collapse/src/data/profile/profile_repository.dart';
import 'package:collapse/src/presentation/app/settings_cubit.dart';
import 'package:collapse/src/presentation/auth/auth_cubit.dart';
import 'package:collapse/src/presentation/chat/chat_cubit.dart';
import 'package:collapse/src/presentation/chat/chats_cubit.dart';
import 'package:collapse/src/presentation/chat/search/message_search_cubit.dart';
import 'package:collapse/src/presentation/contacts/contacts_cubit.dart';
import 'package:collapse/src/presentation/navigation/app_router.dart';
import 'package:collapse/src/presentation/profile/profile_cubit.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'fake_gateway.dart';

class RouterAuthCubit extends AuthCubit {
  RouterAuthCubit(super.repository);
  void show(SessionState value) => emit(value);
}

class RouterChatCubit extends ChatCubit {
  RouterChatCubit(super.repository);
  int opens = 0;
  @override
  Future<void> open(String topicId, {int? aroundSeq, String? aroundId}) {
    opens++;
    return super.open(topicId, aroundSeq: aroundSeq, aroundId: aroundId);
  }
}

class _Profiles extends ProfileRepository {
  _Profiles(super.gateway);
  @override
  Future<PeerProfile> get(String id, {bool refresh = false}) async =>
      PeerProfile(id: id, name: id == 'me' ? 'Me' : 'Peer');
}

class _Store implements SessionStore {
  @override
  Future<SavedSession?> read() async => null;
  @override
  Future<void> write(SavedSession session) async {}
  @override
  Future<void> clear() async {}
}

class _NoCache implements BaseCacheManager {
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RouterFixture {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final gateway = FakeGateway()..seed(200);
  final config = AppConfig(
    endpoint: Uri.parse('ws://localhost:6060/v0/channels'),
    apiKey: 'fixture',
  );
  final chats = <RouterChatCubit>[];
  final searches = <MessageSearchCubit>[];
  final locations = <Uri>[];
  late final ChatsRepository repository;
  late final AuthRepository authentication;
  late final RouterAuthCubit auth;
  late final ProfileRepository profiles;
  late final MediaRepository media;
  late final PushService push;
  late final SettingsCubit settings;
  late final AppRouter navigation;

  Future<void> initialize({
    required String location,
    bool signedIn = true,
    bool restoring = false,
  }) async {
    await locator.reset();
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    settings = SettingsCubit(await SharedPreferences.getInstance());
    repository = ChatsRepository(
      database: db,
      gateway: gateway,
      serverId: 'local',
    );
    await repository.start('me');
    await db.mergeTopic('local|me', 'usrPeer', {
      'seq': 200,
      'read': 200,
      'public': {'fn': 'Peer'},
    });
    await db.batch(
      (batch) => batch.insertAll(db.messages, [
        for (var seq = 1; seq <= 200; seq++)
          MessagesCompanion.insert(
            scope: 'local|me',
            topicId: 'usrPeer',
            seq: seq,
            clientId: 'usrPeer:$seq',
            senderId: 'peer',
            createdAtMs: seq,
            content: '"Message $seq"',
          ),
      ]),
    );
    await db.recordCoverage('local|me', 'usrPeer', 1, 201);
    profiles = _Profiles(gateway);
    media = MediaRepository(config, gateway, cache: _NoCache())..userId = 'me';
    push = PushService(gateway, enabled: false);
    authentication = AuthRepository(
      gateway: gateway,
      chats: repository,
      store: _Store(),
    );
    auth = RouterAuthCubit(authentication)
      ..show(
        SessionState(
          restoring
              ? SessionPhase.restoring
              : signedIn
              ? SessionPhase.offline
              : SessionPhase.signedOut,
          userId: !restoring && signedIn ? 'me' : null,
        ),
      );
    locator.registerFactory<ChatCubit>(() {
      final cubit = RouterChatCubit(repository);
      chats.add(cubit);
      return cubit;
    });
    locator.registerFactory(() => ChatsCubit(repository, profiles));
    locator.registerFactory(() => ContactsCubit(profiles));
    locator.registerFactoryParam<ProfileCubit, String, void>(
      (id, _) => ProfileCubit(profiles, id),
    );
    locator.registerFactoryParam<MessageSearchCubit, String, void>((id, _) {
      final cubit = MessageSearchCubit(repository, id);
      searches.add(cubit);
      return cubit;
    });
    navigation = AppRouter(auth, config, initialLocation: location);
    locations.add(uri);
    navigation.router.routeInformationProvider.addListener(
      () => locations.add(uri),
    );
  }

  Future<void> mount(
    WidgetTester tester, {
    double width = 1200,
    Future<Object?> Function(MethodCall)? recordCall,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          recordCall ?? (_) async => null,
        );
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ChatsRepository>.value(value: repository),
          RepositoryProvider<ProfileRepository>.value(value: profiles),
          RepositoryProvider<MediaRepository>.value(value: media),
          RepositoryProvider(
            create: (_) => MediaGalleryRepository(repository, media),
          ),
          RepositoryProvider<PushService>.value(value: push),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: auth),
            BlocProvider<SettingsCubit>.value(value: settings),
          ],
          child: MaterialApp.router(
            routerConfig: navigation.router,
            builder: AppRouter.buildScope,
            theme: appTheme(Brightness.light),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      ),
    );
    await pump(tester);
  }

  Future<void> pump(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  Uri get uri => navigation.router.routeInformationProvider.value.uri;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await pump(tester);
    navigation.dispose();
    var closed = false;
    late Future<void> closing;
    await tester.runAsync(() async {
      closing = _closeResources();
      unawaited(
        closing.then<void>(
          (_) => closed = true,
          onError: (Object _, StackTrace _) => closed = true,
        ),
      );
    });
    // UI subscriptions and draft writes originate in the fake widget zone,
    // while SQLite completes in the real zone. Both clocks must drain before
    // awaiting the repository's explicit disposal barrier.
    for (var i = 0; i < 20 && !closed; i++) {
      await pump(tester);
    }
    expect(closed, isTrue, reason: 'router fixture disposal must complete');
    await tester.runAsync(() => closing);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
  }

  Future<void> _closeResources() async {
    await auth.close();
    await authentication.dispose();
    await settings.close();
    await push.dispose();
    await media.dispose();
    await repository.dispose();
    await gateway.dispose();
    await db.close();
    await locator.reset();
  }
}
