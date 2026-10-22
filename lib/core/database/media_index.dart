part of 'app_database.dart';

extension _MediaIndex on AppDatabase {
  Future<void> _indexMedia(String scope, ChatMessage message) async {
    await (delete(mediaEntries)..where(
          (m) =>
              m.scope.equals(scope) &
              m.topicId.equals(message.topicId) &
              (m.seq.equals(message.seq) | m.clientId.equals(message.id)),
        ))
        .go();
    if (message.hidden) return;
    final doc = message.content is Map<String, dynamic>
        ? message.content as Map<String, dynamic>
        : DraftyCodec.decode(message.content);
    await _cacheMedia(scope, [
      for (final attachment in DraftyCodec.attachments(
        doc,
        excludeQuotes: true,
      ))
        MediaItem.fromMessage(message, attachment.entityIndex),
    ]);
  }

  Future<void> _cacheMedia(String scope, List<MediaItem> items) async {
    final ranges = <String, List<dynamic>>{};
    for (final item in items) {
      final known = await messageRow(scope, item.topicId, item.seq);
      if (known?.hidden == true || known?.deleted == true) continue;
      final deleted = ranges[item.topicId] ??=
          jsonDecode(
                (await topicRow(scope, item.topicId))?.deletedRanges ?? '[]',
              )
              as List;
      if (deleted.any((r) => item.seq >= r[0] && item.seq < r[1])) continue;
      // Inline originals stay in messages/outbox. Gallery pages never multiply
      // binary payloads by the number of thumbnails mounted in a grid.
      final data = {...item.data}..remove('val');
      final thumbnail = item.data['val'];
      if (item.type == 'IM' &&
          thumbnail is String &&
          thumbnail.length <= 16384 &&
          (data['ref']?.toString().isNotEmpty ?? false)) {
        data.putIfAbsent('preview', () => thumbnail);
      }
      final preview = data['preview'];
      if (preview is String && preview.length > 32768) data.remove('preview');
      await into(mediaEntries).insertOnConflictUpdate(
        MediaEntriesCompanion.insert(
          scope: scope,
          topicId: item.topicId,
          seq: item.seq,
          entityIndex: item.entityIndex,
          clientId: known?.clientId ?? item.messageId,
          type: item.type,
          senderId: item.senderId,
          createdAtMs: item.createdAt.millisecondsSinceEpoch,
          data: jsonEncode(data),
          isInline: Value(item.inline),
        ),
      );
    }
  }

  /// Lazy upgrade of already cached messages, bounded to one small SQL batch.
  Future<bool> _prepareMediaBatch(String scope, String topicId) async {
    final key = (scope, topicId);
    if (_mediaPrepared.contains(key)) return true;
    final before = _mediaCursors[key];
    final query = select(messages)
      ..where(
        (m) =>
            m.scope.equals(scope) &
            m.topicId.equals(topicId) &
            m.seq.isBiggerThanValue(0),
      );
    if (before != null) query.where((m) => m.seq.isSmallerThanValue(before));
    query
      ..orderBy([(m) => OrderingTerm.desc(m.seq)])
      ..limit(40);
    final rows = await transaction(() async {
      // Read and index one snapshot; logout cannot clear the source rows and
      // then have a stale backfill recreate metadata outside that transaction.
      final rows = await query.get();
      for (final row in rows) {
        await _indexMedia(scope, toMessage(row));
      }
      return rows;
    });
    if (rows.length < 40) {
      _mediaPrepared.add(key);
      _mediaCursors.remove(key);
      return true;
    }
    _mediaCursors[key] = rows.last.seq;
    return false;
  }
}
