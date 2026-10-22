import 'dart:async';
import 'dart:math';
import 'package:collapse_tinode/tinode.dart';
import '../chat/chats_repository.dart';
import 'session.dart';
import 'session_store.dart';

export 'session.dart' show SessionPhase, SessionState;

part 'auth_restore.dart';
part 'auth_login.dart';
part 'auth_session.dart';
part 'auth_reconnect.dart';

/// Sole owner of session restore, token persistence and reconnect scheduling.
class AuthRepository {
  AuthRepository({
    required this.gateway,
    required this.chats,
    required this.store,
  }) {
    _connection = gateway.events.listen((event) {
      if (event.kind == 'disconnected' && _saved != null) {
        _emit(SessionState(SessionPhase.offline, userId: _saved!.userId));
        _scheduleReconnect();
      }
    });
  }

  final TinodeGateway gateway;
  final ChatsRepository chats;
  final SessionStore store;
  final _changes = StreamController<SessionState>.broadcast(sync: true);
  late final StreamSubscription<TinodeEvent> _connection;
  SessionState _state = const SessionState(SessionPhase.restoring);
  SessionState get state => _state;
  Stream<SessionState> get changes => _changes.stream;
  SavedSession? _saved;
  Timer? _retry;
  Future<void>? _operation;
  String? _operationKind;
  Future<void>? _signingOut;
  int _epoch = 0;
  int _attempt = 0;
  bool _disposed = false;

  void _emit(SessionState value) {
    if (_disposed) return;
    _state = value;
    _changes.add(value);
  }

  Future<void> restore() {
    if (_disposed) return Future.value();
    if (_signingOut != null) return _signingOut!.then((_) => restore());
    if (_operation != null) return _operation!;
    return _run('restore', _restore);
  }

  Future<void> signIn(
    String username,
    String password, {
    String? displayName,
  }) => _signIn(username, password, displayName: displayName);

  Future<void> reconnect() {
    if (_saved == null || _disposed) return Future.value();
    if (_operation != null) return _operation!;
    return _run('reconnect', () => _reconnect(_epoch));
  }

  Future<void> _run(String kind, Future<void> Function() action) {
    final future = action();
    _operation = future;
    _operationKind = kind;
    return future.whenComplete(() {
      if (identical(_operation, future)) {
        _operation = null;
        _operationKind = null;
      }
    });
  }

  Future<void> signOut() {
    if (_signingOut != null) return _signingOut!;
    final previous = _operation;
    final epoch = ++_epoch;
    _retry?.cancel();
    _saved = null;
    final logout = (() async {
      await gateway.disconnect();
      // Cancellation rejects transport work; slow keychain writes finish before
      // the final clear. New sign-in calls wait for this entire barrier.
      try {
        await previous;
      } catch (_) {}
      // A late authentication callback may have set gateway identity after the
      // first disconnect. Clear that state too before opening the next account.
      await gateway.disconnect();
      await chats.stop();
      await store.clear();
      if (epoch == _epoch) _emit(const SessionState(SessionPhase.signedOut));
    })().whenComplete(() => _signingOut = null);
    _signingOut = logout;
    _emit(const SessionState(SessionPhase.signedOut));
    return logout;
  }

  Future<void> dispose() async {
    _disposed = true;
    ++_epoch;
    _retry?.cancel();
    await _connection.cancel();
    await _changes.close();
  }
}
