part of 'media_viewer.dart';

extension _MediaViewerPaging on _MediaViewerState {
  void _ensureNeighbour() {
    final state = _gallery.state;
    if (_initialEdgeRequested ||
        state.busy ||
        state.items.length != 1 ||
        (!state.hasOlder && !state.hasNewer)) {
      return;
    }
    _initialEdgeRequested = true;
    // At most one initial probe. Empty/filtered pages cannot silently drain
    // history; another explicit edge drag or desktop arrow permits progress.
    scheduleMicrotask(() {
      if (mounted && !_closing) {
        unawaited(state.hasOlder ? _gallery.older() : _gallery.newer());
      }
    });
  }

  bool _edgeScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.horizontal) return false;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _requestedEdge = null;
    }
    double? beyond;
    if (notification is OverscrollNotification &&
        notification.dragDetails != null) {
      beyond = notification.overscroll;
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      final metrics = notification.metrics;
      if (metrics.pixels < metrics.minScrollExtent) {
        beyond = metrics.pixels - metrics.minScrollExtent;
      } else if (metrics.pixels > metrics.maxScrollExtent) {
        beyond = metrics.pixels - metrics.maxScrollExtent;
      }
    }
    if (beyond == null || _closing || _positioning) return false;
    final state = _gallery.state;
    if (state.busy ||
        (_images[state.currentId]?.currentState?.isZoomed ?? false)) {
      return false;
    }
    final direction = beyond < 0 ? -1 : 1;
    final index = state.items.indexWhere((item) => item.id == state.currentId);
    final canLoad = direction < 0
        ? index == 0 && state.hasOlder
        : index == state.items.length - 1 && state.hasNewer;
    if (!canLoad || direction == _requestedEdge) return false;
    _requestedEdge = direction;
    unawaited(direction < 0 ? _gallery.older() : _gallery.newer());
    return false;
  }
}
