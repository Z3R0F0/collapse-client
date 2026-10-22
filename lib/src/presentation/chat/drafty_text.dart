import 'package:collapse_tinode/tinode.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme.dart';
import 'drafty_spoiler.dart';
import 'message_layout.dart';

/// Rendering adapter over canonical grapheme ranges; no parallel Drafty AST.
class DraftyText extends StatefulWidget {
  const DraftyText({super.key, required this.content, this.header, this.footer})
    : _style = null,
      _depth = 0;
  const DraftyText._nested(this.content, this._style, this._depth)
    : header = null,
      footer = null;
  final Object content;
  final Widget? header;
  final Widget? footer;
  final TextStyle? _style;
  final int _depth;
  @override
  State<DraftyText> createState() => _DraftyTextState();
}

class _DraftyTextState extends State<DraftyText> {
  final _recognizers = <TapGestureRecognizer>[];
  void _clear() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _text(context, constraints.maxWidth),
  );

  Widget _text(BuildContext context, double maxWidth) {
    _clear();
    final doc = switch (widget.content) {
      Map<String, dynamic> content => content,
      _ => DraftyCodec.decode(widget.content),
    };
    final text = doc['txt'];
    final characters = (text is String ? text : '').characters.toList();
    final points = <int>{0, characters.length};
    final starting = <int, List<Map<String, dynamic>>>{};
    final ending = <int, List<Map<String, dynamic>>>{};
    final formats = DraftyCodec.formats(doc).toList();
    for (final f in formats) {
      final start = f['at'] as int;
      final end = start + (f['len'] as int);
      if (start < 0 || end == start) continue;
      points.add(start);
      points.add(end);
      (starting[start] ??= []).add(f);
      (ending[end] ??= []).add(f);
    }
    final sorted = points.toList()..sort();
    final active = <Map<String, dynamic>>{};
    final spans = <InlineSpan>[];
    var spoilerEnd = 0;
    for (var i = 0; i + 1 < sorted.length; i++) {
      final start = sorted[i], end = sorted[i + 1];
      active.removeAll(ending[start] ?? const []);
      active.addAll(starting[start] ?? const []);
      if (start < spoilerEnd) continue;
      var style = widget._style ?? context.textStyles.bodyMedium!;
      String? link;
      var hidden = false;
      var lineBreak = false;
      Map<String, dynamic>? spoiler;
      Map<String, dynamic>? spoilerFormat;
      // Visit only overlapping styles, not every format for every text span.
      for (final f in active) {
        final key = f['key'];
        final entity = key is int ? DraftyCodec.entity(doc, key) : null;
        final type = f['tp'] ?? entity?['tp'];
        switch (type) {
          case 'ST':
            style = style.copyWith(fontWeight: FontWeight.bold);
          case 'EM':
            style = style.copyWith(fontStyle: FontStyle.italic);
          case 'DL':
            style = style.copyWith(decoration: TextDecoration.lineThrough);
          case 'CO':
            style = style.copyWith(
              fontFamily: context.textStyles.labelMedium?.fontFamily,
              backgroundColor: context.colors.surfaceContainerHighest,
            );
          case 'QQ' || 'QR':
            style = style.copyWith(
              color: context.colors.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            );
          case 'LN':
            final data = entity?['data'];
            if (data is Map) link = data['url']?.toString();
          case 'MN' || 'HT':
            style = style.copyWith(color: context.colors.primary);
          case 'HL':
            style = style.copyWith(
              backgroundColor: context.colors.primaryContainer,
            );
          case 'BR':
            lineBreak = true;
          case 'HD':
            final fragment = widget._depth < 8
                ? DraftyCodec.spoiler(doc, f)
                : null;
            if (fragment == null) {
              hidden = true;
            } else {
              spoiler = fragment;
              spoilerFormat = f;
            }
          case 'IM' || 'AU' || 'VD':
            hidden = true;
        }
      }
      if (hidden) continue;
      if (spoiler != null && spoilerFormat != null) {
        final format = spoilerFormat;
        spoilerEnd = (format['at'] as int) + (format['len'] as int);
        // A generic HD overlap must never become revealable through this opt-in
        // extension, including malformed documents received from other clients.
        final permanentlyHidden = formats.any((f) {
          final key = f['key'];
          final entity = key is int ? DraftyCodec.entity(doc, key) : null;
          return (f['tp'] ?? entity?['tp']) == 'HD' &&
              DraftyCodec.spoiler(doc, f) == null &&
              (f['at'] as int) < spoilerEnd &&
              (f['at'] as int) + (f['len'] as int) > start;
        });
        if (!permanentlyHidden) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: DraftySpoiler(
                  key: ValueKey((format['at'], format['key'], spoiler['txt'])),
                  child: DraftyText._nested(spoiler, style, widget._depth + 1),
                ),
              ),
            ),
          );
        }
        continue;
      }
      TapGestureRecognizer? recognizer;
      final uri = link == null ? null : Uri.tryParse(link);
      if (uri != null && {'https', 'http', 'mailto'}.contains(uri.scheme)) {
        recognizer = TapGestureRecognizer()
          ..onTap = () => launchUrl(uri, mode: LaunchMode.externalApplication);
        _recognizers.add(recognizer);
        style = style.copyWith(
          color: context.colors.primary,
          decoration: TextDecoration.combine([
            if (style.decoration != null) style.decoration!,
            TextDecoration.underline,
          ]),
        );
      }
      spans.add(
        TextSpan(
          text: lineBreak ? '\n' : characters.sublist(start, end).join(),
          style: style,
          recognizer: recognizer,
        ),
      );
    }
    final span = TextSpan(children: spans);
    if (widget.footer == null) return Text.rich(span);
    return MessageLayout(
      header: widget.header,
      content: Text.rich(span, textWidthBasis: TextWidthBasis.longestLine),
      footer: widget.footer!,
      inlineFooter: true,
    );
  }
}
