enum SessionPhase { restoring, signedOut, connecting, online, offline }

class SessionState {
  const SessionState(this.phase, {this.userId, this.error});
  final SessionPhase phase;
  final String? userId;
  final Object? error;
  bool get authenticated => userId != null;
  bool get busy =>
      phase == SessionPhase.restoring || phase == SessionPhase.connecting;
}

class SavedSession {
  const SavedSession(this.userId, this.token);
  final String userId;
  final String token;
}
