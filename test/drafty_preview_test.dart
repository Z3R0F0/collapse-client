import 'package:collapse/core/database/app_database.dart';
import 'package:collapse_tinode/tinode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'chat list previews the actual reply instead of the old quoted text',
    () {
      final reply = DraftyCodec.reply(
        content: DraftyCodec.markdown('**new reply**'),
        quote: 'old message',
        authorId: 'usrA',
        authorName: 'Alice',
      );
      expect(AppDatabase.preview(reply), 'new reply');
    },
  );

  test('chat list excludes hidden text and reconstructs line breaks', () {
    expect(
      AppDatabase.preview({
        'txt': 'secret visible next',
        'fmt': [
          {'tp': 'HD', 'at': 0, 'len': 7},
          {'tp': 'BR', 'at': 14, 'len': 1},
        ],
      }),
      'visible\nnext',
    );
  });

  test(
    'attachment-only chat list previews retain the existing glyph fallback',
    () {
      final image = DraftyCodec.media(
        type: 'IM',
        ref: '',
        name: 'a.png',
        mime: 'image/png',
        size: 10,
      );
      expect(AppDatabase.preview(image), '📷');
    },
  );
}
