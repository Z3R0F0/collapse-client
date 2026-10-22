import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../widgets/view_activity.dart';

part 'workspace_divider.dart';

/// Changes pane constraints, never reparents the retained detail Navigator.
class WorkspaceLayout extends StatefulWidget {
  const WorkspaceLayout({
    super.key,
    required this.masterBuilder,
    required this.detail,
    required this.hasDetail,
    required this.sidebarWidth,
    required this.onSidebarWidthChanged,
    required this.resizeLabel,
  });

  final Widget Function(BuildContext context, bool compact) masterBuilder;
  final Widget detail;
  final bool hasDetail;

  /// A preference owned by the shell. Mobile layout never overwrites it.
  final double sidebarWidth;
  final ValueChanged<double> onSidebarWidthChanged;
  final String resizeLabel;

  static const breakpoint = 840.0;
  static const compactWidth = 72.0;
  static const minimumSidebarWidth = 240.0;
  static const maximumSidebarWidth = 420.0;
  static const minimumDetailWidth = 400.0;

  @override
  State<WorkspaceLayout> createState() => _WorkspaceLayoutState();
}

class _WorkspaceLayoutState extends State<WorkspaceLayout> {
  double? _dragWidth;

  double _bounded(double value, double maximum) =>
      value.clamp(WorkspaceLayout.compactWidth, maximum);

  double _snapped(double value, double maximum) => value < 200
      ? WorkspaceLayout.compactWidth
      : value.clamp(WorkspaceLayout.minimumSidebarWidth, maximum);

  void _resize(double width, double maximum) =>
      widget.onSidebarWidthChanged(_bounded(width, maximum));

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = MediaQuery.sizeOf(context);
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : size.width;
      final height = constraints.maxHeight.isFinite
          ? constraints.maxHeight
          : size.height;
      final wide = width >= WorkspaceLayout.breakpoint;
      final maximum = max(
        WorkspaceLayout.minimumSidebarWidth,
        min(
          WorkspaceLayout.maximumSidebarWidth,
          width - WorkspaceLayout.minimumDetailWidth,
        ),
      );
      final sidebar = _bounded(widget.sidebarWidth, maximum);
      final masterVisible = wide || !widget.hasDetail;
      final detailVisible = wide || widget.hasDetail;
      return SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              key: const ValueKey('workspace-master'),
              left: 0,
              top: 0,
              bottom: 0,
              width: wide ? sidebar : width,
              child: Offstage(
                offstage: !masterVisible,
                child: ViewActivity(
                  active: masterVisible,
                  child: Builder(
                    builder: (context) =>
                        widget.masterBuilder(context, wide && sidebar < 200),
                  ),
                ),
              ),
            ),
            Positioned(
              key: const ValueKey('workspace-detail'),
              left: wide ? sidebar : 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Offstage(
                offstage: !detailVisible,
                child: ViewActivity(
                  active: detailVisible,
                  // A nested Navigator's modal semantics must not suppress
                  // the independently visible master pane.
                  child: Semantics(
                    container: true,
                    explicitChildNodes: true,
                    child: widget.detail,
                  ),
                ),
              ),
            ),
            if (wide)
              Positioned(
                // Keep both pointer and web-semantic hit bounds on the edge;
                // a 48px overlay steals adjacent pane/header button clicks.
                left: sidebar - 4,
                top: 0,
                bottom: 0,
                width: 8,
                child: _WorkspaceDivider(
                  label: widget.resizeLabel,
                  width: sidebar,
                  maximum: maximum,
                  onChanged: (value) => _resize(value, maximum),
                  onDragStart: () => _dragWidth = sidebar,
                  onDragUpdate: (delta) {
                    _dragWidth = _bounded(
                      (_dragWidth ?? sidebar) + delta,
                      maximum,
                    );
                    _resize(_dragWidth!, maximum);
                  },
                  onDragEnd: () {
                    _resize(_snapped(_dragWidth ?? sidebar, maximum), maximum);
                    _dragWidth = null;
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}
