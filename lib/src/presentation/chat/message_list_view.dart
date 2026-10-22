part of 'message_list.dart';

extension _MessageListView on _MessageListState {
  Widget _buildList() {
    final ids = _rows.value.map((message) => message.id).toList();
    if (_list != null &&
        _list!.controller == widget.controller &&
        _listPosition == _positionEpoch &&
        listEquals(_listIds, ids)) {
      return _list!;
    }
    _listIds = ids;
    _listPosition = _positionEpoch;
    // Upstream rebuilds its sliver even for an unchanged delegate. Retain that
    // widget across loading/receipt/highlight changes; only rows need updating.
    return _list = FlutterListView(
      controller: widget.controller,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      delegate: FlutterListViewDelegate(
        (context, index) {
          final id = ids[index];
          return ValueListenableBuilder<List<chat.Message>>(
            key: ValueKey(id),
            valueListenable: _rows,
            builder: (context, messages, _) {
              final current = messages.indexWhere(
                (message) => message.id == id,
              );
              if (current < 0) return const SizedBox.shrink();
              return widget.itemBuilder(
                context,
                messages[current],
                current,
                const AlwaysStoppedAnimation(1),
              );
            },
          );
        },
        childCount: ids.length,
        onItemKey: (index) => ids[index],
        keepPosition: true,
        keepPositionOffset: 0,
        disableCacheItems: true,
        initIndex: _initialIndex,
        initOffset: _initialOffset,
        initOffsetBasedOnBottom: _alignBottom,
        forceToExecuteInitIndex: _positionEpoch,
      ),
    );
  }
}
