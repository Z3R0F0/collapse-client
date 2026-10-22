import 'dart:async';
import 'package:collapse/core/config.dart';
import 'package:collapse/core/theme.dart';
import 'package:collapse/l10n/app_localizations.dart';
import 'package:collapse/src/data/media/media_repository.dart';
import 'package:collapse/src/presentation/chat/attachment_view.dart';
import 'package:collapse/widgets/view_activity.dart';
import 'package:collapse_tinode/tinode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

class AttachmentMedia extends MediaRepository {
  AttachmentMedia()
    : super(
        AppConfig(
          endpoint: Uri.parse('wss://chat.test/v0/channels'),
          apiKey: 'test',
        ),
        TinodeGateway(endpoint: Uri.parse('wss://chat.test'), apiKey: 'test'),
        cache: _NoCache(),
      );
  int resolutions = 0;
  Completer<Uri>? delayedSource;
  @override
  Future<Uri> playable(String ref, String mime) async {
    resolutions++;
    if (delayedSource != null) return delayedSource!.future;
    return Uri.parse('file:///attachment');
  }

  @override
  Future<void> dispose() async {
    await gateway.dispose();
  }
}

class _NoCache implements BaseCacheManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> mountAttachment(
  WidgetTester tester,
  AttachmentMedia media,
  String type, {
  ValueNotifier<bool>? activity,
}) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('com.ryanheise.audio_session'),
        (_) async => null,
      );
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
            child: SizedBox(
              width: 240,
              child: ValueListenableBuilder<bool>(
                valueListenable: activity ?? const AlwaysStoppedAnimation(true),
                builder: (_, active, child) =>
                    ViewActivity(active: active, child: child!),
                child: AttachmentView(
                  type: type,
                  data: {
                    'ref': '/v0/file/s/media',
                    'mime': type == 'AU' ? 'audio/wav' : 'video/mp4',
                    'name': 'sample',
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> tapAttachment(WidgetTester tester) async {
  await tester.tap(find.byType(InkWell));
  await flushAttachment(tester);
}

Future<void> flushAttachment(WidgetTester tester) async {
  // Platform interfaces/streams can complete in the outer test zone. Flush both
  // event loops without waiting for a deliberately blocked native initialization.
  for (var frame = 0; frame < 12; frame++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

Future<void> settleAttachment(WidgetTester tester) async {
  await flushAttachment(tester);
  await tester.pumpAndSettle();
}

Future<void> unmountAttachment(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await settleAttachment(tester);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}
