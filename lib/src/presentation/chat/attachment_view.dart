import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme.dart';
import '../../../widgets/view_activity.dart';
import '../../data/media/media_repository.dart';
import 'attachment_mime.dart';
import 'video_controller.dart';

part 'attachment_body.dart';
part 'attachment_playback.dart';
part 'attachment_source.dart';

class AttachmentView extends StatefulWidget {
  const AttachmentView({
    super.key,
    required this.type,
    required this.data,
    this.pendingBytes,
    this.onPreview,
    this.heroTag,
  });
  final String type;
  final Map<String, dynamic> data;
  final Future<Uint8List?> Function()? pendingBytes;
  final VoidCallback? onPreview;
  final Object? heroTag;
  @override
  State<AttachmentView> createState() => _AttachmentViewState();
}

class _AttachmentViewState extends State<AttachmentView>
    with WidgetsBindingObserver {
  Future<Uint8List>? _bytes;
  Future<Uint8List?>? _queuedBytes;
  String? _resolvedRef;
  AudioPlayer? _audio;
  VideoPlayerController? _video;
  (bool, bool, bool, double)? _videoPresentation;
  StreamSubscription<PlayerState>? _audioState;
  StreamSubscription<PlayerException>? _audioErrors;
  bool _loading = false;
  bool _failed = false;
  bool _foreground = true;
  bool _routeActive = true;
  int _operation = 0;
  String get _ref => _resolvedRef ??= context
      .read<MediaRepository>()
      .draftyReference(widget.data);
  String get _mime => normalizeAttachmentMime(
    widget.data['name']?.toString() ?? '',
    widget.data['mime']?.toString() ?? 'application/octet-stream',
  );
  String get _name =>
      widget.data['name']?.toString() ??
      switch (widget.type) {
        'AU' => context.l10n.audio,
        'VD' => context.l10n.video,
        'IM' => context.l10n.photo,
        _ => context.l10n.file,
      };

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
    final active =
        (ModalRoute.isCurrentOf(context) ?? true) &&
        ViewActivity.isActiveOf(context);
    if (_routeActive && !active) _suspend();
    _routeActive = active;
    _prepareImage();
  }

  @override
  void didUpdateWidget(AttachmentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateSource(oldWidget);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _suspend();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _operation++;
    _releasePlayers();
    super.dispose();
  }

  Future<void> _open() async {
    if (_loading || !_foreground || !_routeActive) return;
    final operation = ++_operation;
    final media = context.read<MediaRepository>();
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      if (widget.type == 'AU') {
        await _openAudio(media, operation);
      } else if (widget.type == 'VD') {
        await _openVideo(media, operation);
      } else {
        final bytes = await _loadBytes();
        if (!_canContinue(operation)) return;
        await FilePicker.saveFile(
          fileName: widget.data['name']?.toString() ?? 'attachment',
          bytes: bytes,
        );
      }
    } catch (_) {
      if (mounted && operation == _operation) _fail();
    } finally {
      if (mounted && operation == _operation) setState(() => _loading = false);
    }
  }

  void _update(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) => _buildBody(context);
}
