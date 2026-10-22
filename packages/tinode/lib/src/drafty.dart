import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:markdown/markdown.dart' as md;

import 'tinode_gateway.dart' show JsonMap;

part 'drafty_formats.dart';
part 'drafty_markdown.dart';
part 'drafty_quote.dart';
part 'drafty_spoiler.dart';
part 'drafty_presentation.dart';

/// Canonical Drafty JSON only: no parallel AST or persisted rendering model.
/// Tinode 0.25 offsets use grapheme clusters, not UTF-16 indices or code points.
abstract final class DraftyCodec {
  static const mime = 'text/x-drafty';

  /// Only outgoing composer text is parsed; decode/forward remain literal.
  static JsonMap markdown(String value) => _MarkdownDrafty().convert(value);

  /// Safe reading views; neither method rewrites the stored/wire document.
  static Iterable<JsonMap> formats(JsonMap doc) => _draftyFormats(doc);
  static JsonMap? entity(JsonMap doc, int key) => _draftyEntity(doc, key);

  /// Read-only canonical views. Call only for a message with `head.reply`.
  static ({JsonMap? quote, JsonMap body}) splitReply(JsonMap doc) =>
      _splitReply(doc);

  /// Referenced media with their original entity keys (also outbox blob keys).
  static Iterable<({int entityIndex, JsonMap entity})> attachments(
    JsonMap doc, {
    bool excludeQuotes = false,
  }) =>
      _attachments(doc, excludeQuotes: excludeQuotes);

  /// Collapse's opt-in HD extension. Other HD ranges remain permanently hidden.
  static JsonMap? spoiler(JsonMap doc, JsonMap format) =>
      _draftySpoiler(doc, format);

  /// Explicit Copy includes spoilers; previews/search must use [previewText].
  static String copyText(Object? content) => _copyDrafty(decode(content));

  /// Chat-list text excludes hidden content, quotes and inline media markers.
  static String previewText(Object? content) {
    if (content is String) return content;
    final doc = content is JsonMap ? content : decode(content);
    final raw = doc['txt'];
    final characters = (raw is String ? raw : '').characters.toList();
    final hidden = List.filled(characters.length + 1, 0);
    for (final format in formats(doc)) {
      final at = format['at'] as int, len = format['len'] as int;
      if (at < 0 || len == 0) continue;
      final key = format['key'];
      final attachment = key is int ? entity(doc, key) : null;
      final type = format['tp'] ?? attachment?['tp'];
      if (const {'HD', 'QQ', 'QR', 'IM', 'AU', 'VD'}.contains(type)) {
        hidden[at]++;
        hidden[at + len]--;
      } else if (type == 'BR') {
        characters[at] = '\n';
      }
    }
    final result = StringBuffer();
    var depth = 0;
    for (var i = 0; i < characters.length; i++) {
      depth += hidden[i];
      if (depth == 0) result.write(characters[i]);
    }
    return result.toString().trim();
  }

  /// Plain strings stay literal. They are not interpreted as JSON or Markdown.
  /// Unknown JSON entity types and fields survive decode/forward unchanged.
  static JsonMap decode(Object? content) {
    if (content is String) return text(content);
    if (content is Map) {
      return Map<String, dynamic>.from(jsonDecode(jsonEncode(content)) as Map);
    }
    return {'txt': ''};
  }

  static String plainText(Object? content) {
    if (content is String) return content;
    final doc = content is JsonMap ? content : decode(content);
    final raw = doc['txt'];
    final characters = (raw is String ? raw : '').characters.toList();
    for (final format in formats(doc)) {
      final at = format['at'] as int;
      if (format['tp'] == 'BR' && at >= 0 && at < characters.length) {
        characters[at] = '\n';
      }
    }
    return characters.join();
  }

