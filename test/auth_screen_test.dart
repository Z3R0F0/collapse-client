import 'package:collapse/core/config.dart';
import 'package:collapse/core/theme.dart';
import 'package:collapse/l10n/app_localizations.dart';
import 'package:collapse/src/data/auth/auth_repository.dart';
import 'package:collapse/src/presentation/auth/auth_cubit.dart';
import 'package:collapse/src/presentation/auth/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth implements AuthRepository {
  final calls = <({String username, String password, String? name})>[];
  @override
  SessionState get state => const SessionState(SessionPhase.signedOut);
  @override
  Stream<SessionState> get changes => const Stream.empty();
  @override
  Future<void> signIn(
    String username,
    String password, {
    String? displayName,
  }) async {
    calls.add((username: username, password: password, name: displayName));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Auth repository;
  late AuthCubit cubit;
  setUp(() {
    repository = _Auth();
    cubit = AuthCubit(repository);
  });
  tearDown(() => cubit.close());

  Future<void> mount(
    WidgetTester tester, {
    String locale = 'en',
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: appTheme(brightness),
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: AuthScreen(
            config: AppConfig(
              endpoint: Uri.parse('ws://localhost:6060/v0/channels'),
              apiKey: 'test',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'sign-in validation and submission preserve the existing auth path',
    (tester) async {
      await mount(tester);
      await tester.ensureVisible(find.byKey(const Key('auth-submit')));
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();
      expect(repository.calls, isEmpty);
      await tester.enterText(
        find.byKey(const Key('auth-username')),
        'local_user',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'test-password',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(repository.calls, [
        (username: 'local_user', password: 'test-password', name: null),
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in ['en', 'ru']) {
    testWidgets('$locale registration fits narrow large-text layout', (
      tester,
    ) async {
      await mount(
        tester,
        locale: locale,
        scale: 2,
        brightness: Brightness.dark,
      );
      final toggle = find.byType(TextButton);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-username')),
        'local_user',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'test-password',
      );
      await tester.enterText(find.byKey(const Key('auth-name')), 'Local user');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(repository.calls.single.name, 'Local user');
      expect(tester.takeException(), isNull);
    });
  }
}
