part of 'auth_repository.dart';

extension _AuthReconnect on AuthRepository {
  Future<void> _reconnect(int epoch) async {
    final saved = _saved!;
    if (_state.phase == SessionPhase.online &&
        gateway.connected &&
        gateway.userId == saved.userId) {
      try {
        await gateway.probe();
        if (epoch != _epoch || _disposed) return;
        if (gateway.connected && gateway.userId == saved.userId) return;
      } catch (_) {
        if (epoch != _epoch || _disposed) return;
      }
      await gateway.disconnect();
      if (epoch != _epoch || _disposed) return;
    }
    Map<String, dynamic> reply;
    try {
      await gateway.connect();
      if (epoch != _epoch || _disposed) return;
      reply = await gateway.loginToken(saved.token);
      _validateReply(reply);
    } catch (error) {
      if (epoch != _epoch || _disposed) return;
      if (error is TinodeException &&
          (error.code == 401 || error.code == 403)) {
        _saved = null;
        _retry?.cancel();
        await chats.stop();
        await gateway.disconnect();
        await store.clear();
        if (epoch != _epoch || _disposed) return;
        _emit(SessionState(SessionPhase.signedOut, error: error));
      } else {
        await gateway.disconnect();
        if (epoch != _epoch || _disposed) return;
        _emit(
          SessionState(
            SessionPhase.offline,
            userId: saved.userId,
            error: error,
          ),
        );
        _scheduleReconnect();
      }
      return;
    }
    // Sync/storage failures after authentication must not invalidate a token.
    try {
      await _accept(reply, epoch);
    } catch (error) {
      if (epoch != _epoch || _disposed) return;
      await gateway.disconnect();
      if (epoch != _epoch || _disposed) return;
      _emit(
        SessionState(SessionPhase.offline, userId: saved.userId, error: error),
      );
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _saved == null || (_retry?.isActive ?? false)) return;
    _retry = Timer(Duration(seconds: min(30, 1 << min(_attempt++, 5))), () {
      _retry = null;
      unawaited(reconnect());
    });
  }
}
