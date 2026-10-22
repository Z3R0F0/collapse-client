import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../domain/chat/chat_models.dart';

/// Delivery changes fade in a fixed box; they never replay bubble arrival motion.
class MessageStatus extends StatelessWidget {
  const MessageStatus({super.key, required this.delivery});
  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final quiet =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    final icon = Icon(
      key: ValueKey(delivery),
      switch (delivery) {
        Delivery.queued => Icons.schedule,
        Delivery.sending => Icons.more_horiz,
        Delivery.failed => Icons.error_outline,
        Delivery.sent => Icons.done,
        _ => Icons.done_all,
      },
      size: 14,
      color: switch (delivery) {
        Delivery.read => context.colors.primary,
        Delivery.failed => context.colors.error,
        _ => context.colors.onSurfaceVariant,
      },
    );
    return Tooltip(
      message: switch (delivery) {
        Delivery.queued => context.l10n.queued,
        Delivery.sending => context.l10n.sending,
        Delivery.sent => context.l10n.sent,
        Delivery.received => context.l10n.received,
        Delivery.read => context.l10n.read,
        Delivery.failed => context.l10n.failed,
      },
      child: SizedBox.square(
        dimension: 20,
        // Dispose an interrupted fade instead of resuming old motion on return.
        child: quiet
            ? icon
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                child: icon,
              ),
      ),
    );
  }
}
