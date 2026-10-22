import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme.dart';
import '../../../widgets/view_activity.dart';
import '../chat/attachment_view.dart';
import 'media_gallery_cubit.dart';
import 'media_viewer_download.dart';
import 'media_viewer_image.dart';
import 'media_viewer_video.dart';

part 'media_viewer_controls.dart';
part 'media_viewer_pages.dart';
part 'media_viewer_paging.dart';

/// Presentation only: gallery history and authenticated bytes belong to Cubit.
class MediaViewer extends StatefulWidget {
  const MediaViewer({
    super.key,
    required this.heroSurface,
    required this.onClose,
    this.onCurrentChanged,
  });
  final String heroSurface;
  final VoidCallback onClose;
  final ValueChanged<MediaItem>? onCurrentChanged;

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late final MediaGalleryCubit _gallery;
  late ExtendedPageController _pages;
  final _images = <String, GlobalKey<MediaViewerImageState>>{};
  final _videos = <String, GlobalKey<MediaViewerVideoState>>{};
  var _ids = <String>[];
  String? _selectedId;
  (String, int, int)? _reportedCurrent;
  int _revision = 0;
  bool _positioning = false;
  bool _closing = false;
  bool _moving = false;
  bool _initialEdgeRequested = false;
  int? _requestedEdge;

  @override
  void initState() {
    super.initState();
    _gallery = context.read<MediaGalleryCubit>();
    final state = _gallery.state;
    _selectedId = state.currentId;
    final current = state.current;
    if (current != null) {
      _reportedCurrent = (current.id, current.seq, current.entityIndex);
    }
    _ids = state.items.map((item) => item.id).toList();
    final index = _ids.indexOf(state.currentId ?? '');
    _pages = ExtendedPageController(
      initialPage: index < 0 ? 0 : index,
      keepPage: false,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureNeighbour();
    });
  }

  void _sync(MediaGalleryState state) {
    final ids = state.items.map((item) => item.id).toList();
    final index = ids.indexOf(state.currentId ?? '');
    final changedIndex = index != _ids.indexOf(state.currentId ?? '');
    final changedSelection = _selectedId != state.currentId;
    _selectedId = state.currentId;
    _reportCurrent(state.current);
    _ids = ids;
    final nearby = ids.skip((index - 1).clamp(0, ids.length)).take(3).toSet();
    _images.removeWhere((id, _) => !nearby.contains(id));
    _videos.removeWhere((id, _) => !nearby.contains(id));
    _ensureNeighbour();
    if (index < 0 || (!changedIndex && !changedSelection)) return;
    final previous = _pages;
    // A stock controller's initialPage is applied in layout, atomically with
    // the keyed delegate. No wrong-media frame precedes a corrective jump.
    _pages = ExtendedPageController(initialPage: index, keepPage: false);
    _positioning = true;
    final revision = ++_revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      previous.dispose();
      if (mounted && revision == _revision) _positioning = false;
    });
  }

  void _close() {
    if (_closing) return;
    setState(() => _closing = true);
    _revision++;
    widget.onClose();
  }

  void _select(int index) {
    if (_positioning || _closing || index >= _gallery.state.items.length) {
      return;
    }
    final item = _gallery.state.items[index];
    if (item.id == _selectedId) return;
    _selectedId = item.id;
    _gallery.select(item.id);
    _reportCurrent(item);
    if (index < 2 && _gallery.state.hasOlder) unawaited(_gallery.older());
    if (index >= _gallery.state.items.length - 2 && _gallery.state.hasNewer) {
      unawaited(_gallery.newer());
    }
  }

  void _reportCurrent(MediaItem? item) {
    if (item == null || _closing) return;
    final identity = (item.id, item.seq, item.entityIndex);
    if (identity == _reportedCurrent) return;
    _reportedCurrent = identity;
    widget.onCurrentChanged?.call(item);
  }

  Future<void> _move(int delta) async {
    if (_moving || _closing) return;
    _moving = true;
    final id = _gallery.state.currentId;
    try {
      var state = _gallery.state;
      var index = state.items.indexWhere((item) => item.id == id);
      if (index + delta < 0 && state.hasOlder) await _gallery.older();
      if (index + delta >= state.items.length && state.hasNewer) {
        await _gallery.newer();
      }
      if (!mounted || _closing || _gallery.state.currentId != id) return;
      state = _gallery.state;
      index = state.items.indexWhere((item) => item.id == id) + delta;
      if (index < 0 || index >= state.items.length) return;
      // A fetched prepend first retains the old item's page; navigate afterwards.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted ||
          _closing ||
          !_pages.hasClients ||
          _gallery.state.currentId != id) {
        return;
      }
      index = _gallery.state.items.indexWhere((item) => item.id == id) + delta;
      if (index < 0 || index >= _gallery.state.items.length) return;
      await _pages.animateToPage(
        index,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    } finally {
      _moving = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<MediaGalleryCubit, MediaGalleryState>(
        listener: (_, state) => _sync(state),
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) {
            final mobile = constraints.maxWidth < 840;
            return CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): _close,
                const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                    _move(-1),
                const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                    _move(1),
                const SingleActivator(LogicalKeyboardKey.equal): () => _zoom(2),
                const SingleActivator(LogicalKeyboardKey.minus): () =>
                    _zoom(.5),
                const SingleActivator(LogicalKeyboardKey.digit0): () =>
                    _zoom(0),
                const SingleActivator(LogicalKeyboardKey.space): () =>
                    _videos[_gallery.state.currentId]?.currentState?.toggle(),
              },
              child: Focus(
                autofocus: true,
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle.light,
                  child: Material(
                    color: Colors.transparent,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildPages(context, state, mobile),
                        _toolbar(context, state, mobile),
                        if (!mobile) ..._arrows(context, state),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

  @override
  void dispose() {
    _revision++;
    _pages.dispose();
    super.dispose();
  }
}
