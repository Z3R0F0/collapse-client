part of 'attachment_view.dart';

extension _AttachmentPlayback on _AttachmentViewState {
  static const _initializationLimit = Duration(seconds: 30);

  bool get _playing =>
      (_audio?.playing == true &&
          _audio?.processingState != ProcessingState.completed) ||
      (_video?.value.isPlaying ?? false);

  bool _canContinue(int operation) =>
      mounted && _foreground && _routeActive && operation == _operation;

  void _suspend() {
    // Invalidate pending user play intent, including a load which finishes after
    // resume. The user can explicitly continue without downloading again.
    _operation++;
    if (_loading) {
      _releasePlayers();
      _update(() => _loading = false);
    } else {
      _audio?.pause().ignore();
      _video?.pause().ignore();
    }
  }

  void _releasePlayers() {
    _audioState?.cancel().ignore();
    _audioErrors?.cancel().ignore();
    _audioState = null;
    _audioErrors = null;
    final audio = _audio;
    final video = _video;
    _audio = null;
    _video = null;
    _videoPresentation = null;
    audio?.dispose().ignore();
    video?.removeListener(_videoChanged);
    video?.dispose().ignore();
  }

  void _fail() {
    _operation++;
    _releasePlayers();
    if (mounted) {
      _update(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  void _videoChanged() {
    if (!mounted || _video == null) return;
    if (_video?.value.hasError ?? false) {
      _fail();
    } else {
      final value = _video!.value;
      final presentation = (
        value.isInitialized,
        value.isPlaying,
        value.isBuffering,
        value.aspectRatio,
      );
      // Video position ticks do not change this control or its layout.
      if (presentation != _videoPresentation) {
        _update(() => _videoPresentation = presentation);
      }
    }
  }

  Future<void> _openAudio(MediaRepository media, int operation) async {
    if (_audio == null) {
      final uri = await _playable(media);
      if (!_canContinue(operation)) return;
      final player = _audio = AudioPlayer();
      _audioState = player.playerStateStream.listen((_) {
        if (mounted && identical(player, _audio)) _update(() {});
      });
      _audioErrors = player.errorStream.listen((_) {
        if (mounted && identical(player, _audio)) _fail();
      });
      await player.setUrl(uri.toString()).timeout(_initializationLimit);
    }
    final player = _audio;
    if (player == null || !_canContinue(operation)) return;
    // just_audio intentionally keeps `playing` true at natural completion.
    if (player.processingState == ProcessingState.completed) {
      await player.pause();
      if (!_canContinue(operation)) return;
      await player.seek(Duration.zero);
    } else if (player.playing) {
      await player.pause();
      return;
    }
    if (!_canContinue(operation) || !identical(player, _audio)) return;
    // play completes on pause/end, not on start. Catch decoder/autoplay errors
    // without holding the control in a loading state for the entire recording.
    unawaited(
      player.play().catchError((Object _) {
        if (mounted && identical(player, _audio)) _fail();
      }),
    );
  }

  Future<void> _openVideo(MediaRepository media, int operation) async {
    if (_video == null) {
      final uri = await _playable(media);
      if (!_canContinue(operation)) return;
      final player = _video = createVideoController(uri);
      player.addListener(_videoChanged);
      await player.initialize().timeout(_initializationLimit);
    }
    final player = _video;
    if (player == null || !_canContinue(operation)) return;
    if (player.value.isPlaying) {
      await player.pause();
    } else {
      await player.play().timeout(_initializationLimit);
      if (!_canContinue(operation)) await player.pause();
    }
  }
}
