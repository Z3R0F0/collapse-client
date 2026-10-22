import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme.dart';
import '../../../widgets/view_activity.dart';
import '../../data/media/media_repository.dart';
import '../../domain/chat/media_models.dart';
import '../chat/attachment_mime.dart';
import '../chat/video_controller.dart';

class MediaViewerVideo extends StatefulWidget {
  const MediaViewerVideo({
    super.key,
    required this.item,
    required this.heroTag,
    required this.load,
  });
  final MediaItem item;
  final Object heroTag;
  final Future<Uint8List> Function() load;

  @override
  State<MediaViewerVideo> createState() => MediaViewerVideoState();
}

class MediaViewerVideoState extends State<MediaViewerVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? _player;
  bool _loading = false;
  bool _failed = false;
  bool _active = true;
  bool _foreground = true;
  int _operation = 0;
  (bool, bool, bool, bool)? _presentation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _active =
        ViewActivity.isActiveOf(context) &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (!_active) _suspend();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _suspend();
  }

  bool _valid(int operation) =>
      mounted && _active && _foreground && operation == _operation;

  void _suspend() {
    _operation++;
    if (_loading) {
      final player = _player;
      _player = null;
      player?.removeListener(_changed);
      player?.dispose().ignore();
      setState(() => _loading = false);
    } else {
      _player?.pause().ignore();
    }
  }

  void _changed() {
    final value = _player?.value;
    if (!mounted || value == null) return;
    final next = (
      value.isInitialized,
      value.isPlaying,
      value.isBuffering,
      value.hasError,
    );
    if (next != _presentation) setState(() => _presentation = next);
  }

  Future<void> toggle() async {
    if (_loading || !_active || !_foreground) return;
    if (_player?.value.hasError ?? false) {
      final player = _player;
      _player = null;
      player?.removeListener(_changed);
      player?.dispose().ignore();
    }
    final operation = ++_operation;
    final media = context.read<MediaRepository>();
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      if (_player == null) {
        final bytes = await widget.load();
        if (!_valid(operation)) return;
        final uri = await media.playableBytes(
          bytes,
          normalizeAttachmentMime(
            widget.item.data['name']?.toString() ?? '',
            widget.item.data['mime']?.toString() ?? 'video/mp4',
          ),
        );
        if (!_valid(operation)) return;
        final player = _player = createVideoController(uri);
        player.addListener(_changed);
        await player.initialize().timeout(const Duration(seconds: 30));
      }
      if (!_valid(operation)) return;
      final player = _player!;
      if (player.value.isPlaying) {
        await player.pause();
      } else {
        if (player.value.position >= player.value.duration) {
          await player.seekTo(Duration.zero);
        }
        if (!_valid(operation)) return;
        await player.play().timeout(const Duration(seconds: 30));
        if (!_valid(operation)) await player.pause();
      }
    } catch (_) {
      if (_valid(operation)) {
        final player = _player;
        _player = null;
        player?.removeListener(_changed);
        player?.dispose().ignore();
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && operation == _operation) setState(() => _loading = false);
    }
  }

  Widget _body(BuildContext context, VideoPlayerValue? value) => Column(
    children: [
      Expanded(
        child: Hero(
          tag: widget.heroTag,
          child: Center(
            child: value?.isInitialized == true
                ? AspectRatio(
                    aspectRatio: value!.aspectRatio,
                    child: VideoPlayer(_player!),
                  )
                : const Icon(
                    Icons.videocam_outlined,
                    color: Colors.white,
                    size: 64,
                  ),
          ),
        ),
      ),
      if (value?.isInitialized == true)
        VideoProgressIndicator(
          _player!,
          allowScrubbing: _active && !_loading,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      IconButton(
        tooltip: _failed || value?.hasError == true
            ? context.l10n.retry
            : value?.isPlaying == true
            ? context.l10n.pause
            : context.l10n.play,
        onPressed: _loading ? null : toggle,
        color: Colors.white,
        icon: _loading
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(),
              )
            : Icon(
                _failed || value?.hasError == true
                    ? Icons.refresh
                    : value?.isPlaying == true
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => _body(context, _player?.value);

  @override
  void dispose() {
    _operation++;
    WidgetsBinding.instance.removeObserver(this);
    _player?.removeListener(_changed);
    _player?.dispose().ignore();
    super.dispose();
  }
}
