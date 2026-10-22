import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/chat/chats_repository.dart';
import '../../data/profile/profile_repository.dart';
import '../../domain/chat/chat_models.dart';

class ChatsCubit extends Cubit<List<ChatTopic>> {
  ChatsCubit(this.repository, this.profiles) : super(const []) {
    _subscription = repository.watchTopics().listen(emit);
  }
  final ChatsRepository repository;
  final ProfileRepository profiles;
  late final StreamSubscription<List<ChatTopic>> _subscription;
  Future<void> refresh() => repository.refreshTopics();
  Future<String> createGroup(String name) async {
    final id = await profiles.createGroup(name);
    await repository.ensureTopic(id);
    await refresh();
    return id;
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
