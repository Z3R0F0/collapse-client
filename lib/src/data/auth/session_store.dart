import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'session.dart';

export 'session.dart' show SavedSession;

abstract interface class SessionStore {
  Future<SavedSession?> read();
  Future<void> write(SavedSession session);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore(String serverId, {FlutterSecureStorage? storage})
    : _key = 'collapse.session.${base64Url.encode(utf8.encode(serverId))}',
      _storage = storage ?? const FlutterSecureStorage();
  final String _key;
  final FlutterSecureStorage _storage;

  @override
  Future<SavedSession?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      final session = SavedSession(
        json['userId'] as String,
        json['token'] as String,
      );
      if (session.userId.isEmpty || session.token.isEmpty) {
        throw const FormatException('Empty saved session');
      }
      return session;
    } on FormatException {
      await clear();
      return null;
    } on TypeError {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(SavedSession session) => _storage.write(
    key: _key,
    value: jsonEncode({'userId': session.userId, 'token': session.token}),
  );

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
