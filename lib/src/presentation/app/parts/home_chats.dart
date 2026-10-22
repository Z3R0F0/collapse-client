part of '../home_screen.dart';

extension _HomeChats on _HomeScreenState {
  Widget _buildChats(
    BuildContext context, {
    bool compact = false,
  }) => BlocBuilder<ChatsCubit, List<ChatTopic>>(
    builder: (context, topics) => topics.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: compact
                  ? Tooltip(
                      message: context.l10n.emptyChats,
                      child: const Icon(Icons.forum_outlined),
                    )
                  : Text(context.l10n.emptyChats),
            ),
          )
        : RefreshIndicator(
            onRefresh: () async {
              try {
                await _chats.refresh();
              } catch (_) {
                _showError();
              }
            },
            child: ListView.separated(
              key: const PageStorageKey('chats-list'),
              itemCount: topics.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, indent: compact ? 16 : 76, endIndent: 16),
              itemBuilder: (context, index) {
                final topic = topics[index];
                return PeerTile(
                  key: ValueKey(topic.id),
                  name: topic.title,
                  avatar: topic.avatarRef,
                  preview: topic.lastPreview,
                  unread: topic.unreadCount,
                  compact: compact,
                  selected:
                      widget.uri.pathSegments.elementAtOrNull(1) == topic.id,
                  location: AppRoutes.chat(topic.id),
                );
              },
            ),
          ),
  );
}
