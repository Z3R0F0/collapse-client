part of 'message_list.dart';

extension _MessageListVisibility on _MessageListState {
  void _trackVisible(List<chat.Message> snapshot) {
    widget
        .controller
        .sliverController
        .onPaintItemPositionsCallback = (height, positions) {
      // Upstream reports painted rows at frame end. Never apply indices from a
      // previous snapshot to a new message window.
      if (!mounted || !identical(snapshot, widget.messages)) return;
      final visible = <String>{};
      _paintedAnchor = null;
      for (final item in positions) {
        if (item.index < 0 ||
            item.index >= snapshot.length ||
            item.height <= 0 ||
            item.offset >= height ||
            item.offset + item.height <= 0) {
          continue;
        }
        final id = snapshot[item.index].id;
        _paintedAnchor ??= (id: id, offset: item.offset);
        visible.add(id);
      }
      if (setEquals(visible, _visibleIds) &&
          visible.firstOrNull == _visibleIds.firstOrNull) {
        return;
      }
      _visibleIds = visible;
      widget.onVisibleIds?.call(Set.unmodifiable(visible));
    };
  }
}
