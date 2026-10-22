import 'dart:async';

import 'package:collapse/src/data/media/media_gallery_repository.dart';
import 'package:collapse/src/presentation/media/media_gallery_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collapse_tinode/tinode.dart';

MediaItem item(int seq, {String? id}) => MediaItem(
  topicId: 'usrPeer',
  messageId: id ?? 'message:$seq',
  seq: seq,
  entityIndex: 0,
  type: 'IM',
  data: const {'ref': '/v0/file/s/test'},
  senderId: 'peer',
  createdAt: DateTime.utc(2026).add(Duration(seconds: seq)),
);

MediaPage page(
  List<MediaItem> items, {
  bool older = false,
  bool newer = false,
  bool offline = false,
  bool found = true,
  MediaCursor? cursor,
}) => MediaPage(
  items: items,
  hasOlder: older,
  hasNewer: newer,
  offline: offline,
  anchorFound: found,
  snapshot: 100,
  olderCursor: cursor ?? items.firstOrNull?.cursor,
  newerCursor: items.lastOrNull?.cursor,
);

class GalleryFake implements MediaGalleryRepository {
  @override
  String account = 'me';
  @override
  int generation = 1;
  @override
  bool online = true;
  final events = StreamController<Object>.broadcast();
  final visible = <String, MediaItem>{};
  MediaPage local = const MediaPage(items: [], offline: true);
  MediaPage remote = const MediaPage(items: []);
  final requests =
      <({MediaCursor? before, MediaCursor? after, MediaCursor? around})>[];
  Completer<MediaPage>? held;
  @override
  Stream<Object> changes(String topic) => events.stream;
  @override
  Future<MediaItem?> find(
    String topic,
    int seq,
    int entity, {
    String? messageId,
  }) async => visible.values
      .where((item) => item.messageId == messageId || item.seq == seq)
      .firstOrNull;
  @override
  Future<List<MediaItem>> retained(String topic, List<MediaItem> items) async =>
      items.map((i) => visible[i.id]).whereType<MediaItem>().toList();
  @override
  Future<MediaPage> cached(
    String topic,
    MediaCategory category, {
    MediaCursor? before,
    MediaCursor? after,
    MediaCursor? around,
    int limit = 24,
  }) async => local;
  @override
  Future<MediaPage> page(
    String topic,
    MediaCategory category, {
    MediaCursor? before,
    MediaCursor? after,
    MediaCursor? around,
    int limit = 24,
    int? snapshot,
  }) async {
    requests.add((before: before, after: after, around: around));
    return held?.future ?? Future.value(remote);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late GalleryFake repository;
  late MediaGalleryCubit cubit;
  final ten = item(10), twenty = item(20), thirty = item(30);
  setUp(() {
    repository = GalleryFake()
      ..visible.addEntries([
        for (final i in [ten, twenty, thirty]) MapEntry(i.id, i),
      ])
      ..local = page([ten, twenty], offline: true)
      ..remote = page([ten, twenty], older: true);
    cubit = MediaGalleryCubit(repository, 'usrPeer', MediaCategory.visual);
  });
  tearDown(() async {
    await cubit.close();
    await repository.events.close();
  });

  test(
    'seed is synchronous and around refresh keeps the selected identity',
    () async {
      final opening = cubit.open(seed: ten);
      expect(cubit.state.currentId, ten.id);
      expect(cubit.state.items.single, ten);
      await opening;
      cubit.select(twenty.id);
      await cubit.refresh();
      expect(cubit.state.currentId, twenty.id);
      expect(repository.requests.last.around?.seq, 20);
    },
  );

  test(
    'older is single-flight; prepend does not select another media',
    () async {
      await cubit.open(seed: twenty);
      final held = repository.held = Completer();
      final request = cubit.older();
      await cubit.older();
      expect(repository.requests.length, 2);
      held.complete(page([item(1), ten]));
      await request;
      expect(cubit.state.items.map((i) => i.seq), [1, 10, 20]);
      expect(cubit.state.currentId, twenty.id);
      await cubit.older();
      expect(
        repository.requests.length,
        2,
        reason: 'known older end is terminal',
      );
    },
  );

  test(
    'cold URL never selects a cached neighbour while its target loads',
    () async {
      repository.local = page([ten], offline: true, found: false);
      final held = repository.held = Completer();
      final selected = <String?>[];
      final subscription = cubit.stream.listen(
        (state) => selected.add(state.currentId),
      );
      final opening = cubit.open(around: twenty.cursor);
      await pumpEventQueue();
      expect(cubit.state.loading, isTrue);
      expect(cubit.state.current, isNull);
      held.complete(page([ten, twenty]));
      await opening;
      expect(cubit.state.currentId, twenty.id);
      expect(selected, isNot(contains(ten.id)));
      await subscription.cancel();
    },
  );

  test('locally hidden entire page still advances the server cursor', () async {
    await cubit.open();
    repository.remote = page([], older: true, cursor: const MediaCursor(3, 2));
    await cubit.older();
    repository.remote = page([]);
    await cubit.older();
    expect(repository.requests.last.before?.seq, 3);
    expect(repository.requests.last.before?.key, 2);
  });

  test(
    'revoked read access clears visible media during older pagination',
    () async {
      await cubit.open(seed: twenty);
      final held = repository.held = Completer();
      final loading = cubit.older();
      held.completeError(const TinodeException(403, 'Permission denied'));
      await loading;
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.error, isTrue);
      expect(cubit.state.busy, isFalse);
    },
  );

