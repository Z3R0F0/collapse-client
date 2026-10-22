part of 'attachment_view.dart';

extension _AttachmentBody on _AttachmentViewState {
  Widget _previewFrame(Widget child) => LayoutBuilder(
    builder: (context, constraints) {
      final limit = constraints.hasBoundedWidth
          ? constraints.maxWidth.clamp(0.0, 320.0)
          : 320.0;
      final width = widget.data['width'], height = widget.data['height'];
      final valid =
          width is num &&
          height is num &&
          width.isFinite &&
          height.isFinite &&
          width > 0 &&
          height > 0;
      final size = valid
          ? applyBoxFit(
              BoxFit.contain,
              Size(width.toDouble(), height.toDouble()),
              Size(limit, 320),
            ).destination
          : Size(limit.clamp(0.0, 240.0), limit.clamp(0.0, 240.0) * .75);
      final frame = SizedBox(
        width: size.width,
        height: size.height,
        child: child,
      );
      return widget.heroTag == null
          ? frame
          : Hero(tag: widget.heroTag!, child: frame);
    },
  );

  Widget _buildBody(BuildContext context) {
    if (widget.type == 'IM' && _bytes != null) {
      // Keep late image decoding from moving an already restored chat anchor.
      return _previewFrame(
        FutureBuilder<Uint8List>(
          future: _bytes,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return InkWell(
                onTap: _loading ? null : widget.onPreview ?? _open,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    context.collapseTheme.radius,
                  ),
                  child: Image.memory(
                    snapshot.data!,
                    semanticLabel: _name,
                    cacheWidth: 720,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                ),
              );
            }
            return InkWell(
              onTap: widget.onPreview,
              child: SizedBox(
                height: 90,
                child: Center(
                  child: snapshot.hasError
                      ? IconButton(
                          tooltip: context.l10n.retry,
                          onPressed: () {
                            final bytes = _loadBytes();
                            // FutureBuilder attaches on the next frame; it owns the
                            // error state even if malformed inline data fails now.
                            bytes.ignore();
                            _update(() {
                              _bytes = bytes;
                            });
                          },
                          icon: const Icon(Icons.refresh),
                        )
                      : const CircularProgressIndicator(),
                ),
              ),
            );
          },
        ),
      );
    }
    final playable = widget.type == 'AU' || widget.type == 'VD';
    final action = _loading
        ? context.l10n.loading
        : _failed
        ? context.l10n.retry
        : playable
        ? (_playing ? context.l10n.pause : context.l10n.play)
        : context.l10n.download;
    final buffering =
        _playing &&
        (_audio?.processingState == ProcessingState.buffering ||
            (_video?.value.isBuffering ?? false));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.type == 'VD')
          _previewFrame(
            // Decoder initialization must not move the visible chat anchor.
            GestureDetector(
              onTap: widget.onPreview,
              child: Center(
                child: _video?.value.isInitialized ?? false
                    ? AspectRatio(
                        aspectRatio: _video!.value.aspectRatio,
                        child: VideoPlayer(_video!),
                      )
                    : const Icon(Icons.videocam_outlined),
              ),
            ),
          ),
        Semantics(
          button: true,
          enabled: !_loading,
          onTap: _loading ? null : _open,
          label: '$action: $_name',
          excludeSemantics: true,
          child: Tooltip(
            message: '$action: $_name',
            child: InkWell(
              onTap: _loading ? null : _open,
              borderRadius: BorderRadius.circular(context.collapseTheme.radius),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _loading || buffering
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _failed
                                ? Icons.refresh
                                : playable
                                ? (_playing
                                      ? Icons.pause_circle_outline
                                      : Icons.play_circle_outline)
                                : Icons.attach_file,
                          ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _failed ? context.l10n.retry : _name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
