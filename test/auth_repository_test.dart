import 'dart:async';

import 'package:collapse/src/data/auth/auth_repository.dart';
import 'package:collapse/src/data/auth/session_store.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/presentation/auth/auth_cubit.dart';
import 'package:collapse_tinode/tinode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Gateway gateway;
  late _Chats chats;
  late _Store store;
  late AuthRepository auth;
  setUp(() {
    gateway = _Gateway();
    chats = _Chats(gateway);
    store = _Store();
    auth = AuthRepository(gateway: gateway, chats: chats, store: store);
  });
  tearDown(() async {
    await auth.dispose();
    await gateway.dispose();
  });

  test(
    'offline restore keeps cached account and token after network timeout',
    () async {
      store.session = const SavedSession('usrAlice', 'old-token');
      gateway.connectionError = TimeoutException('network unavailable');
      await auth.restore();
      expect(auth.state.phase, SessionPhase.offline);
      expect(auth.state.userId, 'usrAlice');
      expect(chats.currentUser, 'usrAlice');
      expect(store.session?.token, 'old-token');
      expect(store.clears, 0);
    },
  );

  test('rejected saved token signs out and clears account context', () async {
    store.session = const SavedSession('usrAlice', 'expired-token');
    gateway.tokenError = const TinodeException(401, 'expired');
    await auth.restore();
    expect(auth.state.phase, SessionPhase.signedOut);
    expect(auth.state.userId, isNull);
    expect(chats.currentUser, isNull);
    expect(store.session, isNull);
  });

  test(
    'local cache failure does not discard an otherwise valid saved account',
    () async {
      store.session = const SavedSession('usrAlice', 'old-token');
      chats.startError = StateError('cache temporarily unavailable');
      await auth.restore();
      expect(auth.state.phase, SessionPhase.offline);
      expect(auth.state.userId, 'usrAlice');
      expect(store.session?.token, 'old-token');
      expect(store.clears, 0);
    },
  );

  test('post-login sync 403 preserves valid rotated token offline', () async {
    store.session = const SavedSession('usrAlice', 'old-token');
    chats.onlineStartError = const TinodeException(403, 'one topic denied');
    await auth.restore();
    expect(auth.state.phase, SessionPhase.offline);
    expect(auth.state.userId, 'usrAlice');
    expect(store.session?.token, 'token-usrAlice');
    expect(store.clears, 0);
  });

  test('fresh successful login survives initial sync failure', () async {
    chats.onlineStartError = TimeoutException('initial sync');
    await auth.signIn('alice', 'password');
    expect(auth.state.phase, SessionPhase.offline);
    expect(auth.state.authenticated, isTrue);
    expect(store.session?.userId, 'usrAlice');
    expect(store.clears, 0);
  });

  test(
    'basic auth failure and credential challenge never create session',
    () async {
      gateway.basicError = const TinodeException(401, 'invalid login');
      await auth.signIn('alice', 'bad-password');
      expect(auth.state.phase, SessionPhase.signedOut);
      expect(store.session, isNull);
      gateway.basicError = null;
      gateway.challenge = true;
      await auth.signIn('alice', 'password', displayName: 'Alice');
      expect(auth.state.phase, SessionPhase.signedOut);
      expect(
        auth.state.error,
        isA<TinodeException>().having((e) => e.code, 'code', 300),
      );
      expect(store.session, isNull);
    },
  );

  test('restore and reconnect are single-flight', () async {
    store.session = const SavedSession('usrAlice', 'old-token');
    gateway.loginGate = Completer<void>();
    final first = auth.restore();
    await gateway.tokenStarted.future;
    final other = auth.reconnect();
    final third = auth.restore();
    gateway.loginGate!.complete();
    await Future.wait([first, other, third]);
    expect(gateway.tokenLogins, 1);
    expect(store.reads, 1);
    expect(auth.state.phase, SessionPhase.online);
  });

  test(
    'resuming an already online account does not authenticate or sync again',
    () async {
      store.session = const SavedSession('usrAlice', 'old-token');
      await auth.restore();
      final starts = chats.starts;
      final writes = store.writes;
      await Future.wait([auth.reconnect(), auth.reconnect()]);
      expect(gateway.tokenLogins, 1);
      expect(chats.starts, starts);
      expect(store.writes, writes);
      expect(gateway.probes, 1);
      expect(auth.state.phase, SessionPhase.online);
    },
  );

  test('resume replaces a half-open socket before restoring online', () async {
    store.session = const SavedSession('usrAlice', 'old-token');
    await auth.restore();
    gateway.probeError = TimeoutException('half-open socket');
    await auth.reconnect();
    expect(gateway.probes, 1);
    expect(gateway.tokenLogins, 2);
    expect(auth.state.phase, SessionPhase.online);
  });

  test('logout during a liveness probe cannot reopen the account', () async {
    store.session = const SavedSession('usrAlice', 'old-token');
    await auth.restore();
    gateway.probeGate = Completer<void>();
    final reconnect = auth.reconnect();
    // The fake deliberately completes late, even after transport cancellation.
    final logout = auth.signOut();
    gateway.probeGate!.complete();
    await Future.wait([reconnect, logout]);
    expect(gateway.tokenLogins, 1);
    expect(auth.state.phase, SessionPhase.signedOut);
    expect(store.session, isNull);
  });

  test(
    'logout during token login never republishes stale authenticated state',
    () async {
      store.session = const SavedSession('usrAlice', 'old-token');
      gateway.loginGate = Completer<void>();
      final restore = auth.restore();
      await gateway.tokenStarted.future;
      final logout = auth.signOut();
      gateway.loginGate!.complete();
      await Future.wait([restore, logout]);
      expect(auth.state.phase, SessionPhase.signedOut);
      expect(store.session, isNull);
      expect(chats.currentUser, isNull);
      expect(store.writes, 0);
      expect(gateway.userId, isNull);
      expect(gateway.token, isNull);
    },
  );

  test(
    'logout waits slow vault write, then next account login is not swallowed',
    () async {
      store.writeGate = Completer<void>();
      final alice = auth.signIn('alice', 'password');
      await store.writeStarted.future;
      final logout = auth.signOut();
      final bob = auth.signIn('bob', 'password');
      store.writeGate!.complete();
      await Future.wait([alice, logout, bob]);
      expect(auth.state.phase, SessionPhase.online);
      expect(auth.state.userId, 'usrBob');
      expect(store.session?.userId, 'usrBob');
      expect(store.session?.token, 'token-usrBob');
      expect(chats.currentUser, 'usrBob');
      expect(gateway.basicLogins, ['alice', 'bob']);
    },
  );

  test(
    'logout during slow restore read cannot reopen cached account',
    () async {
      store.session = const SavedSession('usrAlice', 'token');
      store.readGate = Completer<void>();
      final restoring = auth.restore();
      final logout = auth.signOut();
      store.readGate!.complete();
      await Future.wait([restoring, logout]);
      expect(auth.state.phase, SessionPhase.signedOut);
      expect(chats.currentUser, isNull);
      expect(gateway.tokenLogins, 0);
      expect(store.session, isNull);
    },
  );

  test(
    'disconnect during initial sync does not emit a false online state',
    () async {
      chats.onOnlineStart = () async => gateway.disconnect();
      await auth.signIn('alice', 'password');
      expect(auth.state.phase, SessionPhase.offline);
      expect(store.session?.userId, 'usrAlice');
    },
  );

  test('AuthCubit forwards state and cancels listener on close', () async {
    final cubit = AuthCubit(auth);
    await cubit.signIn('alice', 'password');
    expect(cubit.state.phase, SessionPhase.online);
    await cubit.close();
    await auth.signOut();
    expect(cubit.isClosed, isTrue);
  });

  test(
    'sign-in requested by a signed-out observer waits the logout barrier',
    () async {
      await auth.signIn('alice', 'password');
      Future<void>? nextLogin;
      final listener = auth.changes.listen((state) {
        if (state.phase == SessionPhase.signedOut && nextLogin == null) {
          nextLogin = auth.signIn('bob', 'password');
        }
      });
      await auth.signOut();
      await nextLogin;
      expect(auth.state.userId, 'usrBob');
      expect(store.session?.userId, 'usrBob');
      await listener.cancel();
    },
  );
}

