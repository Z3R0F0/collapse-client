part of 'chat_screen.dart';

extension _ChatScroll on _ChatScreenState {
  void _followingChanged(bool following) {
    _cubit.setFollowingLive(following);
    if (mounted && _following != following) {
      _update(() => _following = following);
    }
    _markVisibleNow();
  }

  void _changed(ChatState state) {
    _captureArrivals(state);
    if (state.navigationEpoch != _renderState.navigationEpoch) {
      _pendingRebase = null;
      if (!state.loading && state.targetId == null) {
        // Latest can also be requested by a send, without a URL callback.
        // Retire any older target's pending highlight/error continuation.
        _jumpGeneration++;
        _jumping = false;
        _highlightTimer?.cancel();
        _highlightedId = null;
      }
      if (!state.loading &&
          state.targetId == null &&
          (widget.targetSeq != null || widget.targetId != null)) {
        final epoch = state.navigationEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _cubit.state.navigationEpoch == epoch &&
              !_cubit.state.loading &&
              _cubit.state.targetId == null) {
            _linkedTarget = null;
            widget.onClearTarget?.call();
          }
        });
      }
    } else if (state.window?.rebaseAnchorId case final String id
        when !identical(state.window, _renderState.window)) {
      // ACK/receipt snapshots may replace this window before the next frame.
      // Keep only its viewport instruction, never another copy of the rows.
      _pendingRebase = (
        id: id,
        epoch: state.navigationEpoch,
        revision: state.revision,
      );
    }
    _next = state;
    if (!_updating) _rendered = _drain();
  }

  String? _rebaseForFrame(ChatState state) {
    final pending = _pendingRebase;
    if (pending == null ||
        pending.epoch != state.navigationEpoch ||
        pending.revision > state.revision) {
      return null;
    }
    if (!state.messages.any((message) => message.id == pending.id)) {
      _pendingRebase = null;
      return null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pendingRebase == pending) _pendingRebase = null;
    });
    return pending.id;
  }

  /// Adapt domain rows to Flyer without owning a second scroll/anchor state.
  /// Navigation epoch and rows become visible together, after row updates.
  Future<void> _drain() async {
    _updating = true;
    try {
      while (mounted && _next != null) {
        final state = _next!;
        _next = null;
        if (!identical(_shown, state.messages)) {
          final messages = state.messages
              .map(
                (message) => chat.Message.custom(
                  id: message.id,
                  authorId: message.senderId,
                  createdAt: message.createdAt,
                  metadata: {'message': message},
                ),
              )
              .toList();
          final previous = {
            for (final message in _controller.messages) message.id: message,
          };
          // Flyer retains row state by ID. Its update operation refreshes the
          // row content; setMessages alone only changes list structure.
          for (final message in messages) {
            final old = previous[message.id];
            if (old != null && old != message) {
              await _controller.updateMessage(old, message);
            }
          }
          if (!listEquals(
            previous.keys.toList(),
            messages.map((message) => message.id).toList(),
          )) {
            await _controller.setMessages(messages, animated: false);
          }
          if (!mounted) return;
          final ids = messages.map((message) => message.id).toSet();
          _keys.removeWhere((id, _) => !ids.contains(id));
        }
        _update(() {
          if (_renderState.navigationEpoch != state.navigationEpoch) {
            _following = state.targetId == null;
          }
          _shown = state.messages;
          _renderState = state;
        });
      }
    } finally {
      _updating = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _markVisibleNow());
    }
  }
}
