import 'dart:convert';

import 'package:collapse/src/data/auth/session_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'secure sessions are isolated by server and clear only their own key',
    () async {
      final first = SecureSessionStore('wss://first.test');
      final second = SecureSessionStore('wss://second.test');
      await first.write(const SavedSession('usrA', 'token-A'));
      await second.write(const SavedSession('usrB', 'token-B'));
      expect((await first.read())?.userId, 'usrA');
      expect((await second.read())?.userId, 'usrB');
      await first.clear();
      expect(await first.read(), isNull);
      expect((await second.read())?.token, 'token-B');
    },
  );

  for (final corrupt in [
    'broken-json',
    '{}',
    '{"userId":12,"token":false}',
    '{"userId":"","token":"synthetic"}',
    '{"userId":"usrA","token":""}',
  ]) {
    test(
      'malformed or empty saved credentials are cleared: $corrupt',
      () async {
        final key = 'collapse.session.${base64Url.encode(utf8.encode('test'))}';
        FlutterSecureStorage.setMockInitialValues({key: corrupt});
        final store = SecureSessionStore('test');
        expect(await store.read(), isNull);
        expect(await const FlutterSecureStorage().read(key: key), isNull);
      },
    );
  }
}
