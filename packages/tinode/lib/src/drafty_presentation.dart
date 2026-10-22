part of 'drafty.dart';

const _mediaTypes = {'IM', 'AU', 'VD', 'EX'};

String? _formatType(JsonMap doc, JsonMap format) {
  final value =
      format['tp'] ?? DraftyCodec.entity(doc, format['key'] as int)?['tp'];
  return value is String ? value : null;
}

({JsonMap? quote, JsonMap body}) _splitReply(JsonMap doc) {
  final text =
      (doc['txt'] is String ? doc['txt'] as String : '').characters.toList();
  final formats = DraftyCodec.formats(doc).toList();
  var end = 0;
  for (final format in formats) {
    if (format['at'] == 0 &&
        const {'QQ', 'QR'}.contains(_formatType(doc, format)) &&
        (format['len'] as int) > end) {
      end = format['len'] as int;
    }
  }
  if (end == 0) return (quote: null, body: doc);
  var bodyStart = end;
  if (end < text.length &&
      (text[end] == '\n' ||
          text[end] == '\r\n' ||
          formats.any((f) =>
              f['at'] == end &&
              f['len'] == 1 &&
              _formatType(doc, f) == 'BR'))) {
    bodyStart++;
  }
  JsonMap slice(int start, int stop, {required bool quote}) {
    final kept = <JsonMap>[];
    for (final format in formats) {
      final at = format['at'] as int, len = format['len'] as int;
      if (at == -1) {
        if (!quote) kept.add(format);
        continue;
      }
      if (quote &&
          at == 0 &&
          len == end &&
          const {'QQ', 'QR'}.contains(_formatType(doc, format))) {
        continue;
      }
      final first = at < start ? start : at;
      final last = at + len > stop ? stop : at + len;
      if (last > first) {
        kept.add({...format, 'at': first - start, 'len': last - first});
      }
    }
    // Never compact entities: pending bytes and viewer URLs address these keys.
    return {...doc, 'txt': text.sublist(start, stop).join(), 'fmt': kept};
  }

  return (
    quote: slice(0, end, quote: true),
    body: slice(bodyStart, text.length, quote: false)
  );
}

Iterable<({int entityIndex, JsonMap entity})> _attachments(JsonMap doc,
    {required bool excludeQuotes}) sync* {
  // Existing entity-only messages have no text-placement information.
  // Explicit empty fmt is a valid slice with no referenced attachments.
  if (!doc.containsKey('fmt')) {
    final entities = doc['ent'];
    if (entities is List) {
      for (var index = 0; index < entities.length; index++) {
        final entity = DraftyCodec.entity(doc, index);
        if (entity != null && _mediaTypes.contains(entity['tp'])) {
          yield (entityIndex: index, entity: entity);
        }
      }
    }
    return;
  }
  final formats = DraftyCodec.formats(doc).toList();
  final length =
      (doc['txt'] is String ? doc['txt'] as String : '').characters.length;
  final hidden = List.filled(length + 1, 0);
  for (final format in formats) {
    final at = format['at'] as int, len = format['len'] as int;
    final type = _formatType(doc, format);
    if (at >= 0 &&
        len > 0 &&
        (type == 'HD' ||
            (excludeQuotes && const {'QQ', 'QR'}.contains(type)))) {
      hidden[at]++;
      hidden[at + len]--;
    }
  }
  final visible = List.filled(length + 1, 0);
  var depth = 0;
  for (var i = 0; i < length; i++) {
    depth += hidden[i];
    visible[i + 1] = visible[i] + (depth == 0 ? 1 : 0);
  }
  final media = formats
      .where((format) =>
          format['key'] is int &&
          _mediaTypes.contains(_formatType(doc, format)))
      .toList()
    ..sort((a, b) {
      final left = a['at'] as int, right = b['at'] as int;
      return (left < 0 ? length : left).compareTo(right < 0 ? length : right);
    });
  final used = <int>{};
  for (final format in media) {
    final at = format['at'] as int, len = format['len'] as int;
    final key = format['key'] as int;
    if (at >= 0 && visible[at + len] == visible[at]) continue;
    if (used.add(key)) {
      yield (entityIndex: key, entity: DraftyCodec.entity(doc, key)!);
    }
  }
}
