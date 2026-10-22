import '../../domain/chat/chat_models.dart';
import '../../domain/chat/history_models.dart';

/// A data window and explicit navigation intent. No pixel/scroll position lives
/// here: the list widget owns its viewport and layout-time anchoring.
class ChatState {
  const ChatState({
    this.window,
    this.loading = false,
    this.paging,
    this.unreadCount = 0,
    this.error,
    this.revision = 0,
    this.navigationEpoch = 0,
    this.targetId,
    this.arrivalIds = const {},
  });

  final HistoryWindow? window;
  final bool loading;
  final HistoryDirection? paging;

  /// Account/topic unread, shared with Home and independent of window position.
  final int unreadCount;
  final String? error;
  final int revision;

  /// Changes only when a ready snapshot is explicitly opened at latest/target.
  final int navigationEpoch;
  final String? targetId;
  final Set<String> arrivalIds;

  List<ChatMessage> get messages => window?.messages ?? const [];
  bool get loadingOlder => paging == HistoryDirection.older;
  bool get loadingNewer => paging == HistoryDirection.newer;
  bool get hasOlder => window?.older.canLoad ?? false;
  bool get hasNewer => window?.newer.canLoad ?? false;
  bool get atLiveEdge => window?.newer.isExhausted ?? true;

  ChatState copyWith({
    HistoryWindow? window,
    bool? loading,
    HistoryDirection? paging,
    bool clearPaging = false,
    int? unreadCount,
    String? error,
    bool clearError = false,
    Set<String> arrivalIds = const {},
  }) => ChatState(
    window: window ?? this.window,
    loading: loading ?? this.loading,
    paging: clearPaging ? null : paging ?? this.paging,
    unreadCount: unreadCount ?? this.unreadCount,
    error: clearError ? null : error ?? this.error,
    revision: revision + 1,
    navigationEpoch: navigationEpoch,
    targetId: targetId,
    arrivalIds: arrivalIds,
  );
}