  test('delete arriving during paging is replayed after completion', () async {
    await cubit.open(seed: twenty);
    final held = repository.held = Completer();
    final request = cubit.older();
    repository.visible.remove(twenty.id);
    repository.events.add(Object());
    await Future<void>.delayed(Duration.zero);
    held.complete(page([ten]));
    await request;
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(cubit.state.items.map((i) => i.id), [ten.id]);
    expect(cubit.state.currentId, ten.id);
    repository.held = null;
    repository.remote = page([ten]);
    await cubit.refresh();
    expect(
      repository.requests.last.around?.seq,
      10,
      reason:
          'refresh follows the surviving selected item, not the deleted anchor',
    );
    expect(cubit.state.currentId, ten.id);
  });

  test('refresh never resurrects a hidden queued seed', () async {
    final queued = item(-1, id: 'local');
    repository
      ..online = false
      ..visible[queued.id] = queued;
    await cubit.open(seed: queued);
    expect(cubit.state.items.any((i) => i.id == queued.id), isTrue);
    repository.visible.remove(queued.id);
    repository.events.add(Object());
    await Future<void>.delayed(Duration.zero);
    await cubit.refresh();
    expect(cubit.state.items.any((i) => i.id == queued.id), isFalse);
  });

  test(
    'missing authoritative anchor does not silently show a neighbour',
    () async {
      repository.remote = page([twenty], found: false);
      await cubit.open(seed: ten);
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.error, isTrue);
    },
  );

  test(
    'missing offline anchor does not select cached neighbouring media',
    () async {
      repository
        ..online = false
        ..local = page([twenty], offline: true, found: false);
      await cubit.open(around: const MediaCursor(11, 0));
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.error, isTrue);
    },
  );

  test('missing queued deep link is unavailable, not latest media', () async {
    await cubit.open(pendingId: 'missing', entityIndex: 2);
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.error, isTrue);
    expect(repository.requests, isEmpty);
  });

  test(
    'late response belongs to neither a replacement account nor session',
    () async {
      final held = repository.held = Completer();
      final opening = cubit.open(seed: ten);
      await Future<void>.delayed(Duration.zero);
      repository.generation++;
      held.complete(page([thirty]));
      await opening;
      expect(cubit.state.items.any((i) => i.seq == 30), isFalse);
    },
  );
}
