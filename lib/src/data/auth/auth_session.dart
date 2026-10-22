part of 'auth_repository.dart';

extension _AuthSession on AuthRepository {
  Future<void> _accept(Map<String, dynamic> reply, int epoch) async {
    if (epoch != _epoch || _disposed) return;
    _validateReply(reply);
    final params = Map<String, dynamic>.from(reply['params'] as Map);
    final saved = SavedSession(
      params['user'] as String,
      params['token'] as String,
    );
    if (_saved != null && _saved!.userId != saved.userId) {
      throw const TinodeException(401, 'Session account changed');
    }
    await store.write(saved);
    // Logout is a barrier: it waits for this operation before clearing storage.
    // A stale operation must never clear credentials written by a newer login.
    if (epoch != _epoch || _disposed) return;
    _saved = saved;
    try {
      await chats.start(saved.userId);
    } catch (error) {
      if (epoch != _epoch || _disposed) return;
      await gateway.disconnect();
      if (epoch != _epoch || _disposed) return;
      _emit(
        SessionState(SessionPhase.offline, userId: saved.userId, error: error),
      );
      _scheduleReconnect();
      return;
    }
    if (epoch != _epoch || _disposed) return;
    _attempt = 0;
    _retry?.cancel();
    final online = gateway.connected && gateway.userId == saved.userId;
    _emit(
      SessionState(
        online ? SessionPhase.online : SessionPhase.offline,
        userId: saved.userId,
      ),
    );
    if (!online) _scheduleReconnect();
  }

  void _validateReply(Map<String, dynamic> reply) {
    final code = reply['code'] as int? ?? 500;
    if (code < 200 || code >= 300) {
      throw TinodeException(code, 'Authentication was not completed');
    }
    final params = reply['params'];
    if (params is! Map ||
        params['user'] is! String ||
        (params['user'] as String).isEmpty ||
        params['token'] is! String ||
        (params['token'] as String).isEmpty) {
      throw const FormatException('Missing authenticated session');
    }
  }
}
