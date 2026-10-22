part of 'chat_screen.dart';

extension _ChatMotion on _ChatScreenState {
  void _captureArrivals(ChatState state) {
    final visible = state.messages.map((message) => message.id).toSet();
    final now = clock.now();
    _arrivals.removeWhere(
      (id, entered) =>
          !visible.contains(id) ||
          now.difference(entered) >= MessageArrival.duration,
    );
    // Mounting a screen is a snapshot, even if its Cubit already received data.
    if (!_presented) {
      _presented = true;
      return;
    }
    if (!_appActive ||
        !_viewActive ||
        state.loading ||
        MediaQuery.disableAnimationsOf(context) ||
        !(ModalRoute.isCurrentOf(context) ?? true)) {
      return;
    }
    for (final id in state.arrivalIds) {
      if (visible.contains(id) && _arrivals.length < WindowPolicy.capacity) {
        _arrivals.putIfAbsent(id, () => now);
      }
    }
  }

  bool _isEntering(String id) {
    final entered = _arrivals[id];
    return entered != null &&
        clock.now().difference(entered) < MessageArrival.duration;
  }

  void _arrivalSettled(String id, DateTime? entered) {
    if (_arrivals[id] == entered) _arrivals.remove(id);
    _markVisibleNow();
  }

  Widget _animatedBubble(
    BuildContext context,
    String id,
    bool isMe,
    Widget child,
  ) {
    final entered = _arrivals[id];
    return MessageArrival(
      enteredAt: entered,
      isMe: isMe,
      onSettled: () => _arrivalSettled(id, entered),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.collapseTheme.radius),
          border: Border.all(
            color: _highlightedId == id
                ? context.colors.primary
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: child,
      ),
    );
  }
}
