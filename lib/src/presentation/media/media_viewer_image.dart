import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../domain/chat/media_models.dart';

class MediaViewerImage extends StatefulWidget {
  const MediaViewerImage({
    super.key,
    required this.item,
    required this.heroTag,
    required this.mobile,
    required this.load,
  });
  final MediaItem item;
  final Object heroTag;
  final bool mobile;
  final Future<Uint8List> Function() load;

  @override
  State<MediaViewerImage> createState() => MediaViewerImageState();
}

class MediaViewerImageState extends State<MediaViewerImage> {
  final _gesture = GlobalKey<ExtendedImageGestureState>();
  late Future<Uint8List> _bytes;

  bool get isZoomed =>
      (_gesture.currentState?.gestureDetails?.totalScale ?? 1) > 1.01;

  @override
  void initState() {
    super.initState();
    _bytes = widget.load();
  }

  void zoom(double factor) {
    final gesture = _gesture.currentState;
    if (gesture == null) return;
    final current = gesture.gestureDetails?.totalScale ?? 1;
    final box = _gesture.currentContext?.findRenderObject();
    gesture.handleDoubleTap(
      scale: factor == 0 ? 1 : (current * factor).clamp(1, 5),
      doubleTapPosition: box is RenderBox
          ? box.localToGlobal(box.size.center(Offset.zero))
          : Offset.zero,
    );
  }

  Widget _hero(Widget child) => Hero(
    tag: widget.heroTag,
    // Keep the actual decoded source visible even when destination bytes are
    // still loading on its mandatory first Hero frame.
    flightShuttleBuilder: (_, _, _, from, _) => (from.widget as Hero).child,
    child: child,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return _hero(
          Center(
            child: snapshot.hasError
                ? TextButton.icon(
                    onPressed: () {
                      final bytes = widget.load();
                      bytes.ignore();
                      setState(() {
                        _bytes = bytes;
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.retry),
                  )
                : const CircularProgressIndicator(),
          ),
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final image = ExtendedImage.memory(
            snapshot.data!,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            fit: BoxFit.contain,
            semanticLabel:
                widget.item.data['name']?.toString() ?? context.l10n.photo,
            mode: ExtendedImageMode.gesture,
            extendedImageGestureKey: _gesture,
            enableSlideOutPage: widget.mobile,
            heroBuilderForSlidingPage: _hero,
            cacheWidth:
                (constraints.maxWidth *
                        MediaQuery.devicePixelRatioOf(context) *
                        2)
                    .round()
                    .clamp(1, 4096),
            initGestureConfigHandler: (_) => GestureConfig(
              inPageView: true,
              minScale: 1,
              maxScale: 5,
              initialScale: 1,
              cacheGesture: false,
            ),
            onDoubleTap: (state) => state.handleDoubleTap(
              scale: (state.gestureDetails?.totalScale ?? 1) > 1.01 ? 1 : 3,
            ),
            loadStateChanged: (state) =>
                state.extendedImageLoadState == LoadState.failed
                ? IconButton(
                    tooltip: context.l10n.retry,
                    onPressed: state.reLoadImage,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                  )
                : null,
          );
          return widget.mobile ? image : _hero(image);
        },
      );
    },
  );
}
