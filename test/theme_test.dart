import 'package:collapse/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance(), second = b.computeLuminance();
  return first > second
      ? (first + .05) / (second + .05)
      : (second + .05) / (first + .05);
}

void main() {
  test('existing extension retains copy and interpolation contracts', () {
    const base = CollapseTheme();
    expect(base.radius, 6);
    expect(base.gap, 12);
    final changed = base.copyWith(radius: 4, gap: 16);
    expect(base.lerp(changed, .5).radius, 5);
    expect(base.lerp(changed, .5).gap, 14);
  });

  for (final brightness in Brightness.values) {
    group(brightness.name, () {
      final theme = appTheme(brightness);
      final c = theme.colorScheme;

      test('normal text and active accent pairs retain readable contrast', () {
        for (final surface in [
          c.surface,
          c.surfaceContainerLowest,
          c.surfaceContainerLow,
          c.surfaceContainer,
          c.surfaceContainerHigh,
          c.surfaceContainerHighest,
        ]) {
          expect(contrast(c.onSurface, surface), greaterThanOrEqualTo(4.5));
          expect(
            contrast(c.onSurfaceVariant, surface),
            greaterThanOrEqualTo(4.5),
          );
          expect(contrast(c.primary, surface), greaterThanOrEqualTo(4.5));
        }
        for (final pair in [
          (c.onPrimary, c.primary),
          (c.onPrimaryFixed, c.primaryFixed),
          (c.onPrimaryContainer, c.primaryContainer),
          (c.onError, c.error),
          (c.onErrorContainer, c.errorContainer),
          (c.onInverseSurface, c.inverseSurface),
          (c.inversePrimary, c.inverseSurface),
        ]) {
          expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
        }
        expect(
          contrast(c.outline, c.surfaceContainerLowest),
          greaterThanOrEqualTo(3),
        );
        expect(c.primary, c.secondary);
        expect(c.primary, c.tertiary);
        expect(c.surfaceTint, Colors.transparent);
      });

      test('accent is reserved for state, not large filled controls', () {
        expect(
          theme.filledButtonTheme.style!.backgroundColor!.resolve({}),
          c.inverseSurface,
        );
        expect(theme.navigationBarTheme.indicatorColor, Colors.transparent);
        expect(
          (theme.navigationBarTheme.indicatorShape as Border).bottom.width,
          2,
        );
      });

      test('body remains sans 16; headings and metadata use bundled mono', () {
        for (final body in [
          theme.textTheme.bodyLarge!,
          theme.textTheme.bodyMedium!,
        ]) {
          expect(body.fontSize, 16);
          expect(body.fontFamily, isNot('IBMPlexMono'));
        }
        for (final label in [
          theme.textTheme.titleLarge!,
          theme.textTheme.titleMedium!,
          theme.textTheme.headlineSmall!,
          theme.textTheme.labelLarge!,
          theme.textTheme.labelMedium!,
          theme.textTheme.labelSmall!,
        ]) {
          expect(label.fontFamily, 'IBMPlexMono');
          expect(label.fontSize, greaterThanOrEqualTo(12));
        }
      });

      test(
        'button states preserve targets, visible focus and disabled affordance',
        () {
          for (final style in [
            theme.filledButtonTheme.style!,
            theme.elevatedButtonTheme.style!,
            theme.outlinedButtonTheme.style!,
            theme.textButtonTheme.style!,
            theme.iconButtonTheme.style!,
            theme.segmentedButtonTheme.style!,
            theme.menuButtonTheme.style!,
          ]) {
            final size = style.minimumSize!.resolve({})!;
            expect(size.width, greaterThanOrEqualTo(48));
            expect(size.height, greaterThanOrEqualTo(48));
            expect(style.side!.resolve({WidgetState.focused})!.width, 2);
            expect(
              style.foregroundColor!.resolve({WidgetState.disabled}),
              isNot(style.foregroundColor!.resolve({})),
            );
            expect(
              style.overlayColor!.resolve({WidgetState.hovered})!.a,
              greaterThan(0),
            );
            expect(
              style.overlayColor!.resolve({WidgetState.pressed})!.a,
              greaterThan(
                style.overlayColor!.resolve({WidgetState.hovered})!.a,
              ),
            );
            expect(
              style.overlayColor!.resolve({WidgetState.disabled}),
              Colors.transparent,
            );
          }
          final filled = theme.filledButtonTheme.style!;
          for (final states in [
            <WidgetState>{},
            {WidgetState.hovered},
            {WidgetState.focused},
            {WidgetState.pressed},
          ]) {
            final background = Color.alphaBlend(
              filled.overlayColor!.resolve(states)!,
              filled.backgroundColor!.resolve(states)!,
            );
            expect(
              contrast(filled.foregroundColor!.resolve(states)!, background),
              greaterThanOrEqualTo(4.5),
            );
          }
          expect(theme.visualDensity, VisualDensity.standard);
          expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
        },
      );

      test(
        'fields use one-pixel outlines and two-pixel focus/error borders',
        () {
          final input = theme.inputDecorationTheme;
          expect(input.constraints!.minHeight, 48);
          expect(input.enabledBorder!.borderSide.width, 1);
          expect(input.focusedBorder!.borderSide.width, 2);
          expect(input.focusedErrorBorder!.borderSide.width, 2);
          expect(input.focusedBorder!.borderSide.color, c.primary);
          expect(input.focusedErrorBorder!.borderSide.color, c.error);
          expect(
            (input.focusedBorder as OutlineInputBorder).borderRadius,
            BorderRadius.circular(6),
          );
        },
      );

      testWidgets('common controls keep 48dp targets with enlarged text', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    FilledButton(
                      onPressed: () {},
                      child: const Text('Connect'),
                    ),
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text('Cancel'),
                    ),
                    TextButton(onPressed: () {}, child: const Text('Profile')),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.search),
                        tooltip: 'Search',
                      ),
                    ),
                    const TextField(
                      decoration: InputDecoration(labelText: 'Message'),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Checkbox(value: true, onChanged: (_) {}),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Switch(value: true, onChanged: (_) {}),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final type in [
          FilledButton,
          OutlinedButton,
          TextButton,
          IconButton,
          TextField,
          Checkbox,
          Switch,
        ]) {
          final size = tester.getSize(find.byType(type));
          expect(size.height, greaterThanOrEqualTo(48), reason: '$type height');
          expect(size.width, greaterThanOrEqualTo(48), reason: '$type width');
        }
        expect(tester.takeException(), isNull);
      });
    });
  }
}
