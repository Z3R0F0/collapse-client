part of 'chat_screen.dart';

extension _ChatActions on _ChatScreenState {
  Future<void> _actions(ChatMessage message) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in [
              if (message.seq > 0) ('reply', context.l10n.reply),
              ('copy', context.l10n.copy),
              if (message.seq > 0) ('forward', context.l10n.forward),
              if (message.delivery == Delivery.failed)
                ('retry', context.l10n.retry),
              ('delete', context.l10n.deleteForMe),
              if (message.senderId == widget.userId && message.seq > 0)
                ('deleteAll', context.l10n.deleteForEveryone),
            ])
              ListTile(
                title: Text(item.$2),
                onTap: () => Navigator.pop(context, item.$1),
              ),
          ],
        ),
      ),
    );
    if (!mounted ||
        action == null ||
        _repository.currentUserId != widget.userId) {
      return;
    }
    try {
      switch (action) {
        case 'reply':
          _update(() {
            _draftRevision++;
            _reply = message;
          });
        case 'copy':
          await Clipboard.setData(
            ClipboardData(text: DraftyCodec.copyText(message.content)),
          );
        case 'retry':
          await _repository.retry(message.id);
        case 'delete' || 'deleteAll':
          await _repository.deleteMessage(
            message,
            forEveryone: action == 'deleteAll',
          );
        case 'forward':
          final topics = await _repository.watchTopics().first;
          if (!mounted) return;
          final target = await showModalBottomSheet<String>(
            context: context,
            builder: (context) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(title: Text(context.l10n.selectChat)),
                  for (final topic in topics)
                    ListTile(
                      title: Text(topic.title),
                      onTap: () => Navigator.pop(context, topic.id),
                    ),
                ],
              ),
            ),
          );
          if (target != null &&
              mounted &&
              _repository.currentUserId == widget.userId) {
            await _repository.send(
              target,
              DraftyCodec.forward(message.content),
              head: {'forwarded': '${message.topicId}:${message.seq}'},
            );
          }
      }
    } catch (_) {
      _error();
    }
  }
}
