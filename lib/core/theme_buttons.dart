part of 'theme.dart';

WidgetStateProperty<Color?> _overlay(
  Color color, {
  Color? selectedColor,
}) => WidgetStateProperty.resolveWith((states) {
  if (states.contains(WidgetState.disabled)) return Colors.transparent;
  final ink = states.contains(WidgetState.selected)
      ? selectedColor ?? color
      : color;
  if (states.contains(WidgetState.pressed)) return ink.withValues(alpha: .14);
  if (states.contains(WidgetState.focused)) return ink.withValues(alpha: .12);
  if (states.contains(WidgetState.hovered)) return ink.withValues(alpha: .08);
  return Colors.transparent;
});

ButtonStyle _terminalButton(
  ThemeData theme, {
  bool filled = false,
  bool outlined = false,
}) {
  final c = theme.colorScheme;
  return ButtonStyle(
    animationDuration: const Duration(milliseconds: 140),
    minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    ),
    tapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    elevation: const WidgetStatePropertyAll(0),
    textStyle: WidgetStatePropertyAll(theme.textTheme.labelLarge),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: _terminalRadius),
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? c.onSurface.withValues(alpha: .38)
          : filled
          ? c.onInverseSurface
          : c.onSurface,
    ),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? filled
                ? c.onSurface.withValues(alpha: .12)
                : Colors.transparent
          : filled
          ? c.inverseSurface
          : Colors.transparent,
    ),
    overlayColor: _overlay(filled ? c.onInverseSurface : c.onSurface),
    side: WidgetStateProperty.resolveWith(
      (states) => BorderSide(
        color: states.contains(WidgetState.disabled)
            ? outlined
                  ? c.outlineVariant
                  : Colors.transparent
            : states.contains(WidgetState.focused) ||
                  states.contains(WidgetState.hovered)
            ? filled
                  ? c.onInverseSurface
                  : c.primary
            : filled || outlined
            ? c.outline
            : Colors.transparent,
        width: states.contains(WidgetState.focused) ? 2 : 1,
      ),
    ),
  );
}
