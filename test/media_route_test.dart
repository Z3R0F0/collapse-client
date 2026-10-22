import 'dart:convert';

import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:collapse/src/presentation/chat/chat_screen.dart';
import 'package:collapse/src/presentation/media/media_gallery_cubit.dart';
import 'package:collapse/src/presentation/media/media_viewer.dart';
import 'package:collapse/src/presentation/navigation/app_navigation.dart';
import 'package:collapse/src/presentation/navigation/app_routes.dart';
import 'package:collapse/widgets/view_activity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/media_viewer_fixture.dart' show viewerPixel;
import 'support/router_fixture.dart';

void main() {
  testWidgets('media route retains chat across paging, external URL and resize', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(() async => RouterFixture()))!;
    await tester.runAsync(() async {
      await fixture.initialize(location: '/chats/usrPeer');
      for (final seq in [100, 101]) {
        await fixture.db.mergeMessage(
          'local|me',
          ChatMessage(
            id: 'usrPeer:$seq',
            topicId: 'usrPeer',
            seq: seq,
            localSeq: 0,
            senderId: 'peer',
            createdAt: DateTime.utc(2026),
            content: {
              'txt': ' ',
              'fmt': [
                {'at': 0, 'len': 1, 'key': 0},
              ],
              'ent': [
                {
                  'tp': 'IM',
                  'data': {
                    'mime': 'image/png',
                    'val': base64Encode(viewerPixel),
                    'width': 1,
                    'height': 1,
                  },
                },
              ],
            },
          ),
          'me',
        );
      }
    });
    try {
      await fixture.mount(tester);
      final chat = fixture.chats.single;
      final input = find.descendant(
        of: find.byType(ChatScreen),
        matching: find.byType(TextField),
      );
      await tester.enterText(input, 'preserved draft');
      final originalWindow = chat.state.messages.map((m) => m.id).toList();
      final context = tester.element(find.byType(ChatScreen));
      final row = (await tester.runAsync(
        () => fixture.db.messageRow('local|me', 'usrPeer', 100),
      ))!;
      final item = MediaItem.fromMessage(fixture.db.toMessage(row), 0);
      AppNavigation.media(context, item);
      await fixture.pump(tester);
      expect(find.byType(MediaViewer), findsOneWidget);
      final gallery = tester
          .element(find.byType(MediaViewer))
          .read<MediaGalleryCubit>();
      expect(gallery.state.current?.seq, 100);
      expect(ViewActivity.isActiveOf(context), isFalse);
      expect(fixture.chats.single, same(chat));
      expect(chat.state.messages.map((m) => m.id), originalWindow);

      // External URL changes select their cursor, not the previously open item.
      fixture.navigation.router.go(
        AppRoutes.media('usrPeer', seq: 101, entity: 0, kind: 'visual'),
      );
      await fixture.pump(tester);
      expect(
        tester.element(find.byType(MediaViewer)).read<MediaGalleryCubit>(),
        same(gallery),
      );
      expect(gallery.state.current?.seq, 101);
      tester.view.physicalSize = const Size(390, 900);
      await fixture.pump(tester);
      expect(
        tester.element(find.byType(MediaViewer)).read<MediaGalleryCubit>(),
        same(gallery),
      );
      expect(fixture.chats.single, same(chat));
      await tester.tap(find.byTooltip('Close'));
      await fixture.pump(tester);
      expect(fixture.uri.path, '/chats/usrPeer');
      expect(find.byType(MediaViewer), findsNothing);
      expect(
        ViewActivity.isActiveOf(tester.element(find.byType(ChatScreen))),
        isTrue,
      );
      expect(
        tester.widget<TextField>(input).controller!.text,
        'preserved draft',
      );
      expect(chat.opens, 1);
      expect(tester.takeException(), isNull);
    } finally {
      await fixture.dispose(tester);
    }
  });
}
