import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/notifications/push_service.dart';
import 'core/theme.dart';
import 'dependency_injection.dart';
import 'l10n/app_localizations.dart';
import 'src/data/chat/chats_repository.dart';
import 'src/data/media/media_repository.dart';
import 'src/data/media/media_gallery_repository.dart';
import 'src/data/profile/profile_repository.dart';
import 'src/presentation/app/settings_cubit.dart';
import 'src/presentation/auth/auth_cubit.dart';
import 'src/presentation/navigation/app_router.dart';

class CollapseApp extends StatefulWidget {
  const CollapseApp({super.key});
  @override
  State<CollapseApp> createState() => _CollapseAppState();
}

class _CollapseAppState extends State<CollapseApp> {
  final _lightTheme = appTheme(Brightness.light);
  final _darkTheme = appTheme(Brightness.dark);
  late final _navigation = AppRouter(locator<AuthCubit>(), locator());

  @override
  void dispose() {
    _navigation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider.value(value: locator<ChatsRepository>()),
      RepositoryProvider.value(value: locator<ProfileRepository>()),
      RepositoryProvider.value(value: locator<MediaRepository>()),
      RepositoryProvider.value(value: locator<MediaGalleryRepository>()),
      RepositoryProvider.value(value: locator<PushService>()),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider.value(value: locator<AuthCubit>()),
        BlocProvider.value(value: locator<SettingsCubit>()),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        buildWhen: (old, next) =>
            old.theme != next.theme || old.locale != next.locale,
        builder: (context, settings) => MaterialApp.router(
          routerConfig: _navigation.router,
          builder: AppRouter.buildScope,
          title: 'collapse',
          debugShowCheckedModeBanner: false,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: settings.theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: settings.locale,
        ),
      ),
    ),
  );
}
