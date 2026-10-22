part of 'auth_repository.dart';

extension _AuthRestore on AuthRepository {
  Future<void> _restore() async {
    final epoch = _epoch;
    try {
      final saved = await store.read();
      if (epoch != _epoch || _disposed) return;
      _saved = saved;
      if (saved == null) {
        _emit(const SessionState(SessionPhase.signedOut));
        return;
      }
      // The cached account is usable even when the network is unavailable.
      await chats.start(saved.userId);
      if (epoch != _epoch || _disposed) return;
      _emit(SessionState(SessionPhase.offline, userId: saved.userId));
      await _reconnect(epoch);
    } catch (error) {
      if (epoch != _epoch || _disposed) return;
      final cached = _saved;
      _emit(
        SessionState(
          cached == null ? SessionPhase.signedOut : SessionPhase.offline,
          userId: cached?.userId,
          error: error,
        ),
      );
      if (cached != null) _scheduleReconnect();
    }
  }
}
