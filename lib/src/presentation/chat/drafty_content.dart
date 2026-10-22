import 'package:collapse_tinode/tinode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme.dart';
import '../../data/chat/chats_repository.dart';
import '../../domain/chat/chat_models.dart';
import 'attachment_view.dart';
import 'drafty_text.dart';
import 'message_footer.dart';
import 'message_header.dart';
import 'message_layout.dart';

export 'attachment_view.dart';
export 'drafty_text.dart';

class DraftyContent extends StatelessWidget {
  const DraftyContent({
    super.key,
    required this.message,
    required this.isMe,
    this.onReply,
    this.onPreview,
    this.heroTagFor,
  });
  final ChatMessage message;
  final bool isMe;
  final VoidCallback? onReply;
  final ValueChanged<int>? onPreview;
  final Object Function(int)? heroTagFor;
  @override
  Widget build(BuildContext context) {
    final doc = message.content is Map<String, dynamic>
        ? message.content as Map<String, dynamic>
        : DraftyCodec.decode(message.content);
    final parts = (int.tryParse('${message.head['reply']}') ?? 0) > 0
        ? DraftyCodec.splitReply(doc)
        : (quote: null, body: doc);
    final bodyDoc = parts.body;
    final entities = DraftyCodec.attachments(bodyDoc).toList();
    final attachments = [
      for (final entry in entities)
        AttachmentView(
          key: ValueKey((message.id, entry.entityIndex)),
          type: entry.entity['tp'] as String,
          data: entry.entity['data'] is Map
              ? Map<String, dynamic>.from(entry.entity['data'] as Map)
              : const {},
          onPreview: onPreview == null
              ? null
              : () => onPreview!(entry.entityIndex),
          heroTag: heroTagFor?.call(entry.entityIndex),
          pendingBytes: isMe && message.pending
              ? () => context.read<ChatsRepository>().pendingAttachmentBytes(
                  message,
                  entry.entityIndex,
                )
              : null,
        ),
    ];
    final hasText = DraftyCodec.plainText(bodyDoc).trim().isNotEmpty;
    final header = MessageHeader(
      message: message,
      quote: parts.quote,
      onReply: onReply,
    );
    final footer = MessageFooter(message: message, isMe: isMe);
    final body = hasText && attachments.isEmpty
        ? DraftyText(
            key: ValueKey(message.id),
            content: bodyDoc,
            header: header,
            footer: footer,
          )
        : MessageLayout(
            header: header,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasText)
                  DraftyText(key: ValueKey(message.id), content: bodyDoc),
                ...attachments,
              ],
            ),
            footer: footer,
          );
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        constraints: BoxConstraints(
          // The conversation pane, not the whole desktop viewport, owns width.
          maxWidth:
              ((constraints.hasBoundedWidth
                          ? constraints.maxWidth
                          : MediaQuery.sizeOf(context).width) *
                      .85)
                  .clamp(0, 512),
        ),
        padding: attachments.isNotEmpty && !hasText
            ? const EdgeInsets.all(6)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? context.colors.surfaceContainer
              : context.colors.surfaceContainerLow,
          border: Border.all(
            color: isMe
                ? context.colors.outline.withValues(alpha: .55)
                : context.colors.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(context.collapseTheme.radius),
        ),
        child: body,
      ),
    );
  }
}
