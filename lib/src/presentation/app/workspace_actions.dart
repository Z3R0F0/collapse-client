import 'package:flutter/widgets.dart';

class WorkspaceActions extends InheritedWidget {
  const WorkspaceActions({
    super.key,
    required this.signOut,
    required this.notifications,
    required super.child,
  });
  final VoidCallback signOut;
  final VoidCallback notifications;
  static WorkspaceActions of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkspaceActions>()!;
  @override
  bool updateShouldNotify(WorkspaceActions oldWidget) => false;
}
