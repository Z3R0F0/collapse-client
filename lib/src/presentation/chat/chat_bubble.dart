part of 'chat_screen.dart';

extension _ChatBubble on _ChatScreenState {
  Widget _buildBubble(
    BuildContext context,
    chat.Message message,
    int index,
    Animation<double> animation,
    Widget child, {
    bool? isRemoved,
    required bool isSentByMe,
    chat.MessageGroupStatus? groupStatus,
  }) {
    final data = message.metadata!['message'] as ChatMessage;
    final firstUnread =
        _initialRead != null &&
        data.seq > _initialRead! &&
        !isSentByMe &&
        (data.seq == _initialRead! + 1 ||
            (index > 0 && _shown[index - 1].seq <= _initialRead!)) &&
        !_shown
            .take(index)
            .any((m) => m.seq > _initialRead! && m.senderId != widget.userId);
    return VisibilityDetector(
      key: ValueKey('visible-${message.id}'),
      onVisibilityChanged: (_) => _markVisibleNow(),
      child: ui.ChatMessage(
        key: _keys.putIfAbsent(message.id, GlobalKey.new),
        message: message,
        index: index,
        animation: animation,
        isRemoved: isRemoved,
        groupStatus: groupStatus,
        // Index zero becomes an interior row on prepend. Its size is invariant.
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        paddingChangeAnimationDuration: null,
        headerWidget: firstUnread
            ? Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        context.l10n.unreadMessages,
                        style: context.textStyles.labelSmall?.copyWith(
                          color: context.colors.primary,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
              )
            : null,
        topWidget: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.topicId.startsWith('grp') && !isSentByMe)
              ui.Username(userId: data.senderId),
          ],
        ),
        child: _animatedBubble(context, message.id, isSentByMe, child),
      ),
    );
  }
}
