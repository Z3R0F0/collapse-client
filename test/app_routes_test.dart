import 'package:collapse/src/presentation/navigation/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'panel target edits retain query/member and clear only target fields',
    () {
      for (final location in [
        AppRoutes.search('usrPeer', query: 'Привет world'),
        AppRoutes.info('grpGroup', member: 'usrPeer'),
      ]) {
        final original = Uri.parse(location);
        final queued = Uri.parse(
          AppRoutes.withTarget(original, local: 'draft-1'),
        );
        expect(queued.path, original.path);
        expect(queued.queryParameters, {
          ...original.queryParameters,
          'local': 'draft-1',
        });
        final accepted = Uri.parse(
          AppRoutes.withTarget(queued, message: 42, local: 'ignored'),
        );
        expect(accepted.queryParameters, {
          ...original.queryParameters,
          'message': '42',
        });
        expect(
          AppRoutes.safeDestination(accepted.toString()),
          accepted.toString(),
        );
        expect(AppRoutes.withTarget(accepted), original.toString());
        expect(
          AppRoutes.withTarget(accepted, message: -1, local: 'x' * 129),
          original.toString(),
        );
      }
    },
  );

  test('authentication handoff accepts only canonical app destinations', () {
    for (final path in [
      AppRoutes.chats,
      AppRoutes.contacts,
      AppRoutes.profile,
    ]) {
      expect(AppRoutes.safeDestination('$path?token=discarded'), path);
    }
    expect(
      AppRoutes.safeDestination('/chats/usrPeer?message=42&token=x'),
      '/chats/usrPeer?message=42',
    );
    expect(
      AppRoutes.safeDestination('/chats/grpGroup?local=draft-1'),
      '/chats/grpGroup?local=draft-1',
    );
    expect(
      AppRoutes.safeDestination('/chats/usrPeer/info?member=usrOther&x=y'),
      '/chats/usrPeer/info?member=usrOther',
    );
    expect(
      AppRoutes.safeDestination('/contacts/usrPeer?token=x'),
      '/contacts/usrPeer',
    );
    expect(
      AppRoutes.safeDestination(
        AppRoutes.search('usrPeer', query: 'Привет world'),
      ),
      AppRoutes.search('usrPeer', query: 'Привет world'),
    );
  });

  test('external, nested, encoded and malformed destinations fail closed', () {
    for (final value in <String?>[
      null,
      '',
      '/',
      'https://outside.test/chats/usrPeer',
      '//outside.test/chats/usrPeer',
      'javascript:alert(1)',
      '/login?from=/chats/usrPeer',
      '/unknown',
      '/chats/usrPeer/extra/info',
      '/chats/usrPeer%2Finfo',
      '/chats/%252Foutside',
      '/chats/usrPeer#fragment',
      '/chats/%FF',
      '/chats/usrPeer?message=%FF',
      '/chats/usrPeer/info?member=%FF',
      '/chats/usrPeer/search?q=%FF',
    ]) {
      expect(
        AppRoutes.safeDestination(value),
        AppRoutes.chats,
        reason: '$value',
      );
    }
  });

  test(
    'unsupported or excessive target fields are not carried through login',
    () {
      expect(
        AppRoutes.safeDestination('/chats/usrPeer?message=-1'),
        '/chats/usrPeer',
      );
      expect(
        AppRoutes.safeDestination(
          '/chats/usrPeer?message=oops&local=stable-id',
        ),
        '/chats/usrPeer?local=stable-id',
      );
      expect(
        AppRoutes.safeDestination('/chats/usrPeer?local=${'x' * 129}'),
        '/chats/usrPeer',
      );
      expect(
        AppRoutes.safeDestination('/chats/usrPeer/info?member=me'),
        '/chats/usrPeer/info',
      );
      expect(
        AppRoutes.safeDestination('/chats/usrPeer/search?q=${'x' * 257}'),
        '/chats/usrPeer/search',
      );
    },
  );
}
