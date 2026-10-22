import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collapse_tinode/tinode.dart';

import '../../data/media/media_gallery_repository.dart';
import '../../domain/chat/media_models.dart';
import 'media_gallery_state.dart';

export 'media_gallery_state.dart';
export '../../domain/chat/media_models.dart';

/// The atlas/viewer owns media cursors, never message-window or scroll state.
class MediaGalleryCubit extends Cubit<MediaGalleryState> {
  MediaGalleryCubit(this.repository, this.topicId, this.category)
    : _account = repository.account,
      _session = repository.generation,
      super(const MediaGalleryState());
  final MediaGalleryRepository repository;
  final String topicId;
  final MediaCategory category;
  final String _account;
  final int _session;
  StreamSubscription<Object>? _subscription;
  MediaCursor? _older, _newer;
  int? _snapshot;
  int _epoch = 0;
  MediaItem? _seed;
  MediaCursor? _around;
  bool _refreshScheduled = false;
  bool _dirty = false;

  Future<void> open({
    MediaItem? seed,
    MediaCursor? around,
    String? pendingId,
    int entityIndex = 0,
  }) async {
    if (seed == null && pendingId != null) {
      final epoch = ++_epoch;
      emit(const MediaGalleryState(loading: true));
      try {
        seed = await repository.find(
          topicId,
          -1,
          entityIndex,
          messageId: pendingId,
        );
        if (!_active(epoch)) return;
        if (seed == null) {
          emit(const MediaGalleryState(error: true));
          return;
        }
      } catch (_) {
        if (_active(epoch)) emit(const MediaGalleryState(error: true));
        return;
      }
    }
    _seed = seed;
    _around = around ?? (seed?.pending == false ? seed!.cursor : null);
    if (seed != null) {
      emit(MediaGalleryState(items: [seed], currentId: seed.id));
    } else {
      emit(const MediaGalleryState(loading: true));
    }
    _subscription ??= repository.changes(topicId).listen((_) => _reconcile());
    await refresh();
  }

  Future<void> refresh() async {
    final epoch = ++_epoch;
    emit(
      state.copyWith(loading: true, loadingOlder: false, loadingNewer: false),
    );
    try {
      if (_seed case final seed?) {
        _seed = await repository.find(
          topicId,
          seed.seq,
          seed.entityIndex,
          messageId: seed.messageId,
        );
        if (!_active(epoch)) return;
        if (_seed != null && !_seed!.pending) _around = _seed!.cursor;
      }
      var cached = await repository.cached(topicId, category, around: _around);
      if (!_active(epoch)) return;
      _replace(cached, loading: repository.online || !cached.cacheIndexed);
      if (repository.online) {
        final page = await repository.page(topicId, category, around: _around);
        if (!_active(epoch)) return;
        _replace(page);
      } else {
        while (!cached.cacheIndexed && _active(epoch)) {
          await Future<void>.delayed(Duration.zero);
          cached = await repository.cached(topicId, category, around: _around);
          if (_active(epoch)) _replace(cached, loading: !cached.cacheIndexed);
        }
      }
    } catch (error) {
      if (_active(epoch)) {
        if (error is TinodeException &&
            (error.code == 403 || error.code == 404)) {
          _seed = null;
          emit(const MediaGalleryState(error: true));
        } else {
          emit(state.copyWith(loading: false, error: true));
        }
      }
    } finally {
      if (_active(epoch) && _dirty) _reconcile();
    }
  }

