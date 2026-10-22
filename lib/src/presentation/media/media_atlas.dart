import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../core/theme.dart';
import '../../../widgets/view_activity.dart';
import '../../data/media/media_gallery_repository.dart';
import '../navigation/app_navigation.dart';
import 'media_gallery_cubit.dart';
import 'media_tile.dart';

/// A lazy sliver grid in the conversation profile, not a nested shrink-wrap list.
class MediaAtlas extends StatefulWidget {
  const MediaAtlas({super.key, required this.topic});
  final String topic;
  @override
  State<MediaAtlas> createState() => _MediaAtlasState();
}

class _MediaAtlasState extends State<MediaAtlas> {
  final _galleries = <MediaCategory, MediaGalleryCubit>{};
  MediaCategory _category = MediaCategory.visual;
  MediaGalleryCubit get _gallery => _galleries.putIfAbsent(
    _category,
    () => MediaGalleryCubit(
      context.read<MediaGalleryRepository>(),
      widget.topic,
      _category,
    )..open(),
  );
  @override
  Widget build(BuildContext context) {
    final gallery = _gallery;
    return BlocBuilder<MediaGalleryCubit, MediaGalleryState>(
      bloc: gallery,
      builder: (context, state) {
        final items = state.items.reversed.toList();
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.mediaGallery,
                            style: context.textStyles.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: context.l10n.refresh,
                          onPressed: state.busy ? null : gallery.refresh,
                          icon: const Icon(Icons.refresh, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<MediaCategory>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: MediaCategory.visual,
                          label: Text(context.l10n.mediaVisual),
                        ),
                        ButtonSegment(
                          value: MediaCategory.audio,
                          label: Text(context.l10n.mediaAudio),
                        ),
                        ButtonSegment(
                          value: MediaCategory.files,
                          label: Text(context.l10n.mediaFiles),
                        ),
                      ],
                      selected: {_category},
                      onSelectionChanged: (value) =>
                          setState(() => _category = value.single),
                    ),
                    if (state.offline)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          context.l10n.mediaCached,
                          style: context.textStyles.labelSmall,
                        ),
                      ),
                    if (state.loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(minHeight: 1),
                      ),
                    if (state.error)
                      TextButton(
                        onPressed: gallery.refresh,
                        child: Text(context.l10n.retry),
                      ),
                    if (!state.loading && !state.error && items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          context.l10n.mediaEmpty,
                          style: context.textStyles.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) => MediaTile(
                  key: ValueKey(items[index].id),
                  item: items[index],
                  gallery: gallery,
                  onOpen: () => AppNavigation.media(
                    context,
                    items[index],
                    surface: 'atlas',
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: state.loadingOlder
                    ? const Center(child: CircularProgressIndicator())
                    : state.hasOlder
                    ? VisibilityDetector(
                        key: ValueKey((
                          'media-edge',
                          widget.topic,
                          _category,
                          items.lastOrNull?.id,
                        )),
                        onVisibilityChanged: (info) {
                          if (mounted &&
                              info.visibleFraction > 0 &&
                              ViewActivity.isActiveOf(context) &&
                              !gallery.state.error &&
                              !gallery.isClosed) {
                            gallery.older();
                          }
                        },
                        child: OutlinedButton.icon(
                          onPressed: gallery.older,
                          icon: const Icon(Icons.south, size: 16),
                          label: Text(context.l10n.olderResults),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    for (final gallery in _galleries.values) {
      gallery.close();
    }
    super.dispose();
  }
}
