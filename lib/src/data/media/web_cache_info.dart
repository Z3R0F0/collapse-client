import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// The default web provider drops metadata, so it cannot evict files by ID.
/// This is session-only metadata for CacheManager's existing memory filesystem.
class WebCacheInfo implements CacheInfoRepository {
  WebCacheInfo({required this.maxBytes, required this.maxEntries})
    : assert(maxBytes > 0),
      assert(maxEntries > 0);
  final int maxBytes;
  final int maxEntries;
  final _objects = <String, CacheObject>{};
  final _readers = <String, int>{};
  int _nextId = 0;

  void pin(String key) =>
      _readers.update(key, (count) => count + 1, ifAbsent: () => 1);

  void release(String key) {
    final count = _readers[key] ?? 0;
    if (count <= 1) {
      _readers.remove(key);
    } else {
      _readers[key] = count - 1;
    }
  }

  void touch(String key) {
    final entry = _objects.remove(key);
    if (entry != null) _objects[key] = entry;
  }

  List<CacheObject> overBudget() {
    var size = _objects.values.fold(
      0,
      (size, item) => size + (item.length ?? 0),
    );
    var count = _objects.length;
    final remove = <CacheObject>[];
    for (final item in _objects.values) {
      if (count <= maxEntries && size <= maxBytes) break;
      if (_readers.containsKey(item.key)) continue;
      remove.add(item);
      size -= item.length ?? 0;
      count--;
    }
    return remove;
  }

  @override
  Future<CacheObject> updateOrInsert(CacheObject item) async {
    final saved = CacheObject.fromMap(
      item.copyWith(id: _objects[item.key]?.id ?? ++_nextId).toMap(),
    );
    _objects.remove(saved.key);
    _objects[saved.key] = saved;
    return saved;
  }

  @override
  Future<CacheObject> insert(CacheObject item, {bool setTouchedToNow = true}) =>
      updateOrInsert(item);

  @override
  Future<int> update(CacheObject item, {bool setTouchedToNow = true}) async {
    await updateOrInsert(item);
    return 1;
  }

  @override
  Future<CacheObject?> get(String key) async => _objects[key];

  @override
  Future<List<CacheObject>> getAllObjects() async => _objects.values.toList();

  @override
  Future<int> delete(int id) => deleteAll([id]);

  @override
  Future<int> deleteAll(Iterable<int> ids) async {
    final before = _objects.length;
    final selected = ids.toSet();
    _objects.removeWhere((_, item) => selected.contains(item.id));
    return before - _objects.length;
  }

  // WebMediaCache prunes after reading bytes, in its serial queue. Letting the
  // package's delayed cleanup also evict would race an active file reader.
  @override
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) async => [];

  @override
  Future<List<CacheObject>> getOldObjects(Duration maxAge) async => [];

  @override
  Future<bool> exists() async => true;

  @override
  Future<bool> open() async => true;

  @override
  Future<bool> close() async {
    _objects.clear();
    _readers.clear();
    return true;
  }

  @override
  Future<void> deleteDataFile() async => _objects.clear();
}
