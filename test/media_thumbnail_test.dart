import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:collapse/src/presentation/chat/image_dimensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('preview is bounded PNG without altering original dimensions', () async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(
      recorder,
    ).drawPaint(ui.Paint()..color = const ui.Color(0xff776655));
    final picture = recorder.endRecording();
    final image = await picture.toImage(800, 400);
    final encoded = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final original = encoded.buffer.asUint8List();
    image.dispose();
    picture.dispose();
    final thumbnail = await imageThumbnail(original);
    expect(thumbnail, isNotNull);
    expect(thumbnail!.length, lessThanOrEqualTo(16384));
    expect(await imageDimensions(base64Decode(thumbnail)), (
      width: 64,
      height: 32,
    ));
    expect(await imageDimensions(original), (width: 800, height: 400));
  });
  test('unsupported bytes safely omit a preview', () async {
    expect(await imageThumbnail(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
