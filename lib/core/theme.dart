import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

part 'theme_tokens.dart';
part 'theme_buttons.dart';
part 'theme_controls.dart';
part 'theme_menus.dart';
part 'theme_surfaces.dart';

/// Small extension: shared surfaces and spacing, not a second theme system.
class CollapseTheme extends ThemeExtension<CollapseTheme> {
  const CollapseTheme({this.radius = 6, this.gap = 12});
  final double radius;
  final double gap;
  @override
  CollapseTheme copyWith({double? radius, double? gap}) =>
      CollapseTheme(radius: radius ?? this.radius, gap: gap ?? this.gap);
  @override
  CollapseTheme lerp(CollapseTheme? other, double t) => other == null
      ? this
      : CollapseTheme(
          radius: radius + (other.radius - radius) * t,
          gap: gap + (other.gap - gap) * t,
        );
}

ThemeData appTheme(Brightness brightness) {
  final scheme = _terminalColors(brightness);
  final base = ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    useMaterial3: true,
    // Desktop density must not make touch targets smaller than mobile targets.
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: NoSplash.splashFactory,
    hoverColor: scheme.onSurface.withValues(alpha: .06),
    focusColor: scheme.primary.withValues(alpha: .12),
    highlightColor: scheme.primary.withValues(alpha: .10),
    extensions: const [CollapseTheme()],
  );
  final typed = base.copyWith(textTheme: _terminalType(base.textTheme));
  return _terminalSurfaces(_terminalMenus(_terminalControls(typed)));
}

extension CollapseContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  CollapseTheme get collapseTheme => Theme.of(this).extension<CollapseTheme>()!;
  TextTheme get textStyles => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
}
