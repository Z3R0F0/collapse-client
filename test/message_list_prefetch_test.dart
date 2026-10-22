import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/message_list_fixture.dart';

void main() {
  for (final older in [true, false]) {
    testWidgets(
      '${older ? 'older' : 'newer'} prefetch leaves a viewport of runway',
      (tester) async {
        final key = GlobalKey<MessageListFixtureState>();
        await tester.pumpWidget(MessageListFixture(key: key));
        await tester.pumpAndSettle();
        final state = key.currentState!;
        final pending = Completer<void>();
        double? requestedAt;
        Future<void> load() {
          requestedAt = older
              ? state.controller.position.extentBefore
              : state.controller.position.extentAfter;
          return pending.future;
        }

        state.olderAction = older ? load : null;
        state.newerAction = older ? null : load;
        for (var step = 0; step < 300 && requestedAt == null; step++) {
          await tester.sendEventToBinding(
            PointerScrollEvent(
              position: const Offset(400, 300),
              scrollDelta: Offset(0, older ? -64 : 64),
            ),
          );
          await tester.pump();
        }
        expect(requestedAt, isNotNull);
        expect(
          requestedAt,
          greaterThan(state.controller.position.viewportDimension),
        );
        for (var step = 0; step < 5; step++) {
          await tester.sendEventToBinding(
            PointerScrollEvent(
              position: const Offset(400, 300),
              scrollDelta: Offset(0, older ? -64 : 64),
            ),
          );
          await tester.pump();
        }
        expect(state.olderCalls + state.newerCalls, 1);
        pending.complete();
        state.change(() {
          state.older = false;
          state.newer = false;
        });
        await tester.pump();
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: const Offset(400, 300),
            scrollDelta: Offset(0, older ? -2000 : 2000),
          ),
        );
        await tester.pump();
        expect(state.olderCalls + state.newerCalls, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
