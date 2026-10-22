part of 'chat_screen.dart';

extension _ChatReceipts on _ChatScreenState {
  void _markVisibleNow() {
    if (!mounted ||
        !_appActive ||
        !_viewActive ||
        _updating ||
        _jumping ||
        !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    final viewport = _viewport.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    final top = viewport.localToGlobal(Offset.zero).dy;
    var bottom = top + viewport.size.height;
    final composer = _composer.currentContext?.findRenderObject();
    if (composer is RenderBox && composer.hasSize) {
      final composerTop = composer.localToGlobal(Offset.zero).dy;
      if (composerTop < bottom) bottom = composerTop;
    }
    if (bottom <= top) return;
    var visibleSeq = _lastVisibleRead;
    for (final message in _shown) {
      if (message.senderId == widget.userId ||
          message.seq <= visibleSeq ||
          _isEntering(message.id)) {
        continue;
      }
      final box = _keys[message.id]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || box.size.height <= 0) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      final visible =
          (y + box.size.height).clamp(top, bottom) - y.clamp(top, bottom);
      if (visible / box.size.height > .5 || visible > 120) {
        visibleSeq = message.seq;
      }
    }
    if (visibleSeq > _lastVisibleRead) {
      _lastVisibleRead = visibleSeq;
      _cubit.markVisible(visibleSeq);
    }
  }
}
