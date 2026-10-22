import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';

/// Read encoded metadata, not a decoded frame held until the upload completes.
Future<({int width, int height})?> imageDimensions(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      return (width: descriptor.width, height: descriptor.height);
    } finally {
      descriptor.dispose();
    }
  } catch (_) {
    // Unsupported images remain ordinary attachments with stable fallback size.
    return null;
  } finally {
    buffer.dispose();
  }
}

/// A tiny canonical in-band preview; the original still uses durable outbox/ref.
Future<String?> imageThumbnail(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final largest = descriptor.width > descriptor.height
          ? descriptor.width
          : descriptor.height;
      final scale = largest > 64 ? 64 / largest : 1.0;
      final codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round().clamp(1, 64),
        targetHeight: (descriptor.height * scale).round().clamp(1, 64),
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (data == null || data.lengthInBytes > 12288) return null;
          return base64Encode(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
    }
  } catch (_) {
    return null;
  } finally {
    buffer.dispose();
  }
}