  void _replace(MediaPage page, {bool loading = false}) {
    if (loading && _around != null && !page.anchorFound) {
      // A partial cache may contain neighbours but not the URL's target. Do
      // not flash/select a neighbour (and replace the URL) before server data.
      emit(
        MediaGalleryState(
          items: _seed == null ? const [] : [_seed!],
          currentId: _seed?.id,
          loading: true,
          offline: page.offline,
        ),
      );
      return;
    }
    if (!loading &&
        _around != null &&
        !page.anchorFound &&
        (!page.offline || _seed == null)) {
      emit(MediaGalleryState(error: true, offline: page.offline));
      return;
    }
    final items = {
      ...{for (final item in page.items) item.id: item},
    };
    // A queued item has no server cursor yet, but must open immediately offline.
    if (_seed case final seed? when seed.pending || page.offline) {
      items.putIfAbsent(seed.id, () => seed);
    }
    final sorted = items.values.toList()..sort(MediaItem.compare);
    final wanted = state.currentId ?? _seed?.id;
    final current =
        sorted.where((i) => i.id == wanted).firstOrNull ??
        sorted
            .where((i) => _around != null && i.cursor.compareTo(_around!) == 0)
            .firstOrNull ??
        sorted.lastOrNull;
    _older = page.olderCursor;
    _newer = page.newerCursor;
    _snapshot = page.snapshot > 0 ? page.snapshot : null;
    emit(
      MediaGalleryState(
        items: List.unmodifiable(sorted),
        currentId: current?.id,
        hasOlder: page.hasOlder,
        hasNewer: page.hasNewer,
        loading: loading,
        offline: page.offline,
      ),
    );
  }

  void select(String id) {
    final item = state.items.where((i) => i.id == id).firstOrNull;
    if (item == null || id == state.currentId) return;
    _seed = item;
    _around = item.pending ? null : item.cursor;
    emit(state.copyWith(currentId: id));
  }

  Future<void> older() => _extend(true);
  Future<void> newer() => _extend(false);
  Future<void> _extend(bool older) async {
    final cursor = older ? _older : _newer;
    if (isClosed ||
        state.busy ||
        cursor == null ||
        !(older ? state.hasOlder : state.hasNewer)) {
      return;
    }
    final epoch = _epoch;
    emit(state.copyWith(loadingOlder: older, loadingNewer: !older));
    try {
      final page = await repository.page(
        topicId,
        category,
        before: older ? cursor : null,
        after: older ? null : cursor,
        snapshot: older ? _snapshot : null,
      );
      if (!_active(epoch)) return;
      final items = {for (final item in state.items) item.id: item};
      for (final item in page.items) {
        items[item.id] = item;
      }
      if (older) {
        _older = page.olderCursor ?? _older;
      } else {
        _newer = page.newerCursor ?? _newer;
        if (page.snapshot > 0) _snapshot = page.snapshot;
      }
      emit(
        state.copyWith(
          items: List.unmodifiable(
            items.values.toList()..sort(MediaItem.compare),
          ),
          hasOlder: older ? page.hasOlder : state.hasOlder,
          hasNewer: older ? state.hasNewer : page.hasNewer,
          loadingOlder: false,
          loadingNewer: false,
          offline: page.offline,
        ),
      );
    } catch (error) {
      if (_active(epoch)) {
        if (error is TinodeException &&
            (error.code == 403 || error.code == 404)) {
          _seed = null;
          emit(const MediaGalleryState(error: true));
          return;
        }
        emit(
          state.copyWith(loadingOlder: false, loadingNewer: false, error: true),
        );
      }
    } finally {
      if (_active(epoch) && _dirty) _reconcile();
    }
  }

  Future<Uint8List> bytes(MediaItem item) => repository.bytes(item);

  void _reconcile() {
    _dirty = true;
    if (_refreshScheduled || isClosed) return;
    _refreshScheduled = true;
    scheduleMicrotask(() async {
      _refreshScheduled = false;
      if (isClosed || state.busy || repository.account != _account) return;
      _dirty = false;
      final epoch = _epoch;
      final snapshot = state.items;
      try {
        final previous = state.items.indexWhere((i) => i.id == state.currentId);
        final items = await repository.retained(topicId, state.items);
        if (!_active(epoch)) return;
        if (!identical(snapshot, state.items) || state.busy) {
          _reconcile();
          return;
        }
        final current =
            items.where((i) => i.id == state.currentId).firstOrNull ??
            (items.isEmpty ? null : items[previous.clamp(0, items.length - 1)]);
        if (_seed != null || _around != null) {
          _seed = current;
          _around = current?.pending == false ? current!.cursor : null;
        }
        emit(state.copyWith(items: items, currentId: current?.id));
      } catch (_) {
        if (_active(epoch)) emit(state.copyWith(error: true));
      }
    });
  }

  bool _active(int epoch) =>
      !isClosed &&
      epoch == _epoch &&
      repository.account == _account &&
      repository.generation == _session;
  @override
  Future<void> close() async {
    _epoch++;
    await _subscription?.cancel();
    return super.close();
  }
}
