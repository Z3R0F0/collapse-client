part of 'chat_screen.dart';

extension _ChatNavigation on _ChatScreenState {
  Future<void> _searchMessages() async {
    if (widget.onSearch != null) {
      widget.onSearch!();
      return;
    }
    final hit = await Navigator.of(context).push<SearchHit>(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => locator<MessageSearchCubit>(param1: widget.topicId),
          child: const MessageSearchScreen(),
        ),
      ),
    );
    if (mounted && hit != null) await _jumpTo(hit.seq, id: hit.id);
  }

  Future<void> _navigateTo(int seq, {String? id}) async {
    final navigate = widget.onMessageTarget;
    if (navigate == null || _linkedTarget == (seq, id)) {
      await _jumpTo(seq, id: id);
    } else {
      navigate(seq, id);
    }
  }

  void _latest() {
    _linkedTarget = null;
    widget.onClearTarget?.call();
    unawaited(_cubit.jumpToLatest());
  }

  Future<void> _jumpTo(int seq, {String? id}) async {
    if (seq <= 0 && id == null) return;
    bool matches(ChatMessage message) =>
        id != null ? message.id == id : message.seq == seq;
    final generation = ++_jumpGeneration;
    _highlightTimer?.cancel();
    if (_highlightedId != null) _update(() => _highlightedId = null);
    _jumping = true;
    _cubit.setFollowingLive(false);
    bool active() => mounted && generation == _jumpGeneration;
    try {
      // Every explicit jump supplies a ready snapshot and an initial index.
      // It never scrolls through intermediate history or triggers pagination.
      await _cubit.open(
        widget.topicId,
        aroundSeq: id == null ? seq : null,
        aroundId: id,
      );
      if (!mounted || !active() || _cubit.state.loading) return;
      _changed(_cubit.state);
      await _rendered;
      if (!mounted || !active()) return;
      final target = _shown.where(matches).firstOrNull;
      if (target == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.messageUnavailable)),
        );
        return;
      }
      if (!active()) return;
      _highlightTimer?.cancel();
      _update(() => _highlightedId = target.id);
      _highlightTimer = Timer(const Duration(milliseconds: 900), () {
        if (active()) _update(() => _highlightedId = null);
      });
    } catch (_) {
      if (active()) _error();
    } finally {
      if (active()) {
        _jumping = false;
        _markVisibleNow();
      }
    }
  }
}
