import 'dart:typed_data';

import 'package:collapse_tinode/tinode.dart';

import '../../domain/chat/media_models.dart';
import '../chat/chats_repository.dart';
import 'media_repository.dart';

/// Independent media cursors/cache; never calls ChatCubit or marks messages read.
class MediaGalleryRepository {
  MediaGalleryRepository(this.chats, this.media);
  final ChatsRepository chats;
  final MediaRepository media;
  String get account => chats.currentUserId;
  int get generation => chats.sessionGeneration;
  String get _scope => '${chats.serverId}|$account';
  bool get online =>
      account.isNotEmpty &&
      chats.gateway.connected &&
      chats.gateway.userId == account;

  Stream<Object> changes(String topic) => chats.changesFor(topic);

  Future<MediaItem?> find(
    String topic,
    int seq,
    int entity, {
    String? messageId,
  }) async {
    final scope = _scope, epoch = generation;
    final row = messageId == null
        ? await chats.database.messageRow(scope, topic, seq)
        : await chats.database.messageById(scope, messageId);
    _check(scope, epoch);
    if (row != null) {
      if (row.topicId != topic || row.hidden || row.deleted) return null;
      final message = chats.database.toMessage(row);
      if (!DraftyCodec.attachments(
        message.content is JsonMap
            ? message.content as JsonMap
            : DraftyCodec.decode(message.content),
        excludeQuotes: true,
      ).any((a) => a.entityIndex == entity)) {
        return null;
      }
      return MediaItem.fromMessage(message, entity);
    }
    final item = await chats.database.mediaItem(
      scope,
      topic,
      MediaCursor(seq, entity),
    );
    _check(scope, epoch);
    return item;
  }

  Future<List<MediaItem>> retained(String topic, List<MediaItem> items) async {
    final scope = _scope, epoch = generation;
    final result = <MediaItem>[];
    for (final item in items) {
      var current = await chats.database.mediaItem(scope, topic, item.cursor);
      if (current == null && item.pending) {
        final message = await chats.database.messageById(scope, item.messageId);
        if (message != null && !message.hidden && !message.deleted) {
          current = await chats.database.mediaItem(
            scope,
            topic,
            MediaCursor(message.seq, item.entityIndex),
          );
        }
      }
      if (current != null) result.add(current);
    }
    _check(scope, epoch);
    return List.unmodifiable(result..sort(MediaItem.compare));
  }

  Future<MediaPage> cached(
    String topic,
    MediaCategory category, {
    MediaCursor? before,
    MediaCursor? after,
    MediaCursor? around,
    int limit = 24,
  }) async {
    final scope = _scope, epoch = generation;
    final ready = await chats.database.prepareMedia(scope, topic);
    final db = chats.database;
    final anchor = around == null
        ? null
        : await db.mediaItem(scope, topic, around);
    final items = around == null
        ? await db.mediaPage(
            scope,
            topic,
            category,
            before: before,
            after: after,
            limit: limit + 1,
          )
        : [
            ...await db.mediaPage(
              scope,
              topic,
              category,
              before: around,
              limit: limit ~/ 2,
            ),
            if (anchor != null && category.types.contains(anchor.type)) anchor,
            ...await db.mediaPage(
              scope,
              topic,
              category,
              after: around,
              limit: limit ~/ 2,
            ),
          ];
    _check(scope, epoch);
    final visible =
        (after != null
                ? items.take(limit)
                : items.skip(items.length > limit ? items.length - limit : 0))
            .toList();
    final hasOlder =
        visible.isNotEmpty &&
        (await db.mediaPage(
          scope,
          topic,
          category,
          before: visible.first.cursor,
          limit: 1,
        )).isNotEmpty;
    final hasNewer =
        visible.isNotEmpty &&
        (await db.mediaPage(
          scope,
          topic,
          category,
          after: visible.last.cursor,
          limit: 1,
        )).isNotEmpty;
    _check(scope, epoch);
    return MediaPage(
      items: List.unmodifiable(visible),
      hasOlder: hasOlder,
      hasNewer: hasNewer,
      offline: true,
      cacheIndexed: ready,
      anchorFound:
          around == null ||
          visible.any((item) => item.cursor.compareTo(around) == 0),
      olderCursor: visible.firstOrNull?.cursor,
      newerCursor: visible.lastOrNull?.cursor,
    );
  }

