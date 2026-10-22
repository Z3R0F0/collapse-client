part of 'chat_screen.dart';

extension _ChatSubmit on _ChatScreenState {
  Future<void> _send(String _) async {
    if (!mounted || _repository.currentUserId != widget.userId) return;
    final draft = _input.value;
    if (draft.text.trim().isEmpty) return;
    final userId = widget.userId;
    final session = _repository.sessionGeneration;
    final topicId = widget.topicId;
    final messenger = ScaffoldMessenger.of(context);
    final errorText = context.l10n.operationError;
    final retryText = context.l10n.retry;
    final reply = _reply;
    try {
      // Validate/convert before clearing. Each invocation owns its own text and
      // reply: a later keystroke can never change this send's wire payload.
      Object content = DraftyCodec.markdown(draft.text);
      final head = <String, dynamic>{};
      if (reply != null) {
        content = DraftyCodec.reply(
          content: content,
          quote: reply.content,
          authorId: reply.senderId,
          authorName: reply.senderId,
        );
        head['reply'] = reply.seq;
      }
      void offerRetry() {
        if (!messenger.mounted) return;
        // Retain the immutable failed intent in the standard messenger action,
        // even after this route closes. Storage failure is not crash-proof.
        messenger.showSnackBar(
          SnackBar(
            content: Text(errorText),
            duration: const Duration(days: 1),
            action: SnackBarAction(
              label: retryText,
              onPressed: () async {
                // An explicit retry may use a new session of the same account,
                // never the account which replaced it. Leave newer drafts alone.
                if (_repository.currentUserId != userId) return;
                try {
                  await _repository.send(topicId, content, head: head);
                } catch (_) {
                  offerRetry();
                }
              },
            ),
          ),
        );
      }

      // Calling send captures the repository/session and schedules the local
      // transaction synchronously. Route disposal cannot cancel that intent.
      final committed = _cubit.send(content, head: head, clearDraft: true);
      _draftTimer?.cancel();
      _draftTimer = null;
      _suppressDraftSave = true;
      _input.clear();
      _suppressDraftSave = false;
      final clearedRevision = _draftRevision;
      if (reply != null) _update(() => _reply = null);
      try {
        await committed;
      } catch (_) {
        final canRestore =
            mounted &&
            _repository.currentUserId == userId &&
            _repository.sessionGeneration == session &&
            _draftRevision == clearedRevision &&
            _input.text.isEmpty &&
            _reply == null;
        if (canRestore) {
          _input.value = draft;
          if (reply != null) _update(() => _reply = reply);
          _error();
        } else {
          offerRetry();
        }
      }
    } catch (_) {
      // Synchronous validation failed before ownership moved to the queue.
      _suppressDraftSave = false;
      _error();
    }
  }
}
