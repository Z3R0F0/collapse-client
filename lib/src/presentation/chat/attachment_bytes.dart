import 'dart:typed_data';

class AttachmentTooLarge implements Exception {
  const AttachmentTooLarge();
}

/// Check picker metadata before opening the file, then bound the actual bytes.
Future<Uint8List> readAttachmentBytes(
  Stream<List<int>> stream, {
  required int declaredSize,
  required int maxBytes,
}) async {
  if (declaredSize > maxBytes) throw const AttachmentTooLarge();
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    if (chunk.length > maxBytes - bytes.length) {
      throw const AttachmentTooLarge();
    }
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}
