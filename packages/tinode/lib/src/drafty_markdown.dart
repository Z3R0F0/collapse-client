part of 'drafty.dart';

/// A short adapter from the maintained Markdown AST to Tinode's wire format.
/// No HTML rendering, remote image loading or additional persisted model.
class _MarkdownDrafty {
  _MarkdownDrafty({bool insideSpoiler = false})
      : _insideSpoiler = insideSpoiler;

  final _text = StringBuffer();
  final _formats = <JsonMap>[];
  final _entities = <JsonMap>[];
  final bool _insideSpoiler;
  bool _lineEnded = true;

  JsonMap convert(String source) {
    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: [_ChatItalicSyntax(), _ChatSpoilerSyntax()],
      blockSyntaxes: [const _ChatBlankLineSyntax()],
      encodeHtml: false,
    );
    return _convert(document.parse(source));
  }

  JsonMap _convert(Iterable<md.Node> nodes) {
    for (final node in nodes) {
      _node(node);
    }
    final text = _text.toString().replaceFirst(RegExp(r'\n+$'), '');
    final formats = <JsonMap>[];
    final characters = text.characters.toList();
    final hidden = List.filled(characters.length + 1, 0);
    // Tinode JS maps each UTF-16 position to its containing grapheme once.
    // This also includes combining marks split across Markdown style nodes.
    final indices = _graphemeIndices(text);
    for (final format in _formats) {
      final start = format['at'] as int;
      final end = (start + (format['len'] as int)).clamp(0, text.length);
      if (start >= end) continue;
      final at = indices[start];
      final length = indices[end - 1] - at + 1;
      formats.add({
        ...format,
        'at': at,
        'len': length,
      });
      final key = format['key'];
      if (key is int && _entities[key]['tp'] == 'HD') {
        hidden[at]++;
        hidden[at + length]--;
        // Keep a grapheme split across AST nodes whole (e.g. an outside accent).
        _entities[key]['data']['spoiler']['txt'] =
            characters.getRange(at, at + length).join();
      }
    }
    var depth = 0;
    for (var i = 0; i < characters.length; i++) {
      depth += hidden[i];
      if (depth > 0 && characters[i].trim().isNotEmpty) characters[i] = '•';
    }
    final result = DraftyCodec.text(characters.join());
    formats.insertAll(0, DraftyCodec._maps(result['fmt']));
    return {
      ...result,
      if (formats.isNotEmpty) 'fmt': formats,
      if (_entities.isNotEmpty) 'ent': _entities,
    };
  }

  void _write(String text) {
    if (text.isEmpty) return;
    _text.write(text);
    _lineEnded = text.endsWith('\n');
  }

  void _break() {
    if (_text.isNotEmpty && !_lineEnded) _write('\n');
  }

  void _node(md.Node node,
      {int depth = 0, bool inlineParagraph = false, bool codeBlock = false}) {
    if (node is md.Text) {
      _write(node.text);
      return;
    }
    if (node is! md.Element) return;
    final tag = node.tag;
    if (tag == 'br' || tag == 'blank') {
      _write('\n');
      return;
    }
    if (!_insideSpoiler &&
        (tag == 'spoiler' || (tag == 'a' && _spoilerOnlyLabel(node)))) {
      // Isolate links and other metadata too: stock push previews may retain
      // short `val` fields or expand LN URLs. Only this private HD field holds
      // the fragment. Nested spoiler delimiters flatten within the same reveal.
      final fragment = _MarkdownDrafty(insideSpoiler: true)._convert(
          tag == 'spoiler' ? node.children ?? const <md.Node>[] : [node]);
      final start = _text.length;
      _write(fragment['txt'] as String);
      _entity('HD', {'spoiler': fragment}, start);
      return;
    }
    if (tag == 'input' && node.attributes['type'] == 'checkbox') {
      _write(node.attributes.containsKey('checked') ? '[x] ' : '[ ] ');
      return;
    }
    if (tag == 'img') {
      // Markdown images remain readable references, never implicit downloads.
      final alt = node.attributes['alt'] ?? '';
      final source = node.attributes['src'] ?? '';
      _write(
          alt.isEmpty ? source : '$alt${source.isEmpty ? '' : ' ($source)'}');
      return;
    }
    if (tag == 'ul' || tag == 'ol') {
      _break();
      var number = int.tryParse(node.attributes['start'] ?? '') ?? 1;
      for (final item in node.children ?? <md.Node>[]) {
        _write('${'  ' * depth}${tag == 'ol' ? '${number++}.' : '•'} ');
        if (item is md.Element && item.tag == 'li') {
          for (final child in item.children ?? <md.Node>[]) {
            _node(child, depth: depth + 1, inlineParagraph: true);
          }
        } else {
          _node(item, depth: depth + 1);
        }
        _break();
      }
      return;
    }
    final heading = const {'h1', 'h2', 'h3', 'h4', 'h5', 'h6'}.contains(tag);
    final block = heading ||
        const {'pre', 'blockquote', 'tr', 'hr'}.contains(tag) ||
        (tag == 'p' && !inlineParagraph);
    if (block) _break();
    if ((tag == 'td' || tag == 'th') && !_lineEnded) _write(' | ');
    final start = _text.length;
    if (tag == 'hr') _write('---');
    for (final child in node.children ?? <md.Node>[]) {
      _node(child, depth: depth, codeBlock: tag == 'pre');
    }
    final type = switch (tag) {
      'strong' || 'th' => 'ST',
      'em' => 'EM',
      'del' => 'DL',
      'code' => codeBlock ? null : 'CO',
      'blockquote' => 'QQ',
      _ => heading ? 'ST' : null,
    };
    if (type != null) {
      _formats.add({'at': start, 'len': _text.length - start, 'tp': type});
    }
    if (tag == 'code' && codeBlock) {
      final language = node.attributes['class'] ?? '';
      _entity(
          'CO',
          {
            'language':
                language.startsWith('language-') ? language.substring(9) : '',
            'block': true,
          },
          start);
    }
    if (tag == 'a') {
      final url = node.attributes['href'];
      final uri = url == null ? null : Uri.tryParse(url);
      if (uri != null &&
          const {'http', 'https', 'mailto'}.contains(uri.scheme)) {
        _entity('LN', {'url': url}, start);
      }
    }
    if (block) _break();
  }

  void _entity(String type, JsonMap data, int start) {
    _formats.add(
        {'at': start, 'len': _text.length - start, 'key': _entities.length});
    _entities.add({'tp': type, 'data': data});
  }

  // A completely hidden link label must not disclose its target via previews.
  // A partially visible label remains an intentionally public clickable link.
  bool _spoilerOnlyLabel(md.Element link) {
    var spoiler = false, visible = false;
    void visit(md.Node node) {
      if (node is md.Text) {
        visible |= node.text.trim().isNotEmpty;
      } else if (node is md.Element) {
        if (node.tag == 'spoiler') {
          spoiler = true;
        } else if (node.tag == 'img') {
          visible = true;
        } else {
          for (final child in node.children ?? const <md.Node>[]) {
            visit(child);
          }
        }
      }
    }

    visit(link);
    return spoiler && !visible;
  }
}

// Telegram's shared double-delimiter core, with Collapse' existing CommonMark
// escapes, single-emphasis aliases and nesting retained as explicit extensions.
class _ChatItalicSyntax extends md.DelimiterSyntax {
  _ChatItalicSyntax()
      : super('_+',
            requiresDelimiterRun: true,
            startCharacter: 95,
            tags: [md.DelimiterTag('em', 1), md.DelimiterTag('em', 2)]);
}

class _ChatSpoilerSyntax extends md.DelimiterSyntax {
  _ChatSpoilerSyntax()
      : super(r'\|+',
            requiresDelimiterRun: true,
            startCharacter: 124,
            allowIntraWord: true,
            tags: [md.DelimiterTag('spoiler', 2)]);
}

class _ChatBlankLineSyntax extends md.EmptyBlockSyntax {
  const _ChatBlankLineSyntax();

  @override
  md.Node? parse(md.BlockParser parser) {
    super.parse(parser);
    return parser.parentSyntax == null ? md.Element.empty('blank') : null;
  }
}
