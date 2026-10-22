import 'dart:async';

import 'package:collapse/src/presentation/chat/attachment_bytes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('oversized picker metadata is rejected without subscribing', () async {
    var opened = false;
    final stream = StreamController<List<int>>(onListen: () => opened = true);
    await expectLater(
      readAttachmentBytes(stream.stream, declaredSize: 11, maxBytes: 10),
      throwsA(isA<AttachmentTooLarge>()),
    );
    expect(opened, isFalse);
    unawaited(stream.close());
  });

  test(
    'an understated or growing file is capped and its stream cancelled',
    () async {
      var chunksRead = 0;
      var cancelled = false;
      Stream<List<int>> chunks() async* {
        try {
          for (final bytes in [
            [1, 2, 3],
            [4, 5],
            [6, 7, 8],
          ]) {
            chunksRead++;
            yield bytes;
          }
        } finally {
          cancelled = true;
        }
      }

      await expectLater(
        readAttachmentBytes(chunks(), declaredSize: 1, maxBytes: 4),
        throwsA(isA<AttachmentTooLarge>()),
      );
      expect(chunksRead, 2);
      expect(cancelled, isTrue);
    },
  );

  test('accepted bytes are exact, including a file at the limit', () async {
    final bytes = await readAttachmentBytes(
      Stream.fromIterable([
        [0, 255],
        <int>[],
        [2, 3],
      ]),
      declaredSize: 4,
      maxBytes: 4,
    );
    expect(bytes, [0, 255, 2, 3]);
  });

  test(
    'unknown picker size is validated using actual streamed bytes',
    () async {
      expect(
        await readAttachmentBytes(
          Stream.value([1, 2, 3]),
          declaredSize: 0,
          maxBytes: 4,
        ),
        [1, 2, 3],
      );
    },
  );

  test(
    'file read failures reach the caller for the existing error UI',
    () async {
      final error = StateError('File no longer available');
      await expectLater(
        readAttachmentBytes(Stream.error(error), declaredSize: 1, maxBytes: 4),
        throwsA(same(error)),
      );
    },
  );
}
