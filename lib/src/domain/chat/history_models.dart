import 'chat_models.dart';

enum HistoryDirection { older, newer }

enum HistoryAvailability { available, exhausted, blocked }

/// Half-open bounds. Server sequences and local sequences never share a range.
class SequenceRange {
  const SequenceRange(this.start, this.end);
  final int start;
  final int end;
  bool get isEmpty => start >= end;
  bool contains(int value) => value >= start && value < end;

  @override
  bool operator ==(Object other) =>
      other is SequenceRange && start == other.start && end == other.end;
  @override
  int get hashCode => Object.hash(start, end);
  @override
  String toString() => '[$start, $end)';
}

/// Authoritative paging position, independent of which rows remain visible.
class HistorySpan {
  const HistorySpan({
    required this.server,
    this.local,
    this.retainedLocalIds = const {},
  });
  final SequenceRange server;

  /// A retained locally-originated suffix. ACK changes delivery/seq, not this
  /// localSeq position; rows outside [server] retain their suffix order until
  /// navigation includes their server sequence or selects a fresh window.
  final SequenceRange? local;

  /// Exact bounded optimistic membership; [local] is only its paging cursor.
  /// ACK sequence values cannot prove or revoke membership.
  final Set<String> retainedLocalIds;

  @override
  bool operator ==(Object other) =>
      other is HistorySpan &&
      server == other.server &&
      local == other.local &&
      retainedLocalIds.length == other.retainedLocalIds.length &&
      retainedLocalIds.containsAll(other.retainedLocalIds);
  @override
  int get hashCode =>
      Object.hash(server, local, Object.hashAllUnordered(retainedLocalIds));
}

class HistoryEdge {
  const HistoryEdge(this.availability, {this.gap});
  final HistoryAvailability availability;
  final SequenceRange? gap;
  bool get canLoad => availability == HistoryAvailability.available;
  bool get isExhausted => availability == HistoryAvailability.exhausted;
  bool get isBlocked => availability == HistoryAvailability.blocked;
}

class HistoryWindow {
  const HistoryWindow(
    this.messages, {
    required this.span,
    required this.older,
    required this.newer,
    this.rebaseAnchorId,
  });
  final List<ChatMessage> messages;
  final HistorySpan span;
  final HistoryEdge older;
  final HistoryEdge newer;

  /// This explicit page action replaced ACK/local ordering with canonical
  /// history around one retained ID. Ordinary snapshots leave this null.
  final String? rebaseAnchorId;
}
