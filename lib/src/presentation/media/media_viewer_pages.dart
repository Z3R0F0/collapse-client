part of 'media_viewer.dart';

extension _MediaViewerPages on _MediaViewerState {
  Widget _buildPages(
    BuildContext context,
    MediaGalleryState state,
    bool mobile,
  ) {
    Widget content;
    if (state.items.isEmpty) {
      content = Center(
        child: state.loading
            ? const CircularProgressIndicator()
            : TextButton.icon(
                onPressed: _gallery.refresh,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.retry),
              ),
      );
    } else {
      final items = List<MediaItem>.of(state.items);
      content = ExtendedImageGesturePageView.custom(
        key: ObjectKey(_pages),
        controller: _pages,
        onPageChanged: _select,
        childrenDelegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            final selected = item.id == state.currentId;
            final active = selected && !_closing;
            return KeyedSubtree(
              key: ValueKey(item.id),
              child: ViewActivity(
                active: active,
                child: HeroMode(
                  // Pop flights are collected after this closing frame. Pause
                  // playback immediately, but keep its selected Hero eligible.
                  enabled: selected,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      mobile ? 0 : 64,
                      72,
                      mobile ? 0 : 64,
                      24,
                    ),
                    child: _item(context, item, mobile),
                  ),
                ),
              ),
            );
          },
          childCount: items.length,
          findChildIndexCallback: (key) {
            final index = key is ValueKey<String>
                ? items.indexWhere((item) => item.id == key.value)
                : -1;
            return index < 0 ? null : index;
          },
        ),
      );
      content = NotificationListener<ScrollNotification>(
        onNotification: _edgeScroll,
        child: content,
      );
    }
    if (!mobile) {
      return ColoredBox(
        color: Colors.black.withValues(alpha: .94),
        child: content,
      );
    }
    return ExtendedImageSlidePage(
      slideAxis: SlideAxis.vertical,
      slideType: SlideType.onlyImage,
      slidePageBackgroundHandler: (offset, size) => Colors.black.withValues(
        alpha: (1 - offset.dy.abs() / size.height).clamp(.2, 1),
      ),
      slideEndHandler:
          (
            offset, {
            ExtendedImageSlidePageState? state,
            ScaleEndDetails? details,
          }) {
            if (state == null || details == null) return false;
            if (offset.dy.abs() > state.pageSize.height / 5 ||
                (offset.dy.abs() > 48 &&
                    details.velocity.pixelsPerSecond.dy.abs() > 700)) {
              state.popPage();
              _close();
            }
            // Router owns closing; the package must not pop a second route.
            return false;
          },
      child: content,
    );
  }

  Widget _item(BuildContext context, MediaItem item, bool mobile) {
    if (item.type == 'IM') {
      return MediaViewerImage(
        key: _images.putIfAbsent(item.id, GlobalKey<MediaViewerImageState>.new),
        item: item,
        heroTag: item.heroTag(widget.heroSurface),
        mobile: mobile,
        load: () => _gallery.bytes(item),
      );
    }
    if (item.type == 'VD') {
      final video = MediaViewerVideo(
        key: _videos.putIfAbsent(item.id, GlobalKey<MediaViewerVideoState>.new),
        item: item,
        heroTag: item.heroTag(widget.heroSurface),
        load: () => _gallery.bytes(item),
      );
      return mobile ? ExtendedImageSlidePageHandler(child: video) : video;
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: AttachmentView(
              key: ValueKey(item.id),
              type: item.type,
              data: item.data,
              pendingBytes:
                  item.pending ||
                      (item.inline &&
                          (item.data['ref']?.toString().isEmpty ?? true))
                  ? () => _gallery.bytes(item)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
