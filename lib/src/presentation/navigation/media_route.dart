import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/media/media_gallery_repository.dart';
import '../media/media_gallery_cubit.dart';
import '../media/media_viewer.dart';
import 'app_navigation.dart';
import 'app_routes.dart';

/// A root PageRoute leaves the source chat/profile mounted for Hero and Back.
class MediaRoute extends StatefulWidget {
  const MediaRoute({
    super.key,
    required this.topic,
    required this.uri,
    required this.extra,
    required this.fromInfo,
  });
  final String topic;
  final Uri uri;
  final Object? extra;
  final bool fromInfo;
  @override
  State<MediaRoute> createState() => _MediaRouteState();
}

class _MediaRouteState extends State<MediaRoute> {
  late final MediaGalleryCubit _gallery;
  @override
  void initState() {
    super.initState();
    final kind = widget.uri.queryParameters['kind'];
    final category =
        MediaCategory.values.where((k) => k.name == kind).firstOrNull ??
        MediaCategory.visual;
    _gallery = MediaGalleryCubit(
      context.read<MediaGalleryRepository>(),
      widget.topic,
      category,
    );
    _openTarget();
  }

  @override
  void didUpdateWidget(covariant MediaRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri == widget.uri) return;
    final query = widget.uri.queryParameters;
    final current = _gallery.state.current;
    // Carousel URL replacements already describe the selected item. External
    // navigation must instead load the requested cursor, without a scroll jump.
    if (current != null &&
        current.entityIndex == int.tryParse(query['entity'] ?? '0') &&
        (current.pending
            ? current.messageId == query['pending']
            : current.seq == int.tryParse(query['seq'] ?? ''))) {
      return;
    }
    _openTarget();
  }

  void _openTarget() {
    final seq = int.tryParse(widget.uri.queryParameters['seq'] ?? '') ?? 0;
    final entity =
        int.tryParse(widget.uri.queryParameters['entity'] ?? '') ?? 0;
    MediaItem? seed;
    final extra = widget.extra;
    if (extra is Map && extra['media'] is Map) {
      try {
        final candidate = MediaItem.fromJson(
          widget.topic,
          extra['media'] as Map,
        );
        if (candidate.category == _gallery.category &&
            candidate.entityIndex == entity &&
            (candidate.seq == seq ||
                candidate.messageId == widget.uri.queryParameters['pending'])) {
          seed = candidate;
        }
      } catch (_) {
        /* A restored URL never depends on ephemeral route data. */
      }
    }
    _gallery.open(
      seed: seed,
      around: seq > 0 ? MediaCursor(seq, entity) : null,
      pendingId: widget.uri.queryParameters['pending'],
      entityIndex: entity,
    );
  }

  void _close() => AppNavigation.back(
    context,
    fallback: widget.fromInfo
        ? AppRoutes.info(widget.topic)
        : AppRoutes.chat(widget.topic),
  );

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _gallery,
    child: MediaViewer(
      heroSurface: widget.fromInfo ? 'atlas' : 'chat',
      onClose: _close,
      onCurrentChanged: (item) => AppNavigation.replace(
        context,
        AppRoutes.withTarget(
          Uri.parse(
            AppRoutes.media(
              widget.topic,
              seq: item.seq,
              entity: item.entityIndex,
              pending: item.pending ? item.messageId : null,
              fromInfo: widget.fromInfo,
              kind: item.category.name,
            ),
          ),
          message: int.tryParse(widget.uri.queryParameters['message'] ?? ''),
          local: widget.uri.queryParameters['local'],
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _gallery.close();
    super.dispose();
  }
}
