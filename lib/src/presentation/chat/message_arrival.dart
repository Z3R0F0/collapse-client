import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

/// Paint-only entry motion. Delivery and history never depend on this widget.
class MessageArrival extends StatefulWidget {
  const MessageArrival({
    super.key,
    required this.child,
    required this.isMe,
    required this.enteredAt,
    required this.onSettled,
  });

  static const duration = Duration(milliseconds: 180);
  final Widget child;
  final bool isMe;
  final DateTime? enteredAt;
  final VoidCallback onSettled;

  @override
  State<MessageArrival> createState() => _MessageArrivalState();
}

class _MessageArrivalState extends State<MessageArrival>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: MessageArrival.duration,
  )..addStatusListener(_statusChanged);
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  bool _reported = false;
  DateTime? _entry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MessageArrival oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enteredAt != widget.enteredAt) {
      _reported = false;
      _sync();
    }
  }

  void _sync() {
    final enteredAt = widget.enteredAt;
    final disabled =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    var progress = enteredAt == null || disabled
        ? 1.0
        : (clock.now().difference(enteredAt).inMicroseconds /
                  MessageArrival.duration.inMicroseconds)
              .clamp(0.0, 1.0)
              .toDouble();
    if (_entry == enteredAt && progress < _controller.value) {
      progress = _controller.value;
    }
    _entry = enteredAt;
    _controller.value = progress;
    if (progress < 1) _controller.forward();
  }

  void _statusChanged(AnimationStatus status) {
    final enteredAt = widget.enteredAt;
    if (status != AnimationStatus.completed || enteredAt == null || _reported) {
      return;
    }
    _reported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enteredAt == enteredAt) widget.onSettled();
    });
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (_, child) => Transform.translate(
        offset: Offset(
          (widget.isMe ? 8 : -8) * (1 - _curve.value),
          4 * (1 - _curve.value),
        ),
        child: child,
      ),
    ),
  );

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }
}
