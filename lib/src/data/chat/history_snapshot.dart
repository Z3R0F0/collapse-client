part of 'chats_repository.dart';

extension _HistorySnapshot on ChatsRepository {
  Future<HistoryWindow?> _inspectHistoryWindow(
    String topicId,
    HistorySpan requested, {
    HistoryDirection retain = HistoryDirection.older,
    int capacity = 120,
    ChatMessage? include,
  }) async {
    final scope = _scope, generation = _generation;
    if (scope == null) return null;
    final result = await database.transaction(() async {
      final topic = await database.topicRow(scope, topicId);
      if (topic == null) return null;
      var server = requested.server;
      var local = requested.local;
      var localIds = Set<String>.of(requested.retainedLocalIds);
      if (include != null && include.topicId == topicId && !include.hidden) {
        if (include.pending) {
          localIds.add(include.id);
          local = SequenceRange(
            local?.start ?? include.localSeq,
            max(local?.end ?? 0, include.localSeq + 1),
          );
        } else {
          final frontier = await _localServerFrontier(scope, topic, requested);
          if (include.seq >= frontier) {
            final retained = local == null
                ? null
                : await database.firstLocalAck(scope, topicId, localIds);
            server = SequenceRange(
              server.isEmpty
                  ? min(frontier, retained ?? frontier)
                  : server.start,
              max(server.end, include.seq + 1),
            );
          }
        }
      }
      // A span must not bridge cache islands, even when live data extends it.
      final components = _historyRanges(
        topic,
      ).where((r) => r.start < server.end && r.end > server.start).toList();
      if (!server.isEmpty) {
        final component = retain == HistoryDirection.older
            ? components.firstOrNull
            : components.lastOrNull;
        server = component == null
            ? SequenceRange(server.start, server.start)
            : SequenceRange(
                max(server.start, component.start),
                min(server.end, component.end),
              );
      }
      final count = capacity.clamp(1, 120);
      var rows = await database.historyRows(
        scope,
        topicId,
        HistorySpan(server: server, local: local, retainedLocalIds: localIds),
        retain: retain,
        limit: count + 1,
      );
      if (rows.length > count) {
        rows = retain == HistoryDirection.older
            ? rows.take(count).toList()
            : rows.skip(rows.length - count).toList();
        final boundary = retain == HistoryDirection.older
            ? rows.last
            : rows.first;
        final inServer = server.contains(boundary.seq);
        if (retain == HistoryDirection.older) {
          if (inServer) {
            server = SequenceRange(server.start, boundary.seq + 1);
            local = null;
          } else {
            local = SequenceRange(local!.start, boundary.localSeq + 1);
          }
        } else if (inServer) {
          server = SequenceRange(boundary.seq, server.end);
        } else {
          server = SequenceRange(server.end, server.end);
          local = SequenceRange(boundary.localSeq, local!.end);
        }
      }
      // Membership follows selected IDs, not ACK sequence comparisons. IDs
      // incorporated into the canonical server span or actually evicted do
      // not reappear through a later local-range query.
      localIds = rows
          .where(
            (row) => localIds.contains(row.id) && !server.contains(row.seq),
          )
          .map((row) => row.id)
          .toSet();
      if (localIds.isEmpty) local = null;
      HistoryEdge? older;
      if (server.isEmpty && local != null) {
        final before = await database.localHistoryRows(
          scope,
          topicId,
          serverEnd: server.end,
          before: local.start,
          limit: 1,
        );
        if (before.isNotEmpty) {
          older = const HistoryEdge(HistoryAvailability.available);
        }
      }
      final span = HistorySpan(
        server: server,
        local: local,
        retainedLocalIds: Set.unmodifiable(localIds),
      );
      older ??= await _serverHistoryEdge(
        scope,
        topic,
        server.isEmpty && local != null
            ? await _localOlderFrontier(scope, topic, span)
            : server.start,
        HistoryDirection.older,
      );
      var newer = await _serverHistoryEdge(
        scope,
        topic,
        await _localServerFrontier(scope, topic, span),
        HistoryDirection.newer,
      );
      if (newer.isExhausted) {
        final after = await database.localHistoryRows(
          scope,
          topicId,
          serverEnd: server.end,
          since: local == null ? 0 : local.end - 1,
          limit: 1,
        );
        if (after.isNotEmpty) {
          newer = const HistoryEdge(HistoryAvailability.available);
        }
      }
      return HistoryWindow(
        List.unmodifiable(rows),
        span: span,
        older: older,
        newer: newer,
      );
    });
    return _historyActive(scope, generation) ? result : null;
  }
}
