import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collapse/core/config.dart';
import 'package:collapse/core/theme.dart';
import 'package:collapse/l10n/app_localizations.dart';
import 'package:collapse/src/data/media/media_repository.dart';
import 'package:collapse/src/presentation/chat/drafty_content.dart';
import 'package:collapse_tinode/tinode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

const _pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jR1cAAAAASUVORK5CYII=';

class _Media extends MediaRepository {
  _Media(TinodeGateway gateway)
    : super(
        AppConfig(
          endpoint: Uri.parse('wss://chat.test/v0/channels'),
          apiKey: 'test',
        ),
        gateway,
        cache: _NoCache(),
      );
  final requested = <String>[];
  final opened = <String>[];
  bool failBytes = false;
  Completer<Uint8List>? delayedBytes;
  @override
  Future<Uint8List> bytes(String ref) async {
    requested.add(ref);
    if (delayedBytes != null) return delayedBytes!.future;
    if (failBytes) {
      throw StateError('Intercept download before native save dialog');
    }
    return super.bytes(ref);
  }

  @override
  Future<Uri> playable(String ref, String mime) async {
    opened.add(ref);
    throw StateError('Intercept source before native media decoder');
  }
}

class _NoCache implements BaseCacheManager {
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late TinodeGateway gateway;
  late _Media media;
  setUp(() {
    gateway = TinodeGateway(
      endpoint: Uri.parse('https://chat.test'),
      apiKey: 'test',
    );
    media = _Media(gateway);
  });
  tearDown(() async {
    await media.dispose();
    await gateway.dispose();
  });

  Future<void> mount(
    WidgetTester tester,
    String type,
    Map<String, dynamic> data,
  ) async {
    await tester.pumpWidget(
      RepositoryProvider<MediaRepository>.value(
        value: media,
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: AttachmentView(type: type, data: data),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('inline image renders decoded bytes without a remote ref', (
    tester,
  ) async {
    await mount(tester, 'IM', {'val': _pixel, 'mime': 'image/png'});
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).semanticLabel, 'Photo');
    expect(media.requested, hasLength(1));
    expect(
      Uri.parse(media.requested.single).data!.contentAsBytes(),
      base64Decode(_pixel),
    );
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final type in ['AU', 'VD']) {
    testWidgets('inline $type reaches media playback with correct bytes', (
      tester,
    ) async {
      await mount(tester, type, {
        'val': 'AQID',
        'mime': type == 'AU' ? 'audio/wav' : 'video/mp4',
      });
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(media.opened, hasLength(1));
      expect(Uri.parse(media.opened.single).data!.contentAsBytes(), [1, 2, 3]);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('late image decode preserves the message preview extent', (
    tester,
  ) async {
    media.delayedBytes = Completer<Uint8List>();
    await mount(tester, 'IM', {'val': _pixel, 'mime': 'image/png'});
    final before = tester.getSize(find.byType(AttachmentView));
    media.delayedBytes!.complete(base64Decode(_pixel));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AttachmentView)), before);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline file reaches download with correct bytes', (
    tester,
  ) async {
    media.failBytes = true;
    await mount(tester, 'EX', {
      'val': 'AQID',
      'mime': 'application/octet-stream',
      'name': 'file.bin',
    });
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(Uri.parse(media.requested.single).data!.contentAsBytes(), [1, 2, 3]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'invalid inline image is a safe retry state, not a build exception',
    (tester) async {
      await mount(tester, 'IM', {'val': 'not base64!', 'mime': 'image/png'});
      await tester.pumpAndSettle();
      expect(find.byTooltip('Retry'), findsOneWidget);
      expect(media.requested, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Retry'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
