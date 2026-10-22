part of 'media_viewer.dart';

extension _MediaViewerControls on _MediaViewerState {
  void _zoom(double factor) =>
      _images[_gallery.state.currentId]?.currentState?.zoom(factor);

  Widget _toolbar(BuildContext context, MediaGalleryState state, bool mobile) {
    final item = state.items
        .where((item) => item.id == state.currentId)
        .firstOrNull;
    final title =
        item?.data['name']?.toString() ??
        switch (item?.type) {
          'IM' => context.l10n.photo,
          'VD' => context.l10n.video,
          'AU' => context.l10n.audio,
          _ => context.l10n.file,
        };
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Material(
          color: Colors.black.withValues(alpha: .7),
          child: IconButtonTheme(
            data: IconButtonThemeData(
              style: (IconButtonTheme.of(context).style ?? const ButtonStyle())
                  .copyWith(
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.disabled)
                          ? Colors.white38
                          : Colors.white,
                    ),
                  ),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: context.l10n.close,
                  onPressed: _close,
                  icon: const Icon(Icons.close),
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.labelLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                if (state.loadingOlder || state.loadingNewer)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (item != null && item.visual)
                  MediaViewerDownload(
                    key: ValueKey(item.id),
                    item: item,
                    active: !_closing,
                    load: () => _gallery.bytes(item),
                  ),
                if (!mobile && item?.type == 'IM') ...[
                  IconButton(
                    tooltip: context.l10n.zoomOut,
                    onPressed: () => _zoom(.5),
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    tooltip: context.l10n.resetZoom,
                    onPressed: () => _zoom(0),
                    icon: const Icon(Icons.center_focus_strong),
                  ),
                  IconButton(
                    tooltip: context.l10n.zoomIn,
                    onPressed: () => _zoom(2),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _arrows(BuildContext context, MediaGalleryState state) {
    final index = state.items.indexWhere((item) => item.id == state.currentId);
    return [
      for (final direction in [-1, 1])
        Positioned(
          left: direction < 0 ? 8 : null,
          right: direction > 0 ? 8 : null,
          top: 72,
          bottom: 24,
          child: Center(
            child: IconButton.filledTonal(
              tooltip: direction < 0
                  ? MaterialLocalizations.of(context).previousPageTooltip
                  : MaterialLocalizations.of(context).nextPageTooltip,
              onPressed:
                  index >= 0 &&
                      (direction < 0
                          ? index > 0 || state.hasOlder
                          : index < state.items.length - 1 || state.hasNewer)
                  ? () => _move(direction)
                  : null,
              icon: Icon(
                direction < 0 ? Icons.chevron_left : Icons.chevron_right,
              ),
            ),
          ),
        ),
    ];
  }
}
