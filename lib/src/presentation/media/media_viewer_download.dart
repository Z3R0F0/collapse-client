import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../domain/chat/media_models.dart';

/// Saving remains separate from viewer navigation and uses the existing cache.
class MediaViewerDownload extends StatefulWidget {
  const MediaViewerDownload({
    super.key,
    required this.item,
    required this.active,
    required this.load,
  });
  final MediaItem item;
  final bool active;
  final Future<Uint8List> Function() load;
  @override
  State<MediaViewerDownload> createState() => _MediaViewerDownloadState();
}

class _MediaViewerDownloadState extends State<MediaViewerDownload> {
  bool _busy = false, _failed = false;

  Future<void> _save() async {
    if (_busy || !widget.active) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final bytes = await widget.load();
      if (!mounted || !widget.active) return;
      await FilePicker.saveFile(
        fileName: widget.item.data['name']?.toString() ?? 'attachment',
        bytes: bytes,
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: _failed ? context.l10n.retry : context.l10n.save,
    onPressed: _busy || !widget.active ? null : _save,
    icon: _busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(_failed ? Icons.refresh : Icons.download_outlined),
  );
}
