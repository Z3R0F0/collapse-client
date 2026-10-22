part of 'drafty.dart';

// Hidden text and its link targets live only in this optional entity payload.
// Stock Tinode push/plain/lightweight previews see the masked outer txt, never
// the fragment. No new server type, parallel storage or encryption is implied.
JsonMap? _draftySpoiler(JsonMap doc, JsonMap format) {
  if (format['tp'] != null) return null;
  final key = format['key'];
  if (key is! int) return null;
  final entity = DraftyCodec.entity(doc, key);
  final data = entity?['data'];
  if (entity?['tp'] != 'HD' || data is! Map) return null;
  final fragment = data['spoiler'];
  if (fragment is! Map || fragment.keys.any((key) => key is! String)) {
    return null;
  }
  final text = fragment['txt'];
  if (text is! String || text.characters.length != format['len']) return null;
  return Map<String, dynamic>.unmodifiable(fragment);
}

String _copyDrafty(JsonMap doc, [int depth = 0]) {
  final raw = doc['txt'];
  final text = (raw is String ? raw : '').characters.toList();
  final formats = DraftyCodec.formats(doc).toList();
  for (final format in formats) {
    final at = format['at'] as int;
    if (format['tp'] == 'BR' && at >= 0 && at < text.length) text[at] = '\n';
  }
  if (depth < 8) {
    // Preserve original slots: restoring BR/emoji can join graphemes. Even
    // overlapping ranges in an untrusted document must not shift other ranges.
    formats.sort((a, b) => (b['at'] as int).compareTo(a['at'] as int));
    for (final format in formats) {
      final at = format['at'] as int, len = format['len'] as int;
      if (at < 0 || len == 0) continue;
      final fragment = _draftySpoiler(doc, format);
      if (fragment != null) {
        text[at] = _copyDrafty(fragment, depth + 1);
        text.fillRange(at + 1, at + len, '');
      }
    }
  }
  return text.join();
}
