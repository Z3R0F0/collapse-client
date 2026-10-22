import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme.dart';
import '../../../dependency_injection.dart';
import '../app/workspace_actions.dart';
import '../auth/auth_cubit.dart';
import '../chat/search/message_search_cubit.dart';
import '../chat/search/message_search_screen.dart';
import '../profile/profile_cubit.dart';
import '../profile/profile_screen.dart';
import 'app_routes.dart';
import 'app_navigation.dart';
import 'conversation_panel.dart';
import 'package:go_router/go_router.dart';

class SelectConversation extends StatelessWidget {
  const SelectConversation({super.key});
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.colors.surface,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 32, color: context.colors.outline),
          const SizedBox(height: 16),
          Text(context.l10n.selectChat, style: context.textStyles.labelLarge),
        ],
      ),
    ),
  );
}

class OwnProfile extends StatelessWidget {
  const OwnProfile({super.key});
  @override
  Widget build(BuildContext context) {
    final actions = WorkspaceActions.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.profile)),
      body: ProfileScreen(
        userId: context.read<AuthCubit>().state.userId!,
        isMe: true,
        onSignOut: actions.signOut,
        onNotifications: actions.notifications,
      ),
    );
  }
}

class ContactProfile extends StatelessWidget {
  const ContactProfile({
    super.key,
    required this.id,
    this.onChat,
    this.onBack,
    this.onPeer,
    this.mediaTopic,
  });
  final String id;
  final VoidCallback? onChat;
  final VoidCallback? onBack;
  final ValueChanged<String>? onPeer;
  final String? mediaTopic;
  @override
  Widget build(BuildContext context) => BlocProvider(
    key: ValueKey(id),
    create: (_) => locator<ProfileCubit>(param1: id)..load(),
    child: BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed:
                onBack ??
                () => AppNavigation.back(context, fallback: AppRoutes.contacts),
          ),
          title: Text(state.profile?.name ?? context.l10n.profile),
        ),
        body: ProfileScreen(
          userId: id,
          mediaTopic: mediaTopic,
          isMe: id == context.read<AuthCubit>().state.userId,
          onChat:
              onChat ?? () => AppNavigation.open(context, AppRoutes.chat(id)),
          onPeerProfile: (peer) => onPeer != null
              ? onPeer!(peer.id)
              : AppNavigation.open(context, AppRoutes.contact(peer.id)),
        ),
      ),
    ),
  );
}

class ConversationInfo extends StatelessWidget {
  const ConversationInfo({super.key, required this.topic, this.member});
  final String topic;
  final String? member;
  @override
  Widget build(BuildContext context) {
    final id = member != null && AppRoutes.isTopic(member!) ? member! : topic;
    return ContactProfile(
      id: id,
      mediaTopic: id == topic ? topic : null,
      onBack: () => AppNavigation.back(
        context,
        fallback: id == topic ? AppRoutes.chat(topic) : AppRoutes.info(topic),
      ),
      onChat: () => id == topic
          ? AppNavigation.back(
              context,
              fallback: AppRoutes.chat(topic),
              exact: true,
            )
          : AppNavigation.open(context, AppRoutes.chat(id)),
      onPeer: (peer) =>
          AppNavigation.open(context, AppRoutes.info(topic, member: peer)),
    );
  }
}

class ConversationSearch extends StatelessWidget {
  const ConversationSearch({
    super.key,
    required this.topic,
    required this.query,
  });
  final String topic;
  final String query;
  @override
  Widget build(BuildContext context) => BlocProvider(
    key: ValueKey('search:$topic'),
    create: (_) => locator<MessageSearchCubit>(param1: topic),
    child: MessageSearchScreen(
      query: query,
      onBack: () =>
          AppNavigation.back(context, fallback: AppRoutes.chat(topic)),
      onQuery: (query) {
        final uri = GoRouterState.of(context).uri;
        AppNavigation.replace(
          context,
          AppRoutes.withTarget(
            Uri.parse(AppRoutes.search(topic, query: query)),
            message: int.tryParse(uri.queryParameters['message'] ?? ''),
            local: uri.queryParameters['local'],
          ),
        );
      },
      onSelect: (hit) {
        final message = hit.seq > 0 ? hit.seq : null;
        final local = hit.seq > 0 ? null : hit.id;
        if (ConversationPanel.isBesideChat(context)) {
          AppNavigation.replace(
            context,
            AppRoutes.withTarget(
              GoRouterState.of(context).uri,
              message: message,
              local: local,
            ),
          );
        } else {
          AppNavigation.open(
            context,
            AppRoutes.chat(topic, message: message, local: local),
          );
        }
      },
    ),
  );
}
