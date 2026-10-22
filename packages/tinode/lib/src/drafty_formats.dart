part of 'drafty.dart';

// Tinode's graphemeIndices: map every UTF-16 unit to its containing grapheme.
List<int> _graphemeIndices(String text) {
  final indices = <int>[];
  var grapheme = 0;
  for (final character in text.characters) {
    indices.addAll(List.filled(character.length, grapheme++));
  }
  return indices;
}

JsonMap? _draftyEntity(JsonMap doc, int key) {
  final entities = doc['ent'];
  if (entities is! List || key < 0 || key >= entities.length) return null;
  final entity = entities[key];
  return entity is Map ? Map<String, dynamic>.unmodifiable(entity) : null;
}

Iterable<JsonMap> _draftyFormats(JsonMap doc) sync* {
  final raw = doc['txt'];
  final length = raw is String ? raw.characters.length : 0;
  for (final item in DraftyCodec._maps(doc['fmt'])) {
    final at = DraftyCodec._integer(item['at'] ?? 0);
    final len = DraftyCodec._integer(item['len'] ?? 0);
    if (at == null ||
        len == null ||
        at < -1 ||
        len < 0 ||
        (at >= 0 && at + len > length)) {
      continue;
    }
    final type = item['tp'];
    if (type != null && (type is! String || type.isEmpty)) continue;
    final key = type == null ? DraftyCodec._integer(item['key'] ?? 0) : null;
    if (type == null && (key == null || _draftyEntity(doc, key) == null)) {
      continue;
    }
    yield Map.unmodifiable({
      'at': at,
      'len': len,
      if (type != null) 'tp': type,
      if (key != null) 'key': key,
    });
  }
}
