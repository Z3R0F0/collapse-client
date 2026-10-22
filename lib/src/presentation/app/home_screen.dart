import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/notifications/push_service.dart';
import '../../../core/theme.dart';
import '../../../dependency_injection.dart';
import '../../../widgets/view_activity.dart';
import '../../data/auth/auth_repository.dart';
import '../../data/profile/profile_repository.dart';
import '../../domain/chat/chat_models.dart';
import '../auth/auth_cubit.dart';
import '../chat/chats_cubit.dart';
import '../contacts/contacts_cubit.dart';
import '../profile/profile_cubit.dart';
import '../navigation/app_routes.dart';
import '../navigation/app_navigation.dart';
import 'settings_cubit.dart';
import 'peer_tile.dart';
import 'workspace_actions.dart';
import 'workspace_layout.dart';

part 'parts/home_actions.dart';
part 'parts/home_chats.dart';
part 'parts/home_connection.dart';
part 'parts/home_contacts.dart';
part 'parts/home_groups.dart';
part 'parts/home_navigation.dart';
part 'parts/home_workspace.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.userId,
    required this.navigationShell,
    required this.uri,
  });
  final String userId;
  final StatefulNavigationShell navigationShell;
  final Uri uri;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int get _tab => widget.navigationShell.currentIndex;
  bool get _hasDetail => _tab == 2 || widget.uri.pathSegments.length > 1;
  late final ChatsCubit _chats;
  late final ContactsCubit _contacts;
  late final ProfileCubit _profile;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chats = locator<ChatsCubit>();
    _contacts = locator<ContactsCubit>();
    _profile = locator<ProfileCubit>(param1: widget.userId);
    if (context.read<AuthCubit>().state.phase == SessionPhase.online) {
      _profile.load();
    }
    context
        .read<PushService>()
        .initialize(
          onOpenTopic: (topic) {
            if (mounted) _openChat(topic, topic);
          },
        )
        .catchError((Object _) {
          _showError();
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AuthCubit>().reconnect();
    }
  }

  void _selectTab(int value) => widget.navigationShell.goBranch(
    value,
    // Mobile has no visible master beside a restored conversation. An explicit
    // Chats selection (or reselecting any tab) must expose its canonical root.
    initialLocation:
        value == _tab ||
        (value == 0 &&
            MediaQuery.sizeOf(context).width < WorkspaceLayout.breakpoint),
  );

  @override
  Widget build(BuildContext context) => ViewActivity(
    active: ModalRoute.isCurrentOf(context) ?? true,
    child: MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _chats),
        BlocProvider.value(value: _contacts),
        BlocProvider.value(value: _profile),
      ],
      child: WorkspaceActions(
        signOut: _signOut,
        notifications: _enableNotifications,
        child: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                _buildConnection(context),
                Expanded(
                  child: BlocBuilder<SettingsCubit, SettingsState>(
                    buildWhen: (old, next) =>
                        old.sidebarWidth != next.sidebarWidth,
                    builder: (context, settings) => WorkspaceLayout(
                      masterBuilder: _buildMaster,
                      detail: widget.navigationShell,
                      hasDetail: _hasDetail,
                      sidebarWidth: settings.sidebarWidth,
                      onSidebarWidthChanged: context
                          .read<SettingsCubit>()
                          .setSidebarWidth,
                      resizeLabel: context.l10n.resizeSidebar,
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar:
                MediaQuery.sizeOf(context).width < WorkspaceLayout.breakpoint &&
                    (!_hasDetail || _tab == 2)
                ? _buildNavigation(context)
                : null,
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chats.close();
    _contacts.close();
    _profile.close();
    super.dispose();
  }
}
