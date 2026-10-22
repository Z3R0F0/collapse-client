part of 'tinode_gateway.dart';

extension _GatewayMedia on TinodeGateway {
  Future<JsonMap> _media(String topic,
      {String kind = 'visual',
      JsonMap? before,
      JsonMap? after,
      JsonMap? around,
      int limit = 24,
      int? snapshot}) async {
    final cursors = [before, after, around].whereType<JsonMap>().toList();
    if (!{'visual', 'audio', 'files'}.contains(kind) ||
        limit < 1 ||
        limit > 40 ||
        (snapshot != null && snapshot < 0) ||
        cursors.length > 1 ||
        cursors.any((cursor) =>
            cursor.keys.any((key) => key != 'seq' && key != 'key') ||
            cursor['seq'] is! int ||
            (cursor['seq'] as int) < 1 ||
            cursor['key'] is! int ||
            (cursor['key'] as int) < 0)) {
      throw ArgumentError('Invalid media page query');
    }
    // This extension returns one correlated metadata page, never data packets.
    // Attachment/session ownership remains with the calling repository.
    final meta = await _request(
        'get',
        {
          'topic': topic,
          'what': 'media',
          'media': {
            'kind': kind,
            'limit': limit,
            if (before != null) 'before': before,
            if (after != null) 'after': after,
            if (around != null) 'around': around,
            if (snapshot != null) 'snapshot': snapshot,
          },
        },
        metaSection: 'media',
        ctrlWhat: 'media');
    final page = meta['media'];
    if (page is! Map || page['items'] is! List) {
      throw const TinodeException(502, 'Invalid media page response');
    }
    return Map<String, dynamic>.from(page);
  }
}
