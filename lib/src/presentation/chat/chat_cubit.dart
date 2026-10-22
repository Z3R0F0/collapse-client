import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/chat/chats_repository.dart';
import '../../domain/chat/chat_models.dart';
import 'chat_state.dart';
import 'window_policy.dart';

export 'chat_state.dart';

part 'chat_open.dart';
part 'chat_paging.dart';
part 'chat_live.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit(this.repository) : super(const ChatState());

  final ChatsRepository repository;
  String? _topicId;
  String? _accountId;
  int? _sessionGeneration;
  StreamSubscription<ChatChange>? _subscription;
  StreamSubscription<int>? _unreadSubscription;
  Future<void> _updates = Future.value();
  int _generation = 0;
  bool _followingLive = true;
  // A followed cached window awaits one atomic reconciled latest snapshot.
  bool _awaitingLatestTail = false;
  Set<String> _visibleIds = const {};

  /// User's tail-follow intent, not a server-history availability flag.
  void setFollowingLive(bool following) {
    _followingLive = following;
    if (!following) _awaitingLatestTail = false;
  }

  /// An eviction lease for the last painted viewport. No offsets enter data
  /// pagination. A late page must not evict what the user has scrolled back to.
  void setVisibleMessages(Set<String> ids) => _visibleIds = Set.of(ids);

  Future<void> open(String topicId, {int? aroundSeq, String? aroundId}) =>
      _open(topicId, aroundSeq: aroundSeq, aroundId: aroundId);

  Future<void> loadOlder() => _loadPage(HistoryDirection.older);
  Future<void> loadNewer() => _loadPage(HistoryDirection.newer);

  Future<void> jumpToLatest() async {
    if (_topicId != null) await open(_topicId!);
  }

  /// Completion means a durable local enqueue, never delivery or navigation.
  Future<void> send(
    Object content, {
    Map<String, dynamic> head = const {},
    List<PendingUpload> uploads = const [],
    bool clearDraft = false,
  }) {
    if (isClosed ||
        _topicId == null ||
        _accountId != repository.currentUserId ||
        _sessionGeneration != repository.sessionGeneration) {
      return Future.error(StateError('Chat session is no longer active'));
    }
    final generation = _generation;
    final shouldJump = !_followingLive;
    return repository
        .send(
          _topicId!,
          content,
          head: head,
          uploads: uploads,
          clearDraft: clearDraft,
        )
        .then((_) {
          if (_active(generation) && shouldJump) {
            // open changes the generation/follow intent synchronously. A rapid
            // burst therefore requests one latest snapshot, not one per send.
            unawaited(jumpToLatest());
          }
        });
  }

  Future<void> markVisible(int seq) async {
    if (_active(_generation) && _topicId != null && seq > 0) {
      await repository.markRead(_topicId!, seq);
    }
  }

  void _publish(ChatState next) => emit(next);

  Future<void> _serialize(int generation, Future<void> Function() action) {
    final next = _updates.then((_) async {
      if (_active(generation)) await action();
    });
    _updates = next.catchError((Object _) {});
    return next;
  }

  bool _active(int generation) =>
      !isClosed &&
      generation == _generation &&
      _accountId == repository.currentUserId &&
      _sessionGeneration == repository.sessionGeneration;

  @override
  Future<void> close() async {
    _generation++;
    await Future.wait<void>([
      if (_subscription != null) _subscription!.cancel(),
      if (_unreadSubscription != null) _unreadSubscription!.cancel(),
    ]);
    return super.close();
  }
}
