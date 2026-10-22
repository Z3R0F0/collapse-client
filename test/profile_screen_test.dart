import 'package:collapse/core/theme.dart';
import 'package:collapse/l10n/app_localizations.dart';
import 'package:collapse/src/data/media/media_repository.dart';
import 'package:collapse/src/data/profile/profile_repository.dart';
import 'package:collapse/src/presentation/app/settings_cubit.dart';
import 'package:collapse/src/presentation/profile/profile_cubit.dart';
import 'package:collapse/src/presentation/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Profile implements ProfileRepository {
  @override
  int get accountGeneration => 1;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Media implements MediaRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final locale in ['en', 'ru']) {
    testWidgets('$locale profile preferences fit narrow large text', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsCubit(await SharedPreferences.getInstance());
      final profile = ProfileCubit(_Profile(), 'me');
      addTearDown(settings.close);
      addTearDown(profile.close);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        RepositoryProvider<MediaRepository>.value(
          value: _Media(),
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: settings),
              BlocProvider.value(value: profile),
            ],
            child: MaterialApp(
              theme: appTheme(Brightness.dark),
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: ProfileScreen(
                  userId: 'me',
                  isMe: true,
                  onSignOut: () {},
                  onNotifications: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final language = find.byType(DropdownButton<String>);
      await tester.ensureVisible(language);
      await tester.pumpAndSettle();
      await tester.tap(language);
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      expect(settings.state.locale?.languageCode, 'en');
      final theme = find.byType(DropdownButton<ThemeMode>);
      await tester.ensureVisible(theme);
      await tester.pumpAndSettle();
      expect(tester.getSize(theme).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });
  }
}
