import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config.dart';
import '../../../core/theme.dart';
import '../../../widgets/view_activity.dart';
import '../../data/auth/auth_repository.dart';
import '../app/home_screen.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_screen.dart';
import 'app_routes.dart';
import 'conversation_shell.dart';
import 'route_pages.dart';
import 'media_route.dart';

/// One router per application, independent of theme, connection and window size.
class AppRouter extends ChangeNotifier {
  // Flutter 3.41's WidgetsApp.router omits the enclosing Navigator FocusScope.
  // OverlayPortal tooltips then reparent web semantics and blur active inputs.
  // Remove when the pinned SDK includes flutter/flutter#192601.
  static Widget buildScope(BuildContext context, Widget? child) => FocusScope(
    debugLabel: 'Router scope',
    autofocus: true,
    child: BlocSelector<AuthCubit, SessionState, bool>(
      selector: (session) => session.phase == SessionPhase.restoring,
      // Restore the local account before mounting Router. Otherwise a reload
      // adds a temporary /login entry and browser Back loops through it.
      // Cached auth becomes usable before the background network reconnect.
      builder: (_, restoring) => restoring
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : child!,
    ),
  );

  AppRouter(this.auth, this.config, {String? initialLocation}) {
    _subscription = auth.stream.listen((state) {
      final identityChanged = (_account != null) != state.authenticated;
      if (_account != null && state.userId == null) _forgetDestination = true;
      _account = state.userId;
      final context = router.routerDelegate.navigatorKey.currentContext;
      if (identityChanged && context != null && context.mounted) {
        // Auth gates replace the current URL, never a Back destination which
        // would immediately redirect to the same conversation again.
        Router.neglect(context, notifyListeners);
      } else {
        notifyListeners();
      }
    });
    _account = auth.state.userId;
    router = GoRouter(
      navigatorKey: _rootNavigator,
      initialLocation: initialLocation,
      refreshListenable: this,
      redirect: _redirect,
      errorBuilder: (_, _) => const RouteUnavailable(),
      routes: [
        GoRoute(path: '/', redirect: (_, _) => AppRoutes.chats),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, _) => AuthScreen(config: config),
        ),
        StatefulShellRoute(
          pageBuilder: (_, state, shell) => NoTransitionPage(
            key: ValueKey('workspace:${auth.state.userId}'),
            child: HomeScreen(
              userId: auth.state.userId!,
              navigationShell: shell,
              uri: state.uri,
            ),
          ),
          navigatorContainerBuilder: (_, shell, children) => IndexedStack(
            index: shell.currentIndex,
            children: [
              for (var i = 0; i < children.length; i++)
                ViewActivity(
                  active: i == shell.currentIndex,
                  child: children[i],
                ),
            ],
          ),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.chats,
                  builder: (_, _) => const SelectConversation(),
                  routes: [
                    ShellRoute(
                      pageBuilder: (_, state, child) => NoTransitionPage(
                        key: ValueKey(
                          'conversation:${state.pathParameters['topic']}',
                        ),
                        child: ConversationShell(
                          topic: state.pathParameters['topic']!,
                          userId: auth.state.userId!,
                          uri: state.uri,
                          panel: child,
                        ),
                      ),
                      routes: [
                        GoRoute(
                          path: ':topic',
                          redirect: (_, state) =>
                              AppRoutes.isTopic(state.pathParameters['topic']!)
                              ? null
                              : AppRoutes.chats,
                          pageBuilder: (_, state) => NoTransitionPage(
                            key: state.pageKey,
                            child: const SizedBox.shrink(),
                          ),
                          routes: [
                            GoRoute(
                              path: 'info',
                              builder: (_, state) => ConversationInfo(
                                topic: state.pathParameters['topic']!,
                                member: state.uri.queryParameters['member'],
                              ),
                              routes: [_mediaRoute(fromInfo: true)],
                            ),
                            GoRoute(
                              path: 'search',
                              builder: (_, state) => ConversationSearch(
                                topic: state.pathParameters['topic']!,
                                query: state.uri.queryParameters['q'] ?? '',
                              ),
                            ),
                            _mediaRoute(),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.contacts,
                  builder: (_, _) => const SelectConversation(),
                  routes: [
                    GoRoute(
                      path: ':person',
                      redirect: (_, state) =>
                          AppRoutes.isTopic(state.pathParameters['person']!)
                          ? null
                          : AppRoutes.contacts,
                      builder: (_, state) =>
                          ContactProfile(id: state.pathParameters['person']!),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.profile,
                  builder: (_, _) => const OwnProfile(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  final AuthCubit auth;
  final AppConfig config;
  final _rootNavigator = GlobalKey<NavigatorState>();
  late final GoRouter router;
  late final StreamSubscription<SessionState> _subscription;
  String? _account;
  bool _forgetDestination = false;

  GoRoute _mediaRoute({bool fromInfo = false}) => GoRoute(
    path: 'media',
    parentNavigatorKey: _rootNavigator,
    redirect: (_, state) {
      final safe = AppRoutes.safeDestination(state.uri.toString());
      return safe == state.uri.toString() ? null : safe;
    },
    pageBuilder: (_, state) => CustomTransitionPage(
      key: state.pageKey,
      opaque: false,
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
      child: MediaRoute(
        key: ValueKey(
          '${state.pathParameters['topic']}:${state.uri.queryParameters['kind'] ?? 'visual'}',
        ),
        topic: state.pathParameters['topic']!,
        uri: state.uri,
        extra: state.extra,
        fromInfo: fromInfo,
      ),
    ),
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final atLogin = state.uri.path == AppRoutes.login;
    if (!auth.state.authenticated) {
      if (atLogin) return null;
      final destination = _forgetDestination
          ? AppRoutes.chats
          : AppRoutes.safeDestination(state.uri.toString());
      return Uri(
        path: AppRoutes.login,
        queryParameters: {'from': destination},
      ).toString();
    }
    _forgetDestination = false;
    return atLogin
        ? AppRoutes.safeDestination(state.uri.queryParameters['from'])
        : null;
  }

  @override
  void dispose() {
    _subscription.cancel();
    router.dispose();
    super.dispose();
  }
}

class RouteUnavailable extends StatelessWidget {
  const RouteUnavailable({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.appName)),
    body: Center(
      child: TextButton(
        onPressed: () => context.go(AppRoutes.chats),
        child: Text(context.l10n.routeUnavailable),
      ),
    ),
  );
}
