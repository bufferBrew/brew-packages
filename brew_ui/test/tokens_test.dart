import 'package:brew_ui/brew_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('BrewColors', () {
    test('fromSeed fills every role for both brightnesses', () {
      final light = BrewColors.fromSeed(const Color(0xFF7C4DFF));
      final dark = BrewColors.fromSeed(
        const Color(0xFF7C4DFF),
        brightness: Brightness.dark,
      );
      expect(light.isDark, isFalse);
      expect(dark.isDark, isTrue);
      expect(
        light.background.computeLuminance(),
        greaterThan(dark.background.computeLuminance()),
      );
    });

    test('toColorScheme maps the roles Material widgets read', () {
      final c = BrewColors.fromSeed(const Color(0xFF00897B));
      final s = c.toColorScheme();
      expect(s.primary, c.accent);
      expect(s.onPrimary, c.onAccent);
      expect(s.surface, c.background);
      expect(s.surfaceContainerLow, c.surface);
      expect(s.error, c.danger);
      expect(s.outlineVariant, c.divider);
    });

    test('lerp interpolates and copyWith overrides', () {
      final a = BrewColors.fromSeed(const Color(0xFF000000));
      final b = a.copyWith(accent: const Color(0xFFFFFFFF));
      expect(b.accent, const Color(0xFFFFFFFF));
      expect(b.text, a.text);
      expect(a.lerp(b, 0).accent, a.accent);
      expect(a.lerp(b, 1).accent, b.accent);
    });

    test('tone helpers cover every tone', () {
      final c = BrewColors.fromSeed(const Color(0xFF1E88E5));
      for (final tone in BrewTone.values) {
        expect(c.toneColor(tone), isNotNull);
        expect(c.toneText(tone), isNotNull);
        expect(c.toneBackground(tone), isNotNull);
      }
      expect(c.toneText(BrewTone.danger), c.dangerText);
    });
  });

  group('buildBrewTheme', () {
    test('installs the token extensions and component themes', () {
      final colors = BrewColors.fromSeed(const Color(0xFF7C4DFF));
      final theme = buildBrewTheme(
        colors: colors,
        shape: const BrewShape(control: 4, card: 8),
      );
      expect(theme.useMaterial3, isTrue);
      expect(theme.extension<BrewColors>(), colors);
      expect(theme.extension<BrewTypography>(), isNotNull);
      expect(theme.extension<BrewShape>()?.card, 8);
      expect(theme.scaffoldBackgroundColor, colors.background);
      expect(theme.colorScheme.primary, colors.accent);
    });

    test('keeps app-specific extensions alongside', () {
      final theme = buildBrewTheme(
        colors: BrewColors.fromSeed(const Color(0xFF7C4DFF)),
        extensions: const [_AppExtra(42)],
      );
      expect(theme.extension<_AppExtra>()?.value, 42);
    });
  });

  testWidgets('context tokens fall back to the ambient Material theme', (
    tester,
  ) async {
    late BrewColors colors;
    late BrewShape shape;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorSchemeSeed: Colors.teal),
        home: Builder(
          builder: (context) {
            colors = context.brewColors;
            shape = context.brewShape;
            context.brewType;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      colors.accent,
      ThemeData(colorSchemeSeed: Colors.teal).colorScheme.primary,
    );
    expect(shape.card, const BrewShape().card);
  });

  group('ThemeModeStore', () {
    test('round-trips and defaults to system', () async {
      SharedPreferences.setMockInitialValues({});
      const store = ThemeModeStore();
      expect(await store.load(), ThemeMode.system);
      await store.save(ThemeMode.dark);
      expect(await store.load(), ThemeMode.dark);
    });

    test('an unknown stored value reads as system', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'sepia'});
      expect(await const ThemeModeStore().load(), ThemeMode.system);
    });
  });
}

class _AppExtra extends ThemeExtension<_AppExtra> {
  const _AppExtra(this.value);
  final int value;
  @override
  _AppExtra copyWith() => this;
  @override
  _AppExtra lerp(_AppExtra? other, double t) => this;
}
