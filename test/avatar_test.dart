import 'dart:convert';
import 'dart:typed_data';
import 'package:collapse/core/theme.dart';
import 'package:collapse/src/data/media/media_repository.dart';
import 'package:collapse/widgets/avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Media implements MediaRepository {
  _Media(this.value);
  final Uint8List value;
  final requests = <String>[];
  @override
  Future<Uint8List> bytes(String reference) async {
    requests.add(reference);
    return value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> mount(WidgetTester tester, _Media media, {String? ref}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.dark),
          home: Scaffold(
            body: Center(
              child: Avatar(name: 'Ada', media: media, ref: ref),
            ),
          ),
        ),
      );

  testWidgets('photo retains its media reference and bounded frame', (
    tester,
  ) async {
    final media = _Media(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jR1cAAAAASUVORK5CYII=',
      ),
    );
    await mount(tester, media, ref: '/photo');
    await tester.pumpAndSettle();
    expect(media.requests, ['/photo']);
    expect(find.byType(Image), findsOneWidget);
    expect(
      (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes,
      media.value,
    );
    expect(tester.getSize(find.byType(Avatar)), const Size(44, 44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing photo uses an initial without requesting media', (
    tester,
  ) async {
    final media = _Media(Uint8List(0));
    await mount(tester, media);
    expect(media.requests, isEmpty);
    expect(find.text('A'), findsOneWidget);
    expect(tester.getSize(find.byType(Avatar)), const Size(44, 44));
    expect(tester.takeException(), isNull);
  });
}
