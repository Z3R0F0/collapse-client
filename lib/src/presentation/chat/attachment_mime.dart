import 'package:mime/mime.dart';

String? attachmentMime(String name, List<int> bytes) {
  final detected = lookupMimeType(name, headerBytes: bytes);
  return detected == null ? null : normalizeAttachmentMime(name, detected);
}

/// mime 2.1 labels the shared EBML signature `audio/weba`. Only a recognized
/// container extension can disambiguate it; all other headers keep priority.
String normalizeAttachmentMime(String name, String mime) {
  if (mime != 'audio/weba') return mime;
  final container = lookupMimeType(name);
  return const {
        'video/webm',
        'audio/webm',
        'video/x-matroska',
        'audio/x-matroska',
      }.contains(container)
      ? container!
      : 'application/octet-stream';
}
