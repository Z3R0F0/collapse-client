part of 'chats_repository.dart';

extension _HistoryNavigation on ChatsRepository {
  Future<HistoryWindow?> _openHistory(
    String topicId, {
    int? aroundSeq,
    String? aroundId,
    int limit = 40,
    bool cacheOnly = false,
  }) async {
    final scope = _scope, generation = _generation;
    if (scope == null) return null;
    final count = limit.clamp(1, cacheOnly ? 120 : 40);
    if (!cacheOnly) {
      // A ready local target never waits for attachment/metadata or a missing
      // server tail. Reuse the same coverage-aware snapshot, not another cache.
      final cached = await _openHistory(
        topicId,
        aroundSeq: aroundSeq,
        aroundId: aroundId,
        limit: count,
        cacheOnly: true,
      );
      if (!_historyActive(scope, generation)) return null;
      final latest = aroundSeq == null && aroundId == null;
      final ready =
          cached != null &&
          (latest
              ? cached.messages.isNotEmpty ||
                    (cached.older.isExhausted && cached.newer.isExhausted)
              : cached.messages.any(
                  (row) => aroundId != null
                      ? row.id == aroundId
                      : row.seq == aroundSeq,
                ));
      if (ready) {
        unawaited(_reconcileTopic(topicId).catchError((Object _) {}));
        return cached;
      }
    }
    try {
      if (!cacheOnly) await ensureTopic(topicId);
    } catch (_) {
      /* Read the cache offline. */
    }
    if (!_historyActive(scope, generation)) return null;
    final selected = await database.transaction(() async {
      final topic = await database.topicRow(scope, topicId);
      if (topic == null) return null;
      final target = aroundId == null
          ? null
          : await database.messageById(scope, aroundId);
      if (aroundId != null &&
          (target == null ||
              target.topicId != topicId ||
              target.hidden ||
              target.deleted)) {
        return null;
      }
      final seq = target == null
          ? aroundSeq
          : (target.seq > 0 ? target.seq : null);
      List<ChatMessage> local = [];
      if (target?.seq != null && target!.seq < 0) {
        final before = await database.pendingMessages(
          scope,
          topicId,
          before: target.localSeq,
          limit: (count - 1) ~/ 2,
        );
        final after = await database.pendingMessages(
          scope,
          topicId,
          since: target.localSeq,
          limit: count - before.length - 1,
        );
        local = [...before, database.toMessage(target), ...after];
      } else if (aroundSeq == null && aroundId == null) {
        local = await database.pendingMessages(scope, topicId, limit: count);
      }
      return (topic: topic, seq: seq, local: local);
    });
    if (selected == null || !_historyActive(scope, generation)) return null;
    final local = selected.local.isEmpty
        ? null
        : SequenceRange(
            selected.local.first.localSeq,
            selected.local.last.localSeq + 1,
          );
    var server = SequenceRange(
      selected.topic.serverSeq + 1,
      selected.topic.serverSeq + 1,
    );
    final room = count - selected.local.length;
    if (selected.seq != null) {
      final seq = selected.seq!;
      final start = max(1, seq - count ~/ 2);
      final end = min(selected.topic.serverSeq + 1, start + count);
      final known = _historyComponent(selected.topic, seq);
      if (!cacheOnly &&
          _networkReady &&
          (known == null || known.start > start || known.end < end)) {
        await _fetch(scope, topicId, since: start, before: end, limit: count);
      }
      server = SequenceRange(start, end);
      final current = await database.topicRow(scope, topicId);
      final component = current == null
          ? null
          : _historyComponent(current, seq);
      if (component != null) {
        server = SequenceRange(
          max(start, component.start),
          min(end, component.end),
        );
      }
    } else if (room > 0) {
      server = await _expandServerHistory(
        scope,
        generation,
        topicId,
        server,
        HistoryDirection.older,
        room,
        fetch: !cacheOnly,
      );
      // Offline latest selects one cached component, never a union of islands.
      if (server.isEmpty) {
        final cached = await database.page(scope, topicId, limit: 1);
        if (cached.isNotEmpty) {
          server = SequenceRange(cached.last.seq + 1, cached.last.seq + 1);
          server = await _expandServerHistory(
            scope,
            generation,
            topicId,
            server,
            HistoryDirection.older,
            room,
            fetch: false,
          );
        }
      }
    }
    if (!_historyActive(scope, generation)) return null;
    return _inspectHistoryWindow(
      topicId,
      HistorySpan(
        server: server,
        local: local,
        retainedLocalIds: Set.unmodifiable(selected.local.map((row) => row.id)),
      ),
      retain: HistoryDirection.newer,
      capacity: count,
    );
  }

