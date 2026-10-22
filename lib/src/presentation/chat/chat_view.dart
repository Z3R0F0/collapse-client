part of 'chat_screen.dart';

extension _ChatView on _ChatScreenState {
  Widget _buildView(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: widget.onBack == null
          ? null
          : BackButton(onPressed: widget.onBack),
      title: InkWell(
        onTap: widget.onProfile,
        borderRadius: BorderRadius.circular(context.collapseTheme.radius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: context.l10n.searchMessages,
          onPressed: _searchMessages,
          icon: const Icon(Icons.search),
        ),
      ],
    ),
    body: BlocListener<ChatCubit, ChatState>(
      listener: (_, state) => _changed(state),
      child: Stack(
        key: _viewport,
        children: [
          ui.Chat(
            currentUserId: widget.userId,
            chatController: _controller,
            theme: chat.ChatTheme.fromThemeData(Theme.of(context)),
            resolveUser: (id) async {
              try {
                final profile = await context.read<ProfileRepository>().get(id);
                return chat.User(id: id, name: profile.name);
              } catch (_) {
                return chat.User(id: id, name: id);
              }
            },
            onMessageSend: _send,
            onAttachmentTap: _attach,
            onMessageLongPress:
                (context, message, {required index, required details}) =>
                    _actions(message.metadata!['message'] as ChatMessage),
            builders: chat.Builders(
              customMessageBuilder:
                  (
                    context,
                    message,
                    index, {
                    required isSentByMe,
                    groupStatus,
                  }) => DraftyContent(
                    message: message.metadata!['message'] as ChatMessage,
                    isMe: isSentByMe,
                    onPreview: (entity) => AppNavigation.media(
                      context,
                      MediaItem.fromMessage(
                        message.metadata!['message'] as ChatMessage,
                        entity,
                      ),
                    ),
                    heroTagFor: (entity) => MediaItem.fromMessage(
                      message.metadata!['message'] as ChatMessage,
                      entity,
                    ).heroTag('chat'),
                    onReply: () {
                      final data = message.metadata!['message'] as ChatMessage;
                      final seq = int.tryParse('${data.head['reply']}');
                      if (seq != null) _navigateTo(seq);
                    },
                  ),
              chatMessageBuilder: _buildBubble,
              chatAnimatedListBuilder: (_, itemBuilder) => Builder(
                builder: (context) => _buildMessageList(context, itemBuilder),
              ),
              composerBuilder: _buildComposer,
            ),
          ),
          if (_renderState.loading)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(minHeight: 1),
            ),
          if (_renderState.error != null)
            Align(
              alignment: Alignment.topCenter,
              child: TextButton(
                onPressed: _latest,
                child: Text(context.l10n.retry),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _buildMessageList(BuildContext context, chat.ChatItem itemBuilder) {
    final state = _renderState;
    final inset =
        context.watch<ui.ComposerHeightNotifier>().height +
        MediaQuery.paddingOf(context).bottom;
    final span = state.window?.span;
    return Stack(
      fit: StackFit.expand,
      children: [
        MessageList(
          messages: _controller.messages,
          itemBuilder: itemBuilder,
          controller: _scroll,
          canLoadOlder: state.hasOlder,
          canLoadNewer: state.hasNewer,
          atLatest: state.atLiveEdge,
          onLoadOlder: _cubit.loadOlder,
          onLoadNewer: _cubit.loadNewer,
          onFollowingChanged: _followingChanged,
          onVisibleIds: _cubit.setVisibleMessages,
          olderPageKey: span,
          newerPageKey: span,
          navigationEpoch: state.navigationEpoch,
          targetId: state.targetId,
          rebaseAnchorId: _rebaseForFrame(state),
          rowPresentation: (
            _highlightedId,
            _initialRead,
            _appActive,
            _arrivals.isEmpty,
          ),
          navigating: state.loading,
          bottomInset: inset,
          empty: state.loading
              ? const SizedBox.shrink()
              : Center(
                  child: Text(switch (state.error) {
                    null => context.l10n.emptyMessages,
                    'message_unavailable' => context.l10n.messageUnavailable,
                    _ => context.l10n.connectionError,
                  }),
                ),
        ),
        // Overlay controls never resize the viewport. Latest is a repository
        // navigation intent, not a pixel scroll to the current window's end.
        // A later DB write may precede its window event while we're following.
        // Availability alone is not a user request to leave the live tail.
        if (!_following)
          PositionedDirectional(
            end: 16,
            bottom: inset + 12,
            child: FilledButton.tonalIcon(
              key: const ValueKey('latest-messages'),
              onPressed: state.loading ? null : _latest,
              icon: const Icon(Icons.arrow_downward, size: 18),
              label: Text(
                state.unreadCount > 0
                    ? context.l10n.newMessages(state.unreadCount)
                    : context.l10n.latestMessages,
              ),
            ),
          ),
      ],
    );
  }
}
