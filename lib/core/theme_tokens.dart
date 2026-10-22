part of 'theme.dart';

const _terminalRadius = BorderRadius.all(Radius.circular(6));
const _mono = 'IBMPlexMono';

ColorScheme _terminalColors(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  const signal = Color(0xffd9be7c), ink = Color(0xff211b0c);
  final accent = dark ? signal : const Color(0xff6a5219);
  final onAccent = dark ? ink : Colors.white;
  final container = dark ? const Color(0xff29251b) : const Color(0xffeee4c9);
  final onContainer = dark ? const Color(0xffe8d9b5) : ink;
  return ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: onAccent,
    primaryContainer: container,
    onPrimaryContainer: onContainer,
    primaryFixed: signal,
    primaryFixedDim: const Color(0xffbca36a),
    onPrimaryFixed: ink,
    onPrimaryFixedVariant: const Color(0xff4c3b14),
    secondary: accent,
    onSecondary: onAccent,
    secondaryContainer: container,
    onSecondaryContainer: onContainer,
    secondaryFixed: signal,
    secondaryFixedDim: const Color(0xffbca36a),
    onSecondaryFixed: ink,
    onSecondaryFixedVariant: const Color(0xff4c3b14),
    tertiary: accent,
    onTertiary: onAccent,
    tertiaryContainer: container,
    onTertiaryContainer: onContainer,
    tertiaryFixed: signal,
    tertiaryFixedDim: const Color(0xffbca36a),
    onTertiaryFixed: ink,
    onTertiaryFixedVariant: const Color(0xff4c3b14),
    error: dark ? const Color(0xffffb4ab) : const Color(0xffa3221b),
    onError: dark ? const Color(0xff590900) : Colors.white,
    errorContainer: dark ? const Color(0xff742019) : const Color(0xffffdad5),
    onErrorContainer: dark ? const Color(0xffffdad5) : const Color(0xff410500),
    surface: dark ? const Color(0xff0b0d0f) : const Color(0xfff3f3f0),
    onSurface: dark ? const Color(0xffe7e9e6) : const Color(0xff1c2024),
    onSurfaceVariant: dark ? const Color(0xffa8afb5) : const Color(0xff505961),
    surfaceDim: dark ? const Color(0xff0b0d0f) : const Color(0xffd9dde0),
    surfaceBright: dark ? const Color(0xff30363c) : const Color(0xfff3f3f0),
    surfaceContainerLowest: dark ? const Color(0xff080a0c) : Colors.white,
    surfaceContainerLow: dark
        ? const Color(0xff121518)
        : const Color(0xffedeeec),
    surfaceContainer: dark ? const Color(0xff1a1e22) : const Color(0xffe6e8e7),
    surfaceContainerHigh: dark
        ? const Color(0xff23282d)
        : const Color(0xffe0e3e3),
    surfaceContainerHighest: dark
        ? const Color(0xff2d3339)
        : const Color(0xffd9dede),
    outline: dark ? const Color(0xff78818b) : const Color(0xff717980),
    outlineVariant: dark ? const Color(0xff30363c) : const Color(0xffbfc6ca),
    inverseSurface: dark ? const Color(0xffe7e9e6) : const Color(0xff1c2024),
    onInverseSurface: dark ? const Color(0xff1c2024) : const Color(0xffe7e9e6),
    inversePrimary: dark ? const Color(0xff6a5219) : signal,
    surfaceTint: Colors.transparent,
    shadow: Colors.black,
    scrim: Colors.black,
  );
}

TextTheme _terminalType(TextTheme base) {
  TextStyle mono(TextStyle? style, double size) => style!.copyWith(
    fontFamily: _mono,
    fontSize: size,
    fontWeight: FontWeight.w500,
    letterSpacing: -.3,
    height: 1.3,
  );
  return base.copyWith(
    displayLarge: mono(base.displayLarge, 48),
    displayMedium: mono(base.displayMedium, 40),
    displaySmall: mono(base.displaySmall, 36),
    headlineLarge: mono(base.headlineLarge, 28),
    headlineMedium: mono(base.headlineMedium, 24),
    headlineSmall: mono(base.headlineSmall, 22),
    titleLarge: mono(base.titleLarge, 20),
    titleMedium: mono(base.titleMedium, 16),
    titleSmall: mono(base.titleSmall, 14),
    labelLarge: mono(base.labelLarge, 14).copyWith(letterSpacing: .2),
    labelMedium: mono(base.labelMedium, 12).copyWith(letterSpacing: .4),
    labelSmall: mono(
      base.labelSmall,
      12,
    ).copyWith(fontWeight: FontWeight.w400, letterSpacing: .2),
    bodyLarge: base.bodyLarge!.copyWith(
      fontSize: 16,
      height: 1.45,
      letterSpacing: 0,
    ),
    bodyMedium: base.bodyMedium!.copyWith(
      fontSize: 16,
      height: 1.45,
      letterSpacing: 0,
    ),
    bodySmall: base.bodySmall!.copyWith(
      fontSize: 14,
      height: 1.4,
      letterSpacing: 0,
    ),
  );
}
