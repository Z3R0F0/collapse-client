import 'dart:typed_data';

import 'package:video_player/video_player.dart';

import '../../data/media/media_repository.dart';
import 'video_controller.dart';

/// Best-effort local metadata; unsupported videos still enter the outbox.
Future<({int width, int height, int duration})?> videoMetadata(
  Uint8List bytes,
  String mime,
  MediaRepository media,
) async {
  VideoPlayerController? controller;
  var expired = false;
  Future<({int width, int height, int duration})?> read() async {
    final uri = await media.playableBytes(bytes, mime);
    if (expired) return null;
    final player = controller = createVideoController(
      uri,
      // This controller never plays. Avoid a lifecycle observer that the plugin
      // cannot release if native creation itself fails or never completes.
      options: VideoPlayerOptions(allowBackgroundPlayback: true),
    );
    await player.initialize();
    if (expired) return null;
    final value = player.value;
    final size = value.size;
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width < 1 ||
        size.height < 1) {
      return null;
    }
    return (
      width: size.width.round(),
      height: size.height.round(),
      // Web streams/MediaRecorder files may report the plugin's unset sentinel.
      duration: value.duration.isNegative ? 0 : value.duration.inMilliseconds,
    );
  }

  try {
    return await read().timeout(const Duration(seconds: 3));
  } catch (_) {
    return null;
  } finally {
    expired = true;
    // The plugin waits for native creation before disposing. A stalled platform
    // must not stall enqueue; late creation is still owned by this disposal.
    controller?.dispose().ignore();
  }
}
