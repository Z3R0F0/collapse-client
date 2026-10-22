part of 'message_list.dart';

extension _MessageListPaging on _MessageListState {
  void _reportFollowing() {
    if (!mounted || widget.navigating || !widget.controller.hasClients) return;
    final following =
        (widget.atLatest || _following) &&
        widget.controller.position.extentAfter < 80;
    _following = following;
    if (following == _reportedFollowing) return;
    _reportedFollowing = following;
    widget.onFollowingChanged(following);
  }

  bool _onScroll(ScrollNotification event) {
    if (event.depth != 0) return false;
    if (event is ScrollStartNotification && event.dragDetails != null ||
        event is UserScrollNotification &&
            event.direction != ScrollDirection.idle) {
      if (!_userScrolling || event is ScrollStartNotification) {
        _requestedPages.clear();
        _pagingOlder = null;
      }
      _userScrolling = !widget.navigating;
    }
    if (event is ScrollEndNotification) _userScrolling = false;
    _reportFollowing();
    if (!_userScrolling || widget.navigating) return false;
    final delta = switch (event) {
      ScrollUpdateNotification() => event.scrollDelta ?? 0,
      OverscrollNotification() => event.overscroll,
      _ => 0.0,
    };
    // Suppress unchanged progress only within this gesture and direction. A
    // rejected/error page can be retried, including reversal while it awaited.
    if (delta != 0 && _pagingOlder != (delta < 0)) {
      _pagingOlder = delta < 0;
      _requestedPages.clear();
    }
    if (_loadingPage) return false;
    // Begin bounded work while there is still room to scroll during its I/O.
    final prefetchDistance = event.metrics.viewportDimension * 2;
    if (delta < 0 &&
        widget.canLoadOlder &&
        event.metrics.extentBefore < prefetchDistance) {
      unawaited(
        _load(
          true,
          widget.olderPageKey ?? widget.messages.firstOrNull?.id,
          widget.onLoadOlder,
        ),
      );
    } else if (delta > 0 &&
        widget.canLoadNewer &&
        event.metrics.extentAfter < prefetchDistance) {
      unawaited(
        _load(
          false,
          widget.newerPageKey ?? widget.messages.lastOrNull?.id,
          widget.onLoadNewer,
        ),
      );
    }
    return false;
  }

  Future<void> _load(
    bool older,
    Object? edge,
    Future<void> Function() load,
  ) async {
    if (_requestedPages.containsKey(older) && _requestedPages[older] == edge) {
      return;
    }
    _requestedPages[older] = edge;
    _loadingPage = true;
    try {
      await load();
    } finally {
      _loadingPage = false;
    }
  }
}
