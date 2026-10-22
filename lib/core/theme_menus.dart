part of 'theme.dart';

ThemeData _terminalMenus(ThemeData theme) {
  final c = theme.colorScheme, t = theme.textTheme;
  final frame = RoundedRectangleBorder(
    borderRadius: _terminalRadius,
    side: BorderSide(color: c.outlineVariant),
  );
  final menu = MenuStyle(
    elevation: const WidgetStatePropertyAll(0),
    backgroundColor: WidgetStatePropertyAll(c.surfaceContainerLow),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    shape: WidgetStatePropertyAll(frame),
  );
  return theme.copyWith(
    menuTheme: MenuThemeData(style: menu),
    menuBarTheme: MenuBarThemeData(style: menu),
    menuButtonTheme: MenuButtonThemeData(
      style: _terminalButton(theme).copyWith(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? c.onSurface.withValues(alpha: .38)
              : c.onSurface,
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: frame,
      textStyle: t.bodyMedium,
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: t.bodyMedium,
      menuStyle: menu,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.inverseSurface,
        borderRadius: _terminalRadius,
      ),
      textStyle: t.labelMedium!.copyWith(color: c.onInverseSurface),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.inverseSurface,
      contentTextStyle: t.bodyMedium!.copyWith(color: c.onInverseSurface),
      actionTextColor: c.inversePrimary,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: _terminalRadius),
    ),
  );
}
