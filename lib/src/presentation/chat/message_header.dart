import 'package:collapse_tinode/tinode.dart';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../domain/chat/chat_models.dart';

class MessageHeader extends StatelessWidget {
  const MessageHeader({
    super.key,
    required this.message,
    this.quote,
    this.onReply,
  });
  final ChatMessage message;
  final JsonMap? quote;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final reply = (int.tryParse('${message.head['reply']}') ?? 0) > 0;
    final forwarded = message.head['forwarded'] != null;
    if (!reply && !forwarded) return const SizedBox.shrink();
    final doc = quote;
    final preview = doc == null ? '' : DraftyCodec.previewText(doc);
    final author =
        doc != null &&
        DraftyCodec.formats(doc).any((format) {
          final key = format['key'];
          return format['at'] == 0 &&
              key is int &&
              DraftyCodec.entity(doc, key)?['tp'] == 'MN';
        });
    final lines = preview.split('\n');
    final name = author ? lines.first : '';
    final excerpt = author ? lines.skip(1).join('\n').trim() : preview;
    final media = doc == null
        ? <({int entityIndex, JsonMap entity})>[]
        : DraftyCodec.attachments(doc).toList();
    final entity = media.isEmpty ? null : media.first.entity;
    final type = entity?['tp'];
    final data = entity?['data'];
    final filename = data is Map && data['name'] is String
        ? data['name'] as String
        : '';
    final mediaLabel = switch (type) {
      'IM' => context.l10n.photo,
      'AU' => context.l10n.audio,
      'VD' => context.l10n.video,
      'EX' => context.l10n.file,
      _ => '',
    };
    final detail = excerpt.isNotEmpty
        ? excerpt
        : filename.isNotEmpty
        ? filename
        : mediaLabel;
    return Semantics(
      label: reply ? context.l10n.replying : context.l10n.forwardedMessage,
      child: Material(
        color: context.colors.surfaceContainerHighest.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(context.collapseTheme.radius),
        child: InkWell(
          onTap: reply ? onReply : null,
          borderRadius: BorderRadius.circular(context.collapseTheme.radius),
          child: Container(
            constraints: reply ? const BoxConstraints(minHeight: 48) : null,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: context.colors.primary, width: 2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  switch (type) {
                    'IM' => Icons.photo_outlined,
                    'VD' => Icons.videocam_outlined,
                    'AU' => Icons.mic_none,
                    'EX' => Icons.attach_file,
                    _ => reply ? Icons.subdirectory_arrow_right : Icons.forward,
                  },
                  size: 18,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (forwarded && reply)
                        Text(
                          context.l10n.forwardedMessage,
                          style: context.textStyles.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        name.isNotEmpty
                            ? name
                            : reply
                            ? context.l10n.replying
                            : context.l10n.forwardedMessage,
                        style: context.textStyles.labelSmall?.copyWith(
                          color: context.colors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (detail.isNotEmpty)
                        Text(
                          detail,
                          style: context.textStyles.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
