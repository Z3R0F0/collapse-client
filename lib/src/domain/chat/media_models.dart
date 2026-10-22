import 'package:collapse_tinode/tinode.dart';

import 'chat_models.dart';

enum MediaCategory {
  visual(['IM', 'VD']),
  audio(['AU']),
  files(['EX']);

  const MediaCategory(this.types);
  final List<String> types;
  static MediaCategory of(String type) =>
      values.firstWhere((value) => value.types.contains(type));
}

class MediaCursor implements Comparable<MediaCursor> {
  const MediaCursor(this.seq, this.key);
  final int seq;
  final int key;
  Map<String, int> toJson() => {'seq': seq, 'key': key};
  @override
  int compareTo(MediaCursor other) {
    final order = seq.compareTo(other.seq);
    return order == 0 ? key.compareTo(other.key) : order;
  }
}

/// Stable message/entity identity, independent of a gallery's page index or URL.
class MediaItem {
  const MediaItem({
    required this.topicId,
    required this.messageId,
    required this.seq,
    required this.entityIndex,
    required this.type,
    required this.data,
    required this.senderId,
    required this.createdAt,
    this.inline = false,
  });

  factory MediaItem.fromMessage(ChatMessage message, int entityIndex) {
    final doc = message.content is JsonMap
        ? message.content as JsonMap
        : DraftyCodec.decode(message.content);
    final entity = DraftyCodec.entity(doc, entityIndex)!;
    final data = Map<String, dynamic>.from(entity['data'] as Map? ?? {});
    return MediaItem(
      topicId: message.topicId,
      messageId: message.id,
      seq: message.seq,
      entityIndex: entityIndex,
      type: entity['tp'] as String,
      data: data,
      senderId: message.senderId,
      createdAt: message.createdAt,
      inline: data['val'] != null,
    );
  }

  factory MediaItem.fromJson(String topic, Map<dynamic, dynamic> json) =>
      MediaItem(
        topicId: topic,
        messageId: json['clientId'] as String,
        seq: (json['seq'] as num).toInt(),
        entityIndex: (json['key'] as num).toInt(),
        type: json['type'] as String,
        data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
        senderId: json['from'] as String,
        createdAt: DateTime.parse(json['ts'] as String).toUtc(),
        inline: json['inline'] == true,
      );

  /// Route restoration needs no binary payloads or second in-memory registry.
  Map<String, dynamic> toJson() => {
    'clientId': messageId,
    'seq': seq,
    'key': entityIndex,
    'type': type,
    'data': {...data}..remove('val'),
    'from': senderId,
    'ts': createdAt.toIso8601String(),
    'inline': inline,
  };

  final String topicId;
  final String messageId;
  final int seq;
  final int entityIndex;
  final String type;
  final Map<String, dynamic> data;
  final String senderId;
  final DateTime createdAt;
  final bool inline;
  String get id => '$topicId:$messageId:$entityIndex';
  bool get pending => seq < 0;
  bool get visual => type == 'IM' || type == 'VD';
  MediaCategory get category => MediaCategory.of(type);
  MediaCursor get cursor => MediaCursor(seq, entityIndex);
  Object heroTag(String surface) => (surface, topicId, messageId, entityIndex);

  static int compare(MediaItem a, MediaItem b) {
    if (a.pending != b.pending) return a.pending ? 1 : -1;
    if (a.pending) {
      final order = a.createdAt.compareTo(b.createdAt);
      return order == 0 ? a.entityIndex.compareTo(b.entityIndex) : order;
    }
    return a.cursor.compareTo(b.cursor);
  }
}

class MediaPage {
  const MediaPage({
    required this.items,
    this.hasOlder = false,
    this.hasNewer = false,
    this.snapshot = 0,
    this.offline = false,
    this.anchorFound = true,
    this.cacheIndexed = true,
    this.olderCursor,
    this.newerCursor,
  });
  final List<MediaItem> items;
  final bool hasOlder;
  final bool hasNewer;
  final int snapshot;
  final bool offline;
  final bool anchorFound;
  final bool cacheIndexed;
  final MediaCursor? olderCursor;
  final MediaCursor? newerCursor;
}
