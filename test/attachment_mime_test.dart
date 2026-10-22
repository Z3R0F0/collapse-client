import 'package:collapse/src/presentation/chat/attachment_mime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // EBML's shared container signature does not identify audio vs video.
  const ebml = [0x1a, 0x45, 0xdf, 0xa3, 0xa3, 0x42, 0x86, 0x81, 1];
  test('WebM and Matroska use only recognized container extensions', () {
    expect(attachmentMime('movie.webm', ebml), 'video/webm');
    expect(attachmentMime('VOICE.WEBA', ebml), 'audio/webm');
    expect(attachmentMime('movie.mkv', ebml), 'video/x-matroska');
    expect(attachmentMime('voice.mka', ebml), 'audio/x-matroska');
  });
  test(
    'unknown or disguised EBML is not declared an image or arbitrary type',
    () {
      for (final name in ['clip', 'clip.bin', 'clip.jpg', 'clip.mp4']) {
        expect(attachmentMime(name, ebml), 'application/octet-stream');
      }
    },
  );
  test('all other signatures retain priority over the extension', () {
    expect(attachmentMime('fake.webm', [0xff, 0xd8, 0xff]), 'image/jpeg');
    expect(
      attachmentMime('fake.jpg', [0x25, 0x50, 0x44, 0x46]),
      'application/pdf',
    );
    expect(attachmentMime('ordinary.mp4', []), 'video/mp4');
    expect(attachmentMime('unknown', []), isNull);
  });
  test('stored legacy WebM MIME is normalized for playback too', () {
    expect(normalizeAttachmentMime('old.webm', 'audio/weba'), 'video/webm');
    expect(normalizeAttachmentMime('old.weba', 'audio/weba'), 'audio/webm');
    expect(normalizeAttachmentMime('old.jpg', 'image/png'), 'image/png');
    expect(
      normalizeAttachmentMime('old.jpg', 'audio/weba'),
      'application/octet-stream',
    );
  });
}
