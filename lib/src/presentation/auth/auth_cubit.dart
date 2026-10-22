import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/auth/auth_repository.dart';

class AuthCubit extends Cubit<SessionState> {
  AuthCubit(this.repository) : super(repository.state) {
    _subscription = repository.changes.listen(emit);
  }
  final AuthRepository repository;
  late final StreamSubscription<SessionState> _subscription;
  Future<void> signIn(
    String username,
    String password, {
    String? displayName,
  }) => repository.signIn(username, password, displayName: displayName);
  Future<void> signOut() => repository.signOut();
  Future<void> reconnect() => repository.reconnect();
  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