  Future<HistoryWindow?> _extendHistory(
    String topicId,
    HistorySpan span, {
    required HistoryDirection direction,
    int limit = 40,
    int capacity = 120,
    bool includeLocal = true,
    String? anchorId,
  }) async {
    final scope = _scope, generation = _generation;
    if (scope == null) return null;
    if (includeLocal && span.local != null) {
      final topic = await database.topicRow(scope, topicId);
      if (!_historyActive(scope, generation)) return null;
      final retainedAck = await database.firstLocalAck(
        scope,
        topicId,
        span.retainedLocalIds,
      );
      final frontier = topic == null
          ? span.server.end
          : await _localServerFrontier(scope, topic, span);
      if (topic != null &&
          topic.serverSeq + 1 > span.server.end &&
          (retainedAck != null || frontier < topic.serverSeq + 1)) {
        final current = await _inspectHistoryWindow(topicId, span);
        if (!_historyActive(scope, generation) || current == null) return null;
        final anchor =
            anchorId ??
            (direction == HistoryDirection.older
                ? current.messages.firstOrNull?.id
                : current.messages.lastOrNull?.id);
        if (anchor == null) return current;
        final canonical = await _openHistory(
          topicId,
          aroundId: anchor,
          limit: capacity,
          cacheOnly: true,
        );
        if (!_historyActive(scope, generation) ||
            canonical == null ||
            !canonical.messages.any((message) => message.id == anchor)) {
          return null;
        }
        return HistoryWindow(
          canonical.messages,
          span: canonical.span,
          older: canonical.older,
          newer: canonical.newer,
          rebaseAnchorId: anchor,
        );
      }
    }
    var server = span.server, local = span.local;
    final localIds = Set<String>.of(span.retainedLocalIds);
    var room = limit.clamp(1, 40);
    if (includeLocal &&
        direction == HistoryDirection.older &&
        server.isEmpty &&
        local != null) {
      final before = await database.localHistoryRows(
        scope,
        topicId,
        serverEnd: server.end,
        before: local.start,
        limit: room,
      );
      if (before.isNotEmpty) {
        localIds.addAll(before.map((row) => row.id));
        local = SequenceRange(before.first.localSeq, local.end);
        room -= before.length;
      }
      if (room > 0) {
        final topic = await database.topicRow(scope, topicId);
        if (topic != null) {
          final cursor = await _localOlderFrontier(
            scope,
            topic,
            HistorySpan(
              server: server,
              local: local,
              retainedLocalIds: localIds,
            ),
          );
          server = SequenceRange(cursor, cursor);
        }
      }
    }
    if (!_historyActive(scope, generation)) return null;
    var expandServer = true;
    if (includeLocal && direction == HistoryDirection.newer && local != null) {
      if (room > 0) {
        final topic = await database.topicRow(scope, topicId);
        if (topic != null) {
          final frontier = await _localServerFrontier(
            scope,
            topic,
            HistorySpan(server: server, local: local),
          );
          if (frontier >= topic.serverSeq + 1) {
            expandServer = false;
          } else {
            server = SequenceRange(
              server.isEmpty ? frontier : server.start,
              frontier,
            );
          }
        }
      }
    }
    if (room > 0 && expandServer) {
      server = await _expandServerHistory(
        scope,
        generation,
        topicId,
        server,
        direction,
        room,
      );
    }
    if (!_historyActive(scope, generation)) return null;
    if (includeLocal && direction == HistoryDirection.newer) {
      final selected = await database.transaction(() async {
        final topic = await database.topicRow(scope, topicId);
        // Do not cross to local rows while an ACK/live row opened a server gap.
        if (topic == null ||
            await _localServerFrontier(
                  scope,
                  topic,
                  HistorySpan(server: server, local: local),
                ) <
                topic.serverSeq + 1) {
          return <ChatMessage>[];
        }
        final added = await database.historyRows(
          scope,
          topicId,
          HistorySpan(server: SequenceRange(span.server.end, server.end)),
          limit: room,
        );
        return database.localHistoryRows(
          scope,
          topicId,
          serverEnd: server.end,
          since: local == null ? 0 : local.end - 1,
          limit: max(0, room - added.length),
        );
      });
      if (selected.isNotEmpty) {
        localIds.addAll(selected.map((row) => row.id));
        local = SequenceRange(
          local?.start ?? selected.first.localSeq,
          selected.last.localSeq + 1,
        );
      }
    }
    if (!_historyActive(scope, generation)) return null;
    return _inspectHistoryWindow(
      topicId,
      HistorySpan(
        server: server,
        local: local,
        retainedLocalIds: Set.unmodifiable(localIds),
      ),
      retain: direction == HistoryDirection.older
          ? HistoryDirection.older
          : HistoryDirection.newer,
      capacity: capacity,
    );
  }
}
