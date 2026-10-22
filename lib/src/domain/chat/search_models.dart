/// Newest pending messages precede server history, each with its own cursor.
typedef SearchCursor = ({bool pending, int order});

class SearchHit {
  const SearchHit({
    required this.id,
    required this.topicId,
    required this.seq,
    required this.localSeq,
    required this.senderId,
    required this.createdAt,
    required this.snippet,
  });

  final String id;
  final String topicId;
  final int seq;
  final int localSeq;
  final String senderId;
  final DateTime createdAt;
  final String snippet;

  bool get pending => seq < 0;
  SearchCursor get cursor =>
      (pending: pending, order: pending ? localSeq : seq);
}

class SearchPage {
  const SearchPage({
    required this.hits,
    required this.cacheIndexed,
    required this.historyComplete,
    required this.canLoadHistory,
    this.nextCursor,
  });

  final List<SearchHit> hits;
  final SearchCursor? nextCursor;

  /// False while old cached rows still need bounded, resumable preparation.
  final bool cacheIndexed;

  /// Coverage includes all sequences through the current server watermark.
  final bool historyComplete;
  final bool canLoadHistory;
}
