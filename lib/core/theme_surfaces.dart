part of 'theme.dart';

ThemeData _terminalSurfaces(ThemeData theme) {
  final c = theme.colorScheme, t = theme.textTheme;
  final frame = RoundedRectangleBorder(
    borderRadius: _terminalRadius,
    side: BorderSide(color: c.outlineVariant),
  );
  return theme.copyWith(
    appBarTheme: AppBarThemeData(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: c.surface,
      foregroundColor: c.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: t.titleLarge,
      titleSpacing: 20,
      toolbarTextStyle: t.labelLarge,
      shape: Border(bottom: BorderSide(color: c.outlineVariant)),
    ),
    dividerTheme: DividerThemeData(
      color: c.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    cardTheme: CardThemeData(
      color: c.surfaceContainerLow,
      elevation: 0,
      shape: frame,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: frame,
      titleTextStyle: t.titleLarge,
      contentTextStyle: t.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      shape: frame,
      dragHandleColor: c.outline,
    ),
    listTileTheme: ListTileThemeData(
      minTileHeight: 56,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      titleTextStyle: t.bodyLarge,
      subtitleTextStyle: t.bodySmall!.copyWith(color: c.onSurfaceVariant),
      leadingAndTrailingTextStyle: t.labelSmall,
      textColor: c.onSurface,
      iconColor: c.onSurfaceVariant,
      selectedColor: c.primary,
      selectedTileColor: c.surfaceContainer,
      shape: const RoundedRectangleBorder(borderRadius: _terminalRadius),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      indicatorShape: Border(bottom: BorderSide(color: c.primary, width: 2)),
      overlayColor: _overlay(c.onSurface),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => t.labelMedium!.copyWith(
          color: states.contains(WidgetState.disabled)
              ? c.onSurface.withValues(alpha: .38)
              : states.contains(WidgetState.selected)
              ? c.primary
              : c.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.disabled)
              ? c.onSurface.withValues(alpha: .38)
              : states.contains(WidgetState.selected)
              ? c.primary
              : c.onSurfaceVariant,
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle: t.labelLarge,
      unselectedLabelStyle: t.labelLarge,
      labelColor: c.primary,
      unselectedLabelColor: c.onSurfaceVariant,
      indicatorColor: c.primary,
      dividerColor: c.outlineVariant,
      overlayColor: _overlay(c.primary),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surfaceContainerLow,
      selectedColor: c.primaryContainer,
      disabledColor: c.surfaceContainerHighest,
      labelStyle: t.labelMedium!.copyWith(color: c.onSurface),
      secondaryLabelStyle: t.labelMedium!.copyWith(color: c.onPrimaryContainer),
      secondarySelectedColor: c.primaryContainer,
      side: BorderSide(color: c.outline),
      shape: const RoundedRectangleBorder(borderRadius: _terminalRadius),
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: c.primaryFixed,
      textColor: c.onPrimaryFixed,
      textStyle: t.labelSmall,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.inverseSurface,
      foregroundColor: c.onInverseSurface,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: frame,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.primary,
      linearTrackColor: c.surfaceContainerHighest,
      circularTrackColor: c.surfaceContainerHighest,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.dragged) ? c.primary : c.outline,
      ),
    ),
  );
}
