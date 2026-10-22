import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import 'media_gallery_cubit.dart';

class MediaTile extends StatefulWidget {
  const MediaTile({
    super.key,
    required this.item,
    required this.gallery,
    required this.onOpen,
  });
  final MediaItem item;
  final MediaGalleryCubit gallery;
  final VoidCallback onOpen;
  @override
  State<MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<MediaTile> {
  Future<Uint8List>? _bytes;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(MediaTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.data['ref'] != widget.item.data['ref'] ||
        (_failed && !identical(oldWidget.item, widget.item))) {
      _bytes = null;
      _prepare();
    }
  }

  void _prepare() {
    // No original inline downloads just to enumerate an archive page.
    _failed = false;
    final preview = widget.item.data['preview'];
    if (widget.item.visual && preview is String && preview.length <= 32768) {
      try {
        final bytes = base64Decode(preview);
        if (bytes.isNotEmpty) {
          _bytes = Future.value(bytes);
          return;
        }
      } on FormatException {
        /* Legacy malformed previews use the original. */
      }
    }
    if (widget.item.type == 'IM' &&
        (widget.item.data['ref']?.toString().isNotEmpty ?? false)) {
      final task = _bytes = widget.gallery.bytes(widget.item);
      task.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_bytes, task)) _failed = true;
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final label =
        item.data['name']?.toString() ??
        switch (item.type) {
          'IM' => context.l10n.photo,
          'VD' => context.l10n.video,
          'AU' => context.l10n.audio,
          _ => context.l10n.file,
        };
    final icon = switch (item.type) {
      'IM' => Icons.image_outlined,
      'VD' => Icons.play_circle_outline,
      'AU' => Icons.graphic_eq,
      _ => Icons.insert_drive_file_outlined,
    };
    final placeholder = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: context.colors.onSurfaceVariant),
          if (!item.visual)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.textStyles.labelSmall,
              ),
            ),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: widget.onOpen,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: InkWell(
          onTap: widget.onOpen,
          borderRadius: BorderRadius.circular(context.collapseTheme.radius),
          child: Hero(
            tag: item.heroTag('atlas'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(context.collapseTheme.radius),
              child: ColoredBox(
                color: context.colors.surfaceContainerHighest,
                child: _bytes == null
                    ? placeholder
                    : FutureBuilder<Uint8List>(
                        future: _bytes,
                        builder: (_, snapshot) => snapshot.hasData
                            ? Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                cacheWidth: 320,
                                excludeFromSemantics: true,
                                errorBuilder: (_, _, _) => placeholder,
                              )
                            : placeholder,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