  Future<MediaPage> page(
    String topic,
    MediaCategory category, {
    MediaCursor? before,
    MediaCursor? after,
    MediaCursor? around,
    int limit = 24,
    int? snapshot,
  }) async {
    if (!online) {
      return cached(
        topic,
        category,
        before: before,
        after: after,
        around: around,
        limit: limit,
      );
    }
    final scope = _scope, epoch = generation;
    late final JsonMap response;
    try {
      await chats.prepareMediaTopic(topic);
      _check(scope, epoch);
      response = await chats.gateway.media(
        topic,
        kind: category.name,
        before: before?.toJson(),
        after: after?.toJson(),
        around: around?.toJson(),
        limit: limit,
        snapshot: snapshot,
      );
    } on TinodeException catch (error) {
      _check(scope, epoch);
      if (error.code == 403 || error.code == 404) {
        await chats.database.clearMedia(scope, topic);
      }
      rethrow;
    }
    _check(scope, epoch);
    final items = <MediaItem>[];
    for (final raw in (response['items'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final seq = (raw['seq'] as num?)?.toInt() ?? 0;
      final key = (raw['key'] as num?)?.toInt() ?? -1;
      final type = raw['type'];
      if (seq <= 0 || key < 0 || !category.types.contains(type)) continue;
      final sender = raw['from']?.toString() ?? '';
      final id = sender == account && raw['clientId'] is String
          ? raw['clientId'] as String
          : '$topic:$seq';
      items.add(
        MediaItem(
          topicId: topic,
          messageId: id,
          seq: seq,
          entityIndex: key,
          type: type as String,
          data: Map<String, dynamic>.from(raw['data'] as Map? ?? {}),
          senderId: sender,
          createdAt: DateTime.parse(raw['ts'] as String).toUtc(),
          inline: raw['inline'] == true,
        ),
      );
    }
    items.sort(MediaItem.compare);
    final deletionId = (response['delId'] as num?)?.toInt() ?? 0;
    if (deletionId >
        ((await chats.database.topicRow(scope, topic))?.deletionId ?? 0)) {
      await chats.prepareMediaTopic(topic);
      _check(scope, epoch);
    }
    await chats.database.cacheMedia(
      scope,
      items,
      check: () => _check(scope, epoch),
    );
    _check(scope, epoch);
    // A local hide or a deletion racing this response must win over metadata.
    final visible = <MediaItem>[];
    for (final item in items) {
      final cached = await chats.database.mediaItem(scope, topic, item.cursor);
      if (cached != null) visible.add(cached);
    }
    _check(scope, epoch);
    return MediaPage(
      items: List.unmodifiable(visible..sort(MediaItem.compare)),
      hasOlder: response['hasOlder'] == true,
      hasNewer: response['hasNewer'] == true,
      snapshot: (response['snapshot'] as num?)?.toInt() ?? 0,
      anchorFound:
          response['anchorFound'] != false &&
          (around == null ||
              visible.any((item) => item.cursor.compareTo(around) == 0)),
      olderCursor: items.firstOrNull?.cursor,
      newerCursor: items.lastOrNull?.cursor,
    );
  }

  Future<Uint8List> bytes(MediaItem item) async {
    final scope = _scope, epoch = generation;
    var data = item.data;
    if (item.pending ||
        (item.inline &&
            data['val'] == null &&
            (data['ref']?.toString().isEmpty ?? true))) {
      final message = await chats.mediaMessage(
        item.topicId,
        item.seq,
        id: item.pending ? item.messageId : null,
      );
      _check(scope, epoch);
      if (message == null || message.hidden) {
        throw StateError('Media unavailable');
      }
      if (message.pending) {
        final queued = await chats.pendingAttachmentBytes(
          message,
          item.entityIndex,
        );
        _check(scope, epoch);
        if (queued != null) return queued;
      }
      final entity = DraftyCodec.entity(
        message.content is JsonMap
            ? message.content as JsonMap
            : DraftyCodec.decode(message.content),
        item.entityIndex,
      );
      data = Map<String, dynamic>.from(entity?['data'] as Map? ?? {});
    }
    final ref = media.draftyReference(data);
    if (ref.isEmpty) throw StateError('Media unavailable');
    final result = await media.bytes(ref);
    _check(scope, epoch);
    return result;
  }

  void _check(String scope, int epoch) {
    if (account.isEmpty || scope != _scope || epoch != generation) {
      throw StateError('Media belongs to a closed session');
    }
  }
}
