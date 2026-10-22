part of 'workspace_layout.dart';

class _WorkspaceDivider extends StatefulWidget {
  const _WorkspaceDivider({
    required this.label,
    required this.width,
    required this.maximum,
    required this.onChanged,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final String label;
  final double width, maximum;
  final ValueChanged<double> onChanged, onDragUpdate;
  final VoidCallback onDragStart, onDragEnd;

  @override
  State<_WorkspaceDivider> createState() => _WorkspaceDividerState();
}

class _WorkspaceDividerState extends State<_WorkspaceDivider> {
  bool _focused = false, _hovered = false;

  double _stepValue(bool increase) {
    final current = widget.width;
    return increase
        ? current < WorkspaceLayout.minimumSidebarWidth
              ? WorkspaceLayout.minimumSidebarWidth
              : min(widget.maximum, current + 24)
        : current <= WorkspaceLayout.minimumSidebarWidth
        ? WorkspaceLayout.compactWidth
        : max(WorkspaceLayout.minimumSidebarWidth, current - 24);
  }

  void _step(bool increase) => widget.onChanged(_stepValue(increase));

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _step(false);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _step(true);
    } else if (key == LogicalKeyboardKey.home) {
      widget.onChanged(WorkspaceLayout.compactWidth);
    } else if (key == LogicalKeyboardKey.end) {
      widget.onChanged(widget.maximum);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: widget.label,
      value: '${widget.width.round()}',
      increasedValue: '${_stepValue(true).round()}',
      decreasedValue: '${_stepValue(false).round()}',
      slider: true,
      onIncrease: widget.width < widget.maximum ? () => _step(true) : null,
      onDecrease: widget.width > WorkspaceLayout.compactWidth
          ? () => _step(false)
          : null,
      child: Focus(
        onFocusChange: (value) => setState(() => _focused = value),
        onKeyEvent: _key,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Tooltip(
            message: widget.label,
            excludeFromSemantics: true,
            child: GestureDetector(
              key: const ValueKey('workspace-divider'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) => widget.onDragStart(),
              onHorizontalDragUpdate: (event) =>
                  widget.onDragUpdate(event.delta.dx),
              onHorizontalDragEnd: (_) => widget.onDragEnd(),
              onHorizontalDragCancel: widget.onDragEnd,
              child: Center(
                child: ColoredBox(
                  color: _focused || _hovered
                      ? colors.primary
                      : colors.outlineVariant,
                  child: SizedBox(
                    width: _focused ? 2 : 1,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
