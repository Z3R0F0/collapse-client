import 'dart:async';

import 'package:collapse/src/presentation/chat/message_list.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_test/flutter_test.dart';

class _ColdList extends StatefulWidget {
  const _ColdList({super.key});

  @override
  State<_ColdList> createState() => _ColdListState();
}

class _ColdListState extends State<_ColdList> {
  final controller = FlutterListViewController();
  final page = Completer<void>();
  final messages = [
    for (var id = 561; id <= 600; id++)
      chat.Message.custom(
        id: '$id',
        authorId: 'peer',
        metadata: const {'delivery': 'queued'},
      ),
  ];
  bool loading = false;
  int olderCalls = 0;

  void rebuild({required bool changeContent}) => setState(() {
    loading = true;
    if (changeContent) {
      // The real controller also mutates its exposed list in place.
      messages[3] = messages[3].copyWith(metadata: {'delivery': 'sent'});
    }
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: MessageList(
        messages: messages,
        controller: controller,
        canLoadOlder: !loading,
        canLoadNewer: false,
        atLatest: true,
        onFollowingChanged: (_) {},
        onLoadOlder: () async {
          olderCalls++;
          await page.future;
        },
        onLoadNewer: () async {},
        itemBuilder:
            (
              context,
              message,
              index,
              animation, {
              messagesGroupingMode,
              messageGroupingTimeoutInSeconds,
              isRemoved,
            }) => SizedBox(
              key: ValueKey(message.id),
              height: message.id == '561'
                  ? 112
                  : message.id == '600'
                  ? 350
                  : 72 + (int.parse(message.id) % 7) * 46,
              child: Text('${message.id} ${message.metadata!['delivery']}'),
            ),
      ),
    ),
  );

  @override
  void dispose() {
    if (!page.isCompleted) page.complete();
    controller.dispose();
    super.dispose();
  }
}

Map<String, Rect> _painted(WidgetTester tester) => {
  for (var id = 561; id <= 600; id++)
    if (find.byKey(ValueKey('$id'), skipOffstage: false).evaluate().isNotEmpty)
      '$id': tester.getRect(
        find.byKey(ValueKey('$id'), skipOffstage: false).last,
      ),
};

void main() {
  for (final changeContent in [false, true]) {
    testWidgets(
      '${changeContent ? 'same-ID content' : 'loading-only'} rebuild cannot add a cold first-row height delta',
      (tester) async {
        tester.view.physicalSize = const Size(900, 657);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey<_ColdListState>();
        await tester.pumpWidget(_ColdList(key: key));
        await tester.pumpAndSettle();
        final state = key.currentState!;
        var measuredSteps = 0;
        for (var step = 0; step <= 41; step++) {
          final before = _painted(tester);
          final remaining = state.controller.position.extentBefore;
          await tester.sendEventToBinding(
            const PointerScrollEvent(
              position: Offset(400, 300),
              scrollDelta: Offset(0, -180),
            ),
          );
          // Independent of prefetch distance: rebuild at the exact cold boundary
          // from the browser trace, before this wheel step's layout.
          if (step == 41) state.rebuild(changeContent: changeContent);
          await tester.pump();
          final after = _painted(tester);
          for (final entry in before.entries) {
            final next = after[entry.key];
            if (remaining >= 180 &&
                entry.value.top > 0 &&
                entry.value.bottom < 657 &&
                next != null &&
                next.top > 0 &&
                next.bottom < 657) {
              measuredSteps++;
              expect(
                next.top - entry.value.top,
                closeTo(180, .5),
                reason:
                    'step $step, row ${entry.key}, loading=${state.loading}',
              );
            }
          }
        }
        expect(state.olderCalls, 1);
        expect(measuredSteps, greaterThan(0));
        if (changeContent) {
          expect(find.text('564 sent', skipOffstage: false), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
