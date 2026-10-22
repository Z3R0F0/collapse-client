import 'package:flutter/widgets.dart';

/// A retained pane is active only when it and all containing panes are active.
/// Media/receipts combine this with route and application lifecycle visibility.
class ViewActivity extends StatelessWidget {
  const ViewActivity({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  static bool isActiveOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ActivityScope>()?.active ??
      true;

  @override
  Widget build(BuildContext context) {
    final effective = active && isActiveOf(context);
    return _ActivityScope(
      active: effective,
      child: TickerMode(
        enabled: effective,
        child: ExcludeFocus(
          excluding: !effective,
          child: ExcludeSemantics(excluding: !effective, child: child),
        ),
      ),
    );
  }
}

class _ActivityScope extends InheritedWidget {
  const _ActivityScope({required this.active, required super.child});

  final bool active;

  @override
  bool updateShouldNotify(_ActivityScope oldWidget) =>
      active != oldWidget.active;
}
