part of 'drafty.dart';

// Follows Tinode replyContent: remove nested quotes, shorten and lighten entities.
// Bounds apply only to the excerpt, never the original/new message or forwarding.
JsonMap _quoteExcerpt(Object source, {bool plain = false}) {
  final doc = source is JsonMap ? source : DraftyCodec.decode(source);
  final raw = doc['txt'];
  final text = (raw is String ? raw : '').characters.toList();
  final formats = DraftyCodec.formats(doc).map((f) => {...f}).toList();
  var attachments = 0;
  for (final f in formats) {
    if (f['at'] != -1) continue;
    if (++attachments > 3) continue;
    f['at'] = text.length;
    f['len'] = 1;
    text.add(' ');
  }
  final hidden = List.filled(text.length + 1, 0);
  final entities = <int, JsonMap>{};
  final fallback = <JsonMap>{};
  final mediaPositions = <int>{};
  for (final f in formats) {
    final at = f['at'] as int, len = f['len'] as int;
    if (at < 0 || len == 0) continue;
    final key = f['key'];
    final entity = key is int
        ? entities.putIfAbsent(
            key, () => _lightQuoteEntity(DraftyCodec.entity(doc, key)!))
        : null;
    final type = f['tp'] ?? entity?['tp'];
    if (const {'QQ', 'QR', 'HD'}.contains(type)) {
      hidden[at]++;
      hidden[at + len]--;
    } else if (const {'IM', 'AU', 'VD', 'EX'}.contains(type)) {
      final data = entity?['data'] as JsonMap? ?? {};
      final ref = data['ref'], value = data['val'];
      final usable = (ref is String && ref.isNotEmpty) ||
          (value is String && value.isNotEmpty) ||
          (value is List && value.isNotEmpty);
      if (plain || !usable) {
        text[at] = _quoteMediaLabel(type, data);
        hidden[at + 1]++;
        hidden[at + len]--;
        fallback.add(f);
      } else {
        mediaPositions.add(at);
      }
    }
  }
  final positions = List.filled(text.length + 1, 0);
  final output = StringBuffer();
  var depth = 0, count = 0, bytes = 0;
  var truncated = false;
  for (var i = 0; i < text.length; i++) {
    depth += hidden[i];
    if (depth == 0 && !truncated) {
      for (final character in text[i].characters) {
        if (output.isEmpty &&
            character.trim().isEmpty &&
            !mediaPositions.contains(i)) {
          continue;
        }
        final size = utf8.encode(character).length;
        if (count == 255 || bytes + size > 4093) {
          truncated = true;
          break;
        }
        output.write(character);
        count++;
        bytes += size;
      }
    }
    positions[i + 1] = output.length;
  }
  final visible = output.toString();
  final indices = _graphemeIndices(visible);
  final result = <String, dynamic>{'txt': '$visible${truncated ? '…' : ''}'};
  if (plain) return result;
  final keptFormats = <JsonMap>[], keptEntities = <JsonMap>[];
  final keys = <int, int>{};
  // Include exact JSON container overhead; commas below conservatively overcount.
  bytes = utf8.encode(jsonEncode({...result, 'fmt': [], 'ent': []})).length;
  for (final f in formats) {
    final at = f['at'] as int, len = f['len'] as int;
    if (at < 0 ||
        len == 0 ||
        const {'QQ', 'QR', 'HD', 'BR'}.contains(f['tp'])) {
      continue;
    }
    final start = positions[at];
    final end = positions[at + len];
    final key = f['key'];
    if (start == end || fallback.contains(f)) continue;
    final entity = key is int ? entities[key] : null;
    final newKey = key is int ? keys[key] ?? keptEntities.length : null;
    final format = {
      'at': indices[start],
      'len': indices[end - 1] - indices[start] + 1,
      if (f['tp'] != null) 'tp': f['tp'],
      if (newKey != null) 'key': newKey
    };
    bytes += utf8.encode(jsonEncode(format)).length + 1;
    if (entity != null && !keys.containsKey(key)) {
      bytes += utf8.encode(jsonEncode(entity)).length + 1;
      keys[key as int] = newKey!;
      keptEntities.add(entity);
    }
    if (bytes > 16 * 1024) return _quoteExcerpt(source, plain: true);
    keptFormats.add(format);
  }
  return {
    ...result,
    if (keptFormats.isNotEmpty) 'fmt': keptFormats,
    if (keptEntities.isNotEmpty) 'ent': keptEntities
  };
}

JsonMap _lightQuoteEntity(JsonMap entity) {
  final data = entity['data'];
  final kept = <String, dynamic>{};
  if (data is Map) {
    for (final key in const [
      'act',
      'height',
      'duration',
      'incoming',
      'mime',
      'name',
      'premime',
      'preref',
      'preview',
      'ref',
      'size',
      'state',
      'url',
      'val',
      'width'
    ]) {
      final value = data[key];
      if (value is num ||
          value is bool ||
          (value is String &&
              value.length <= 4096 &&
              utf8.encode(value).length <= 4096)) {
        kept[key] = value;
      } else if (value is List &&
          value.length <= 4096 &&
          value.every((v) => v is int)) {
        if (utf8.encode(jsonEncode(value)).length <= 4096) {
          kept[key] = [...value];
        }
      }
    }
  }
  return {'tp': entity['tp'], if (kept.isNotEmpty) 'data': kept};
}

String _quoteMediaLabel(Object? type, JsonMap data) {
  final icon =
      switch (type) { 'IM' => '📷', 'AU' => '🎙', 'VD' => '🎬', _ => '📎' };
  final name = (data['name'] is String ? data['name'] as String : '')
      .characters
      .take(48)
      .join();
  return '[$icon${name.isEmpty ? '' : ' $name'}]';
}
