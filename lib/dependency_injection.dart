import 'dart:async';
import 'package:collapse_tinode/tinode.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config.dart';
import 'core/database/app_database.dart';
import 'core/notifications/push_service.dart';
import 'src/data/auth/auth_repository.dart';
import 'src/data/auth/session_store.dart';
import 'src/data/chat/chats_repository.dart';
import 'src/data/media/media_repository.dart';
import 'src/data/media/media_gallery_repository.dart';
import 'src/data/profile/profile_repository.dart';
import 'src/presentation/app/settings_cubit.dart';
import 'src/presentation/auth/auth_cubit.dart';
import 'src/presentation/chat/chat_cubit.dart';
import 'src/presentation/chat/chats_cubit.dart';
import 'src/presentation/chat/search/message_search_cubit.dart';
import 'src/presentation/contacts/contacts_cubit.dart';
import 'src/presentation/profile/profile_cubit.dart';

final locator = GetIt.instance;

Future<void> initInjections(AppConfig config) async {
  locator.registerSingleton(config);
  locator.registerSingleton(await SharedPreferences.getInstance());
  locator.registerLazySingleton(
    () => AppDatabase(),
    dispose: (db) => db.close(),
  );
  locator.registerLazySingleton(
    () => TinodeGateway(
      endpoint: config.transportEndpoint,
      apiKey: config.apiKey,
    ),
    dispose: (gateway) => gateway.dispose(),
  );
  locator.registerLazySingleton<SessionStore>(
    () => SecureSessionStore(config.serverId),
  );
  locator.registerLazySingleton(
    () => ChatsRepository(
      database: locator(),
      gateway: locator(),
      serverId: config.serverId,
    ),
    dispose: (repo) => repo.dispose(),
  );
  locator.registerLazySingleton(() => ProfileRepository(locator()));
  locator.registerLazySingleton(
    () => MediaRepository(config, locator()),
    dispose: (repo) => repo.dispose(),
  );
  locator.registerLazySingleton(
    () => MediaGalleryRepository(locator(), locator()),
  );
  locator.registerLazySingleton(
    () => PushService(locator()),
    dispose: (service) => service.dispose(),
  );
  locator.registerLazySingleton(
    () =>
        AuthRepository(gateway: locator(), chats: locator(), store: locator()),
    dispose: (repo) => repo.dispose(),
  );
  locator.registerLazySingleton(
    () => SettingsCubit(locator()),
    dispose: (cubit) => cubit.close(),
  );
  locator.registerLazySingleton(
    () => AuthCubit(locator()),
    dispose: (cubit) => cubit.close(),
  );
  locator.registerFactory(() => ChatsCubit(locator(), locator()));
  locator.registerFactory(() => ContactsCubit(locator()));
  locator.registerFactory(() => ChatCubit(locator()));
  locator.registerFactoryParam<MessageSearchCubit, String, void>(
    (id, _) => MessageSearchCubit(locator(), id),
  );
  locator.registerFactoryParam<ProfileCubit, String, void>(
    (id, _) => ProfileCubit(locator(), id),
  );
  String? account;
  final subscription = locator<AuthRepository>().changes.listen((state) {
    locator<MediaRepository>().userId = state.userId;
    if (account != state.userId) {
      account = state.userId;
      locator<ProfileRepository>().clear();
    }
    if (state.phase == SessionPhase.online) {
      unawaited(
        locator<PushService>().synchronize().catchError((Object _) => false),
      );
    }
  });
  locator.registerSingleton<StreamSubscription<SessionState>>(
    subscription,
    dispose: (value) => value.cancel(),
  );
}
