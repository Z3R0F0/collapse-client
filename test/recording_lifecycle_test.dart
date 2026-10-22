import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/router_fixture.dart';

class _Recorder {
  Completer<bool>? permission;
  Completer<void>? starting;
  final calls = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<Object?> call(MethodCall call) async {
    calls.add(call.method);
    if (call.method == 'create') {
      final id = (call.arguments as Map)['recorderId'];
      messenger.setMockMethodCallHandler(
        MethodChannel('com.llfbandit.record/events/$id'),
        (_) async => null,
      );
    }
    if (call.method == 'hasPermission') return permission?.future ?? true;
    if (call.method == 'start') await starting?.future;
    return null;
  }

  void release() {
    if (permission case final gate? when !gate.isCompleted) gate.complete(true);
    if (starting case final gate? when !gate.isCompleted) gate.complete();
  }

  int count(String method) => calls.where((value) => value == method).length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void recordingTest(
    String name,
    Future<void> Function(WidgetTester, RouterFixture, _Recorder) body,
  ) {
    testWidgets(name, (tester) async {
      final fixture = (await tester.runAsync(() async => RouterFixture()))!;
      final recorder = _Recorder();
      await tester.runAsync(
        () => fixture.initialize(location: '/chats/usrPeer'),
      );
      recorder.messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => '/tmp',
      );
      try {
        await fixture.mount(tester, recordCall: recorder.call);
        await body(tester, fixture, recorder);
      } finally {
        recorder.release();
        await fixture.pump(tester);
        await fixture.dispose(tester);
        recorder.messenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
      }
    });
  }

  Future<void> record(WidgetTester tester, RouterFixture fixture) async {
    await tester.tap(find.byIcon(Icons.attach_file).last);
    await fixture.pump(tester);
    await tester.tap(find.byIcon(Icons.mic_none));
    await fixture.pump(tester);
  }

  Future<void> hide(WidgetTester tester, RouterFixture fixture) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.people_outline),
      ),
    );
    await fixture.pump(tester);
  }

  recordingTest('hidden chat cancels active recording without timed send', (
    tester,
    fixture,
    recorder,
  ) async {
    await record(tester, fixture);
    expect(recorder.count('start'), 1);
    expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
    await hide(tester, fixture);
    expect(recorder.count('cancel'), 1);
    await tester.pump(const Duration(minutes: 1));
    await fixture.pump(tester);
    expect(recorder.count('stop'), 0);
    final queued = await tester.runAsync(
      () => fixture.db.pendingOutbox('local|me'),
    );
    expect(queued, isEmpty);
  });

  recordingTest('permission completed after hiding cannot start recording', (
    tester,
    fixture,
    recorder,
  ) async {
    recorder.permission = Completer<bool>();
    await record(tester, fixture);
    expect(recorder.count('hasPermission'), 1);
    await hide(tester, fixture);
    recorder.permission!.complete(true);
    await fixture.pump(tester);
    expect(recorder.count('start'), 0);
    expect(recorder.count('stop'), 0);
  });

  recordingTest('held native start is cancelled after hide and not resumed', (
    tester,
    fixture,
    recorder,
  ) async {
    recorder.starting = Completer<void>();
    await record(tester, fixture);
    expect(recorder.count('start'), 1);
    await hide(tester, fixture);
    recorder.starting!.complete();
    await fixture.pump(tester);
    expect(recorder.count('cancel'), 1);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.chat_bubble_outline),
      ),
    );
    await fixture.pump(tester);
    expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
    expect(recorder.count('start'), 1);
  });

  recordingTest('background cancels recording and resume does not restart it', (
    tester,
    fixture,
    recorder,
  ) async {
    await record(tester, fixture);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await fixture.pump(tester);
    expect(recorder.count('cancel'), 1);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await fixture.pump(tester);
    expect(recorder.count('start'), 1);
    expect(recorder.count('stop'), 0);
    expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
  });

  recordingTest('active recording keeps the existing one-minute stop', (
    tester,
    fixture,
    recorder,
  ) async {
    await record(tester, fixture);
    await tester.pump(const Duration(minutes: 1));
    await fixture.pump(tester);
    expect(recorder.count('start'), 1);
    expect(recorder.count('stop'), 1);
    expect(recorder.count('cancel'), 0);
    expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
  });

  recordingTest('first permission grant survives temporary inactive dialog', (
    tester,
    fixture,
    recorder,
  ) async {
    recorder.permission = Completer<bool>();
    await record(tester, fixture);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    recorder.permission!.complete(true);
    await fixture.pump(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await fixture.pump(tester);
    expect(recorder.count('start'), 1);
    expect(recorder.count('cancel'), 0);
    expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
  });
}
