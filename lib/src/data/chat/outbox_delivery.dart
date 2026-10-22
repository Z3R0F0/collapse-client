part of 'chats_repository.dart';

extension _OutboxDelivery on ChatsRepository {
  Future<void> _flushOutbox() async {
    final scope = _activeScope;
    final userId = currentUserId;
    final generation = _generation;
    // A logout/login can restore the same scope while an old upload is pending.
    bool isCurrentSession() => _generation == generation && _scope == scope;
    final pending = await database.pendingOutbox(scope);
    for (final queued in pending) {
      if (!isCurrentSession() || !_networkReady) break;
      if (queued.nextRetryAt > DateTime.now().millisecondsSinceEpoch) continue;
      try {
        await ensureTopic(queued.topicId);
        if (!isCurrentSession() || !_networkReady) return;
        if (queued.ambiguous) {
          // Reconcile the full interval after enqueue's server watermark.
          // Wall clocks and a fixed recent page cannot prove an ACK was lost.
          final topic = await database.topicRow(scope, queued.topicId);
          var cursor = queued.afterSeq;
          final latest = topic?.serverSeq ?? 0;
          while (cursor < latest && isCurrentSession() && _networkReady) {
            final end = min(latest + 1, cursor + 41);
            await _fetch(
              scope,
              queued.topicId,
              since: cursor + 1,
              before: end,
              limit: 40,
            );
            final reconciled = await database.messageById(
              scope,
              queued.clientId,
            );
            if (reconciled == null || reconciled.seq > 0) break;
            cursor = end - 1;
          }
        }
        var row = await database.messageById(scope, queued.clientId);
        if (!isCurrentSession() || !_networkReady) return;
        if (row == null || row.seq > 0 || row.hidden) continue;
        await database.outboxAttempt(
          scope,
          queued.clientId,
          delivery: Delivery.sending,
        );
        if (!isCurrentSession()) return;
        _changes.add(ChatChange(queued.topicId, reset: true));
        Object content = jsonDecode(row.content) as Object;
        for (final upload in await database.uploads(scope, queued.clientId)) {
          if (!isCurrentSession() || !_networkReady) return;
          if (upload.remoteRef != null) continue;
          final ref = await gateway.upload(
            upload.bytes,
            name: upload.name,
            mime: upload.mime,
          );
          if (!isCurrentSession()) return;
          final drafty = Map<String, dynamic>.from(
            jsonDecode(jsonEncode(content)) as Map,
          );
          final entities = drafty['ent'] as List;
          final entity = Map<String, dynamic>.from(
            entities[upload.entityIndex] as Map,
          );
          entity['data'] = {
            ...Map<String, dynamic>.from(entity['data'] as Map? ?? {}),
            'ref': ref,
          };
          entities[upload.entityIndex] = entity;
          content = drafty;
          await database.uploaded(
            scope,
            queued.clientId,
            upload.entityIndex,
            ref,
            content,
          );
        }
        if (!isCurrentSession() || !_networkReady) return;
        row = await database.messageById(scope, queued.clientId);
        if (!isCurrentSession() || !_networkReady) return;
        if (row == null || row.seq > 0 || row.hidden) continue;
        final head = Map<String, dynamic>.from(jsonDecode(row.head) as Map);
        final refs = <String>{
          ...((head['attachments'] as List?) ?? []).whereType<String>(),
        };
        if (content is Map && content['ent'] is List) {
          for (final entity in content['ent'] as List) {
            if (entity is! Map || entity['data'] is! Map) continue;
            final data = entity['data'] as Map;
            for (final field in ['ref', 'preref']) {
              final ref = data[field];
              if (ref is String && ref.isNotEmpty) {
                final uri = Uri.tryParse(ref);
                if (uri != null &&
                    (!uri.hasScheme || uri.host == gateway.endpoint.host)) {
                  refs.add(ref);
                }
              }
            }
          }
        }
        if (refs.isNotEmpty) head['attachments'] = refs.toList();
        // Mark before I/O: process death after server acceptance is ambiguous too.
        await database.outboxAttempt(
          scope,
          queued.clientId,
          delivery: Delivery.sending,
          ambiguous: true,
        );
        if (!isCurrentSession() || !_networkReady) return;
        final ctrl = await gateway.publish(
          queued.topicId,
          content: content,
          head: head,
          clientId: queued.clientId,
        );
        final seq = AppDatabase.intValue((ctrl['params'] as Map?)?['seq']);
        if (seq <= 0) {
          throw StateError('Publish acknowledgement has no sequence');
        }
        // A publish already accepted by the server still merges into its own
        // account cache, even if its acknowledgement arrives after logout.
        final merged = await database.mergeMessage(
          scope,
          ChatMessage(
            id: queued.clientId,
            topicId: queued.topicId,
            seq: seq,
            localSeq: queued.localSeq,
            senderId: userId,
            createdAt: ChatsRepository._timestamp(ctrl['ts'], row.createdAtMs),
            content: content,
            head: head,
          ),
          userId,
        );
        if (isCurrentSession()) {
          _changes.add(ChatChange(queued.topicId, message: merged));
        }
      } catch (_) {
        if (!isCurrentSession()) return;
        final delay = min(60, 1 << min(queued.attempts, 6));
        await database.outboxAttempt(
          scope,
          queued.clientId,
          delivery: _networkReady ? Delivery.failed : Delivery.queued,
          attempts: queued.attempts + 1,
          nextRetryAt: DateTime.now().millisecondsSinceEpoch + delay * 1000,
          error: 'retry_required',
        );
        if (isCurrentSession()) {
          _changes.add(ChatChange(queued.topicId, reset: true));
        }
      }
    }
    if (isCurrentSession()) {
      final remaining = await database.pendingOutbox(scope);
      if (!isCurrentSession()) return;
      _retryTimer?.cancel();
      _retryTimer = null;
      // Fresh enqueues have already marked the active drain dirty. Only
      // deferred retries need a timer; they must not delay another fresh send.
      if (remaining.isNotEmpty && !_flushAgain) {
        _retryTimer = Timer(
          const Duration(seconds: 2),
          () => unawaited(flushOutbox()),
        );
      }
    }
  }
}