class _Store implements SessionStore {
  SavedSession? session;
  Completer<void>? writeGate;
  Completer<void>? readGate;
  final writeStarted = Completer<void>();
  int reads = 0;
  int writes = 0;
  int clears = 0;
  @override
  Future<SavedSession?> read() async {
    reads++;
    await readGate?.future;
    return session;
  }

  @override
  Future<void> write(SavedSession value) async {
    writes++;
    if (!writeStarted.isCompleted) writeStarted.complete();
    await writeGate?.future;
    session = value;
  }

  @override
  Future<void> clear() async {
    clears++;
    session = null;
  }
}

class _Chats implements ChatsRepository {
  _Chats(this.gateway);
  @override
  final _Gateway gateway;
  String? currentUser;
  int starts = 0;
  Object? startError;
  Object? onlineStartError;
  Future<void> Function()? onOnlineStart;
  @override
  Future<void> start(String userId) async {
    starts++;
    currentUser = userId;
    if (startError != null) throw startError!;
    if (gateway.connected) {
      await onOnlineStart?.call();
      if (onlineStartError != null) throw onlineStartError!;
    }
  }

  @override
  Future<void> stop() async => currentUser = null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Gateway extends TinodeGateway {
  _Gateway() : super(endpoint: Uri.parse('http://localhost'), apiKey: 'test');
  final controller = StreamController<TinodeEvent>.broadcast(sync: true);
  final tokenStarted = Completer<void>();
  final basicLogins = <String>[];
  Completer<void>? loginGate;
  Object? connectionError;
  Object? tokenError;
  Object? basicError;
  bool challenge = false;
  bool ready = false;
  int tokenLogins = 0;
  int probes = 0;
  Object? probeError;
  Completer<void>? probeGate;

  @override
  Future<void> probe() async {
    probes++;
    await probeGate?.future;
    if (probeError != null) throw probeError!;
  }

  @override
  Stream<TinodeEvent> get events => controller.stream;
  @override
  bool get connected => ready;
  @override
  Future<void> connect() async {
    if (connectionError != null) throw connectionError!;
    ready = true;
  }

  @override
  Future<void> disconnect() async {
    final wasReady = ready;
    ready = false;
    userId = null;
    token = null;
    if (wasReady) controller.add(const TinodeEvent('disconnected', {}));
  }

  @override
  Future<JsonMap> loginBasic(String username, String password) async {
    basicLogins.add(username);
    if (basicError != null) throw basicError!;
    return _reply(username == 'bob' ? 'usrBob' : 'usrAlice');
  }

  @override
  Future<JsonMap> createAccountBasic(
    String username,
    String password, {
    required JsonMap public,
  }) async {
    if (challenge) {
      return {
        'code': 300,
        'params': {
          'cred': ['email'],
        },
      };
    }
    return loginBasic(username, password);
  }

  @override
  Future<JsonMap> loginToken(String value) async {
    tokenLogins++;
    if (!tokenStarted.isCompleted) tokenStarted.complete();
    await loginGate?.future;
    if (tokenError != null) throw tokenError!;
    return _reply('usrAlice');
  }

  JsonMap _reply(String user) {
    userId = user;
    token = 'token-$user';
    return {
      'code': 200,
      'params': {'user': userId, 'token': token},
    };
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await controller.close();
    await super.dispose();
  }
}