  static JsonMap text(String value) {
    final characters = value.characters.toList();
    final formatting = <JsonMap>[];
    for (var i = 0; i < characters.length; i++) {
      if (characters[i] == '\n' || characters[i] == '\r\n') {
        characters[i] = ' ';
        formatting.add({'tp': 'BR', 'at': i, 'len': 1});
      }
    }
    return {
      'txt': characters.join(),
      if (formatting.isNotEmpty) 'fmt': formatting,
    };
  }

  static JsonMap media({
    required String type,
    required String ref,
    required String name,
    required String mime,
    required int size,
    String caption = '',
    int? width,
    int? height,
    int? duration,
    String? preview,
    String? thumbnail,
  }) {
    if (!['IM', 'AU', 'VD', 'EX'].contains(type)) {
      throw ArgumentError.value(type, 'type', 'Unsupported media type');
    }
    // Empty refs are valid in the local outbox until upload completes.
    if (size < 0) throw ArgumentError('Invalid media metadata');
    final inline = type != 'EX';
    final doc = text(inline ? ' $caption' : caption);
    final formatting = _maps(doc['fmt']).toList()
      ..add({'at': inline ? 0 : -1, 'len': inline ? 1 : 0, 'key': 0});
    return {
      ...doc,
      'fmt': formatting,
      'ent': [
        {
          'tp': type,
          'data': {
            'mime': mime,
            'ref': ref,
            'name': name,
            'size': size,
            if (width != null) 'width': width,
            if (height != null) 'height': height,
            if (duration != null) 'duration': duration,
            if (preview != null) 'preview': preview,
            if (thumbnail != null) 'val': thumbnail,
          },
        }
      ],
    };
  }

  /// The caller also supplies `head.reply` with the original server sequence.
  static JsonMap reply({
    required Object content,
    required Object quote,
    required String authorId,
    required String authorName,
  }) {
    var quoted = <String, dynamic>{
      'txt': authorName,
      'fmt': [
        {'at': 0, 'len': authorName.characters.length, 'key': 0}
      ],
      'ent': [
        {
          'tp': 'MN',
          'data': {'val': authorId}
        }
      ],
    };
    quoted = _append(_append(quoted, text('\n')), _quoteExcerpt(quote));
    final formats = _maps(quoted['fmt']).toList()
      ..add({
        'tp': 'QQ',
        'at': 0,
        'len': (quoted['txt'] as String).characters.length
      });
    quoted['fmt'] = formats;
    return _append(_append(quoted, text('\n')), decode(content));
  }

  /// The caller supplies `head.forwarded`; structured media is never flattened.
  static JsonMap forward(Object content) => decode(content);

  static JsonMap _append(JsonMap left, JsonMap right) {
    final prefix = left['txt'] is String ? left['txt'] as String : '';
    final suffix = right['txt'] is String ? right['txt'] as String : '';
    final prefixLength = prefix.characters.length;
    // Entity positions are protocol keys: malformed/null slots cannot be removed.
    final leftEntities = left['ent'] is List ? left['ent'] as List : const [];
    final rightEntities =
        right['ent'] is List ? right['ent'] as List : const [];
    final formatting = _maps(left['fmt']).toList();
    for (final item in _maps(right['fmt'])) {
      final at = _integer(item['at'] ?? 0);
      final key = item['tp'] == null ? _integer(item['key'] ?? 0) : null;
      formatting.add({
        ...item,
        if (at != null) 'at': at < 0 ? at : at + prefixLength,
        if (key != null) 'key': key + leftEntities.length,
      });
    }
    return {
      ...left,
      'txt': '$prefix$suffix',
      if (formatting.isNotEmpty) 'fmt': formatting,
      if (leftEntities.isNotEmpty || rightEntities.isNotEmpty)
        'ent': [...leftEntities, ...rightEntities],
    };
  }

  static Iterable<JsonMap> _maps(Object? value) => value is List
      ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item))
      : const <JsonMap>[];

  static int? _integer(Object? value) =>
      value is num && value.isFinite && value == value.truncateToDouble()
          ? value.toInt()
          : null;
}
