import 'package:collapse/src/presentation/chat/message_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_test/flutter_test.dart';

import 'support/message_list_fixture.dart';

void main() {
  Future<_ResponsiveMessagesState> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey<_ResponsiveMessagesState>();
    await tester.pumpWidget(_ResponsiveMessages(key: key));
    await tester.pumpAndSettle();
    return key.currentState!;
  }

  Finder row(String id) =>
      find.byKey(ValueKey('responsive-$id'), skipOffstage: false);

  testWidgets('responsive width keeps a partially clipped message anchor', (
    tester,
  ) async {
    final state = await mount(tester);
    final listState = tester.state(find.byType(MessageList));
    state.controller.sliverController.jumpToIndex(63, offset: -47);
    await tester.pumpAndSettle();
    final anchor = state.visible.first;
    final before = tester.getRect(row(anchor));
    final viewportTop = tester.getTopLeft(find.byType(MessageList)).dy;
    expect(anchor, '64');
    expect(before.top, closeTo(viewportTop - 47, .5));
    expect(before.bottom, greaterThan(viewportTop));

    for (final width in [390.0, 840.0, 1280.0, 500.0, 390.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 860);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(MessageList)), same(listState));
      expect(state.visible.first, anchor, reason: 'width=$width');
      expect(
        tester.getTopLeft(row(anchor)).dy,
        closeTo(before.top, .5),
        reason:
            'Wrapping width=$width must retain the painted stable key '
            'and clipped offset, not only the ScrollPosition pixels.',
      );
      if (width == 390) {
        expect(tester.getSize(row(anchor)).height, greaterThan(before.height));
      }
    }
    expect(state.pages, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('width checkpoint preserves an ongoing drag and its next delta', (
    tester,
  ) async {
    final state = await mount(tester);
    final gesture = await tester.startGesture(const Offset(700, 300));
    await gesture.moveBy(const Offset(0, -47));
    await tester.pump();
    final anchor = state.visible.first;
    final before = tester.getTopLeft(row(anchor)).dy;
    tester.view.physicalSize = const Size(390, 860);
    await tester.pump();
    expect(state.visible.first, anchor);
    expect(tester.getTopLeft(row(anchor)).dy, closeTo(before, .5));
    expect(state.controller.position.isScrollingNotifier.value, isTrue);
    await gesture.moveBy(const Offset(0, -19));
    await tester.pump();
    expect(tester.getTopLeft(row(anchor)).dy, closeTo(before - 19, .5));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.pages, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('latest follows the bottom after responsive text reflow', (
    tester,
  ) async {
    final state = await mount(tester);
    state.latest();
    await tester.pumpAndSettle();
    for (final width in [390.0, 1280.0, 840.0]) {
      tester.view.physicalSize = Size(width, 860);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(row('120')).dy,
        closeTo(tester.getBottomLeft(find.byType(MessageList)).dy - 88, .5),
      );
      expect(state.following.last, isTrue);
    }
    expect(state.pages, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hidden width change never restores a previous navigation anchor',
    (tester) async {
      final state = await mount(tester);
      state.controller.sliverController.jumpToIndex(63, offset: -47);
      await tester.pumpAndSettle();
      expect(state.visible.first, '64');
      state.change(() {
        state.hidden = true;
        state.target = '66';
        state.epoch++;
      });
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(390, 860);
      await tester.pumpAndSettle();
      state.change(() => state.hidden = false);
      await tester.pumpAndSettle();
      expect(state.visible.first, '66');
      expect(
        tester.getTopLeft(row('66')).dy,
        closeTo(tester.getTopLeft(find.byType(MessageList)).dy, .5),
      );
      expect(state.pages, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

class _ResponsiveMessages extends StatefulWidget {
  const _ResponsiveMessages({super.key});

  @override
  State<_ResponsiveMessages> createState() => _ResponsiveMessagesState();
}

class _ResponsiveMessagesState extends State<_ResponsiveMessages> {
  final controller = FlutterListViewController();
  final messages = [
    for (final id in messagePage(1))
      chat.Message.custom(id: '$id', authorId: 'peer'),
  ];
  Set<String> visible = {};
  int pages = 0;
  int epoch = 0;
  bool atLatest = false;
  bool hidden = false;
  String target = '64';
  final following = <bool>[];

  void change(VoidCallback action) => setState(action);

  void latest() => setState(() {
    epoch++;
    atLatest = true;
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('Conversation')),
      body: LayoutBuilder(
        builder: (context, constraints) => Padding(
          padding: EdgeInsets.only(left: constraints.maxWidth >= 840 ? 320 : 0),
          child: Offstage(
            offstage: hidden,
            child: MessageList(
              messages: messages,
              controller: controller,
              canLoadOlder: true,
              canLoadNewer: !atLatest,
              atLatest: atLatest,
              navigationEpoch: epoch,
              targetId: atLatest ? null : target,
              bottomInset: 88,
              onLoadOlder: () async => pages++,
              onLoadNewer: () async => pages++,
              onFollowingChanged: following.add,
              onVisibleIds: (ids) => visible = ids,
              itemBuilder:
                  (
                    context,
                    message,
                    index,
                    animation, {
                    messagesGroupingMode,
                    messageGroupingTimeoutInSeconds,
                    isRemoved,
                  }) => Padding(
                    key: ValueKey('responsive-${message.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(message.id, style: const TextStyle(fontSize: 12)),
                        Text(
                          List.filled(
                            3 + index % 5,
                            'A variable length message must keep its visible anchor '
                            'when the available conversation width changes.',
                          ).join(' '),
                          style: const TextStyle(fontSize: 16, height: 1.3),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
