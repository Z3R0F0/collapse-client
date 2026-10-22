import '../../domain/chat/media_models.dart';

class MediaGalleryState {
  const MediaGalleryState({
    this.items = const [],
    this.currentId,
    this.loading = false,
    this.loadingOlder = false,
    this.loadingNewer = false,
    this.hasOlder = false,
    this.hasNewer = false,
    this.offline = false,
    this.error = false,
  });
  final List<MediaItem> items;
  final String? currentId;
  final bool loading;
  final bool loadingOlder;
  final bool loadingNewer;
  final bool hasOlder;
  final bool hasNewer;
  final bool offline;
  final bool error;
  bool get busy => loading || loadingOlder || loadingNewer;
  MediaItem? get current =>
      items.where((item) => item.id == currentId).firstOrNull;

  MediaGalleryState copyWith({
    List<MediaItem>? items,
    String? currentId,
    bool? loading,
    bool? loadingOlder,
    bool? loadingNewer,
    bool? hasOlder,
    bool? hasNewer,
    bool? offline,
    bool error = false,
  }) => MediaGalleryState(
    items: items ?? this.items,
    currentId: currentId ?? this.currentId,
    loading: loading ?? this.loading,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    loadingNewer: loadingNewer ?? this.loadingNewer,
    hasOlder: hasOlder ?? this.hasOlder,
    hasNewer: hasNewer ?? this.hasNewer,
    offline: offline ?? this.offline,
    error: error,
  );
}
