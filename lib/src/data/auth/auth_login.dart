part of 'auth_repository.dart';

extension _AuthLogin on AuthRepository {
  Future<void> _signIn(
    String username,
    String password, {
    String? displayName,
  }) {
    if (_disposed) return Future.value();
    if (_signingOut != null) {
      return _signingOut!.then(
        (_) => signIn(username, password, displayName: displayName),
      );
    }
    if (_operation != null) {
      if (_operationKind == 'signIn') return _operation!;
      return _operation!.then(
        (_) => signIn(username, password, displayName: displayName),
      );
    }
    return _run('signIn', () async {
      final epoch = ++_epoch;
      _retry?.cancel();
      _emit(const SessionState(SessionPhase.connecting));
      try {
        await gateway.disconnect();
        if (epoch != _epoch || _disposed) return;
        await gateway.connect();
        if (epoch != _epoch || _disposed) return;
        final reply = displayName == null
            ? await gateway.loginBasic(username.trim(), password)
            : await gateway.createAccountBasic(
                username.trim(),
                password,
                public: {'fn': displayName.trim()},
              );
        await _accept(reply, epoch);
      } catch (error) {
        if (epoch != _epoch || _disposed) return;
        if (_saved != null) {
          await gateway.disconnect();
          if (epoch != _epoch || _disposed) return;
          _emit(
            SessionState(
              SessionPhase.offline,
              userId: _saved!.userId,
              error: error,
            ),
          );
          _scheduleReconnect();
        } else {
          await chats.stop();
          if (epoch != _epoch || _disposed) return;
          await gateway.disconnect();
          if (epoch != _epoch || _disposed) return;
          _emit(SessionState(SessionPhase.signedOut, error: error));
        }
      }
    });
  }
}
