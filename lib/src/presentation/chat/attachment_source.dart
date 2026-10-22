part of 'attachment_view.dart';

extension _AttachmentSource on _AttachmentViewState {
  void _updateSource(AttachmentView oldWidget) {
    Object source(AttachmentView value) =>
        (value.type, value.data['ref'], value.data['val'], value.data['mime']);
    if (source(oldWidget) == source(widget)) return;
    // ACK changes the ref, not the already loaded attachment. Keep the player
    // and bytes for this stable message/entity instead of restarting playback.
    final uploaded =
        oldWidget.pendingBytes != null &&
        (oldWidget.data['ref']?.toString().isEmpty ?? true) &&
        oldWidget.data['val'] == widget.data['val'] &&
        (widget.data['ref']?.toString().isNotEmpty ?? false) &&
        oldWidget.type == widget.type &&
        oldWidget.data['mime'] == widget.data['mime'];
    _resolvedRef = null;
    _bytes = null;
    if (!uploaded) {
      _operation++;
      _queuedBytes = null;
      _releasePlayers();
      _loading = false;
      _failed = false;
    }
    _prepareImage();
  }

  void _prepareImage() {
    if (widget.type == 'IM' &&
        (widget.pendingBytes != null ||
            widget.data['val'] != null ||
            (widget.data['ref']?.toString().isNotEmpty ?? false))) {
      final bytes = _bytes ??= _loadBytes();
      bytes.ignore(); // FutureBuilder attaches during the next build.
    }
  }

  Future<Uint8List?> _loadQueuedBytes() async {
    final load = widget.pendingBytes;
    if (_queuedBytes == null && load == null) return null;
    final task = _queuedBytes ??= load!();
    try {
      final bytes = await task;
      if (bytes == null && identical(_queuedBytes, task)) _queuedBytes = null;
      return bytes;
    } catch (_) {
      if (identical(_queuedBytes, task)) _queuedBytes = null;
      rethrow;
    }
  }

  Future<Uint8List> _loadBytes() async {
    final local = await _loadQueuedBytes();
    if (local != null) return local;
    if (!mounted) throw StateError('Attachment disposed');
    if (_ref.isEmpty) throw const FormatException('Missing attachment');
    return context.read<MediaRepository>().bytes(_ref);
  }

  Future<Uri> _playable(MediaRepository media) async {
    final local = await _loadQueuedBytes();
    if (!mounted) throw StateError('Attachment disposed');
    if (local != null) return media.playableBytes(local, _mime);
    if (_ref.isEmpty) throw const FormatException('Missing attachment');
    return media.playable(_ref, _mime);
  }
}
