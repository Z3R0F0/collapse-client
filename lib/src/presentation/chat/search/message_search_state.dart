import '../../../domain/chat/search_models.dart';

class MessageSearchState {
  const MessageSearchState({
    this.query = '',
    this.page,
    this.loading = false,
    this.loadingHistory = false,
    this.error = false,
    this.canPrevious = false,
  });

  final String query;
  final SearchPage? page;
  final bool loading;
  final bool loadingHistory;
  final bool error;
  final bool canPrevious;
  bool get busy => loading || loadingHistory;

  MessageSearchState copyWith({
    SearchPage? page,
    bool? loading,
    bool? loadingHistory,
    bool error = false,
    bool? canPrevious,
  }) => MessageSearchState(
    query: query,
    page: page ?? this.page,
    loading: loading ?? this.loading,
    loadingHistory: loadingHistory ?? this.loadingHistory,
    error: error,
    canPrevious: canPrevious ?? this.canPrevious,
  );
}
