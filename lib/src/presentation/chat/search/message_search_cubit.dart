import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/chat/chats_repository.dart';
import 'message_search_state.dart';

export 'message_search_state.dart';

/// One result page, independent of the conversation window and read receipts.
class MessageSearchCubit extends Cubit<MessageSearchState> {
  MessageSearchCubit(this.repository, this.topicId)
    : _account = repository.currentUserId,
      super(const MessageSearchState());

  final ChatsRepository repository;
  final String topicId;
  final String _account;
  final _previous = <SearchCursor?>[];
  SearchCursor? _cursor;
  Timer? _debounce;
  int _generation = 0;

  void search(String query, {bool immediate = false}) {
    _debounce?.cancel();
    final generation = ++_generation;
    _cursor = null;
    _previous.clear();
    emit(MessageSearchState(query: query, loading: query.trim().isNotEmpty));
    if (!state.loading) return;
    if (immediate) {
      unawaited(_load(generation));
    } else {
      _debounce = Timer(
        const Duration(milliseconds: 250),
        () => _load(generation),
      );
    }
  }

  Future<void> next() async {
    final cursor = state.page?.nextCursor;
    if (state.busy || cursor == null || state.page?.cacheIndexed != true) {
      return;
    }
    final oldCursor = _cursor;
    _previous.add(_cursor);
    _cursor = cursor;
    final generation = ++_generation;
    if (!await _load(generation) && _active(generation)) {
      _cursor = oldCursor;
      _previous.removeLast();
      emit(state.copyWith(error: true, canPrevious: _previous.isNotEmpty));
    }
  }

  Future<void> previous() async {
    if (state.busy || _previous.isEmpty) return;
    final oldCursor = _cursor;
    _cursor = _previous.removeLast();
    final generation = ++_generation;
    if (!await _load(generation) && _active(generation)) {
      _previous.add(_cursor);
      _cursor = oldCursor;
      emit(state.copyWith(error: true, canPrevious: _previous.isNotEmpty));
    }
  }

  Future<void> loadHistory() async {
    if (state.busy || !(state.page?.canLoadHistory ?? false)) return;
    final generation = ++_generation;
    emit(state.copyWith(loadingHistory: true));
    try {
      final loaded = await repository.loadMoreSearchHistory(topicId);
      if (!_active(generation)) return;
      if (loaded == null) throw StateError('Stale search session');
      _cursor = null;
      _previous.clear();
      emit(MessageSearchState(query: state.query, loading: true));
      await _load(generation);
    } catch (_) {
      if (_active(generation)) {
        emit(state.copyWith(loadingHistory: false, error: true));
      }
    }
  }

  Future<bool> _load(int generation) async {
    if (!_active(generation)) return false;
    emit(state.copyWith(loading: true, canPrevious: _previous.isNotEmpty));
    try {
      while (_active(generation)) {
        final page = await repository.searchMessages(
          topicId,
          state.query,
          before: _cursor,
        );
        if (!_active(generation)) return false;
        if (page == null) throw StateError('Stale search session');
        emit(state.copyWith(page: page, loading: !page.cacheIndexed));
        if (page.cacheIndexed) return true;
        // Each repository call prepares only one small persisted batch.
        await Future<void>.delayed(Duration.zero);
      }
    } catch (_) {
      if (_active(generation)) {
        emit(state.copyWith(loading: false, error: true));
      }
    }
    return false;
  }

  bool _active(int generation) =>
      !isClosed &&
      generation == _generation &&
      repository.currentUserId == _account;

  @override
  Future<void> close() async {
    _generation++;
    _debounce?.cancel();
    return super.close();
  }
}
