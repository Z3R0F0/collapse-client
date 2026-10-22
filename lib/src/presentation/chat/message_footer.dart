import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../domain/chat/chat_models.dart';
import 'message_status.dart';

class MessageFooter extends StatelessWidget {
  const MessageFooter({super.key, required this.message, required this.isMe});
  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        TimeOfDay.fromDateTime(message.createdAt.toLocal()).format(context),
        style: context.textStyles.labelSmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
      if (isMe) MessageStatus(delivery: message.delivery),
    ],
  );
}
