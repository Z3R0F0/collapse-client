import 'dart:convert';
import 'dart:typed_data';

import 'package:collapse/core/theme.dart';
import 'package:collapse/l10n/app_localizations.dart';
import 'package:collapse/src/data/media/media_gallery_repository.dart';
import 'package:collapse/src/data/media/media_repository.dart';
import 'package:collapse/src/presentation/media/media_gallery_cubit.dart';
import 'package:collapse/src/presentation/media/media_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:extended_image/extended_image.dart';

import 'attachment_fixture.dart';

final viewerPixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
);

MediaItem viewerItem(int seq, {String type = 'IM'}) => MediaItem(
  topicId: 'usrPeer',
  messageId: 'm$seq',
  seq: seq,
  entityIndex: 0,
  type: type,
  data: {
    'name': 'item $seq',
    'mime': type == 'VD' ? 'video/mp4' : 'image/png',
    'ref': '/v0/file/s/$seq',
  },
  senderId: 'peer',
  createdAt: DateTime(2026, 9, 22, 12, seq),
);

class _GalleryRepository implements MediaGalleryRepository {
  @override
  String get account => 'me';
  @override
  int get generation => 1;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ViewerCubit extends MediaGalleryCubit {
  ViewerCubit(List<MediaItem> items)
    : super(_GalleryRepository(), 'usrPeer', MediaCategory.visual) {
    emit(MediaGalleryState(items: items, currentId: items.firstOrNull?.id));
  }
  int loads = 0, olderCalls = 0, newerCalls = 0;
  bool failBytes = false;
  Future<Uint8List>? delayed;
  void show(List<MediaItem> items, {String? current}) =>
      emit(state.copyWith(items: items, currentId: current));
  void setEdges({bool older = false, bool newer = false}) =>
      emit(state.copyWith(hasOlder: older, hasNewer: newer));
  @override
  Future<Uint8List> bytes(MediaItem item) async {
    loads++;
    if (failBytes) throw StateError('fixture failure');
    return delayed ?? viewerPixel;
  }

  @override
  Future<void> older() async {
    olderCalls++;
  }

  @override
  Future<void> newer() async {
    newerCalls++;
  }
}

class ViewerMedia extends AttachmentMedia {
  @override
  Future<Uri> playableBytes(Uint8List bytes, String mime) async =>
      Uri.parse('file:///viewer');
}

Future<void> mountViewer(
  WidgetTester tester,
  ViewerCubit gallery,
  ViewerMedia media, {
  double width = 390,
  VoidCallback? onClose,
  ValueChanged<MediaItem>? onCurrentChanged,
  bool settle = true,
}) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  await tester.pumpWidget(
    RepositoryProvider<MediaRepository>.value(
      value: media,
      child: BlocProvider<MediaGalleryCubit>.value(
        value: gallery,
        child: MaterialApp(
          theme: appTheme(Brightness.dark),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaViewer(
            heroSurface: 'chat',
            onClose: onClose ?? () {},
            onCurrentChanged: onCurrentChanged,
          ),
        ),
      ),
    ),
  );
  if (settle) await settleViewer(tester);
}

Future<void> settleViewer(WidgetTester tester) async {
  await flushAttachment(tester);
  // Platform image decoding is real asynchronous work, outside fake timers.
  for (var frame = 0; frame < 40; frame++) {
    final images = tester.stateList(find.byType(ExtendedImage));
    if (!images.any(
      (state) =>
          (state as ExtendedImageState).extendedImageLoadState ==
          LoadState.loading,
    )) {
      break;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> closeViewer(
  WidgetTester tester,
  ViewerCubit gallery,
  ViewerMedia media,
) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
  await gallery.close();
  await media.dispose();
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}
