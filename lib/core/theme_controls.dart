part of 'theme.dart';

ThemeData _terminalControls(ThemeData theme) {
  final c = theme.colorScheme, t = theme.textTheme;
  final filled = _terminalButton(theme, filled: true);
  final outline = _terminalButton(theme, outlined: true);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: _terminalRadius,
        borderSide: BorderSide(color: color, width: width),
      );
  return theme.copyWith(
    filledButtonTheme: FilledButtonThemeData(style: filled),
    elevatedButtonTheme: ElevatedButtonThemeData(style: filled),
    outlinedButtonTheme: OutlinedButtonThemeData(style: outline),
    textButtonTheme: TextButtonThemeData(style: _terminalButton(theme)),
    iconButtonTheme: IconButtonThemeData(
      style: _terminalButton(theme).copyWith(
        padding: const WidgetStatePropertyAll(EdgeInsets.all(12)),
        backgroundColor: const WidgetStatePropertyAll(null),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? c.onSurface.withValues(alpha: .38)
              : states.contains(WidgetState.selected)
              ? c.primary
              : c.onSurface,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: outline.copyWith(
        overlayColor: _overlay(c.onSurface),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? c.onSurface.withValues(alpha: .38)
              : states.contains(WidgetState.selected)
              ? c.primary
              : c.onSurface,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) &&
                  !states.contains(WidgetState.disabled)
              ? c.surfaceContainer
              : Colors.transparent,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: c.surfaceContainerLowest,
      hoverColor: c.onSurface.withValues(alpha: .04),
      focusColor: c.primary.withValues(alpha: .04),
      constraints: const BoxConstraints(minHeight: 48),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: t.labelLarge!.copyWith(color: c.onSurfaceVariant),
      floatingLabelStyle: t.labelMedium!.copyWith(color: c.primary),
      hintStyle: t.bodyMedium!.copyWith(color: c.onSurfaceVariant),
      helperStyle: t.labelSmall!.copyWith(color: c.onSurfaceVariant),
      errorStyle: t.labelSmall!.copyWith(color: c.error),
      border: border(c.outline),
      enabledBorder: border(c.outline),
      disabledBorder: border(c.outlineVariant),
      focusedBorder: border(c.primary, 2),
      errorBorder: border(c.error),
      focusedErrorBorder: border(c.error, 2),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.primary,
      selectionColor: c.primary.withValues(alpha: .25),
      selectionHandleColor: c.primary,
    ),
    checkboxTheme: CheckboxThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      overlayColor: _overlay(c.primary),
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.disabled)
              ? c.outlineVariant
              : c.outline,
          width: states.contains(WidgetState.focused) ? 2 : 1,
        ),
      ),
    ),
    radioTheme: RadioThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      overlayColor: _overlay(c.primary),
    ),
    switchTheme: SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      overlayColor: _overlay(c.primary),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? c.outlineVariant
            : states.contains(WidgetState.selected)
            ? c.onPrimaryFixed
            : c.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) &&
                !states.contains(WidgetState.disabled)
            ? c.primaryFixed
            : c.surfaceContainerHighest,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.focused) ? c.primary : c.outline,
      ),
      trackOutlineWidth: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused) ? 2 : 1,
      ),
    ),
  );
}
