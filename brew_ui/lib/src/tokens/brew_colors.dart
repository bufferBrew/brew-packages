import 'package:flutter/material.dart';

/// The colour roles every Brew screen is drawn with.
///
/// The role set is the one BrewVoyage (`TripColors`) and NeuroBrew
/// (`AppColors`) arrived at independently: surface tiers, an accent and a
/// secondary with subtle and on- variants, three text levels, and status
/// colours with a separate `…Text` shade that stays readable on light
/// surfaces. Apps either hand-tune a palette with the constructor or derive one
/// with [BrewColors.fromSeed].
///
/// App-specific roles (NeuroBrew's diagram colours, BrewVoyage's cover ink)
/// belong in the app's own ThemeExtension next to this one.
@immutable
class BrewColors extends ThemeExtension<BrewColors> {
  const BrewColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.accent,
    required this.accentStrong,
    required this.accentSubtle,
    required this.onAccent,
    required this.secondary,
    required this.secondarySubtle,
    required this.onSecondary,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.successText,
    required this.warning,
    required this.warningText,
    required this.danger,
    required this.dangerText,
    required this.onDanger,
    required this.info,
    required this.infoText,
    required this.divider,
    required this.focusRing,
    required this.scrim,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  /// Derives every role from one [seed] colour via Material 3's tonal
  /// palettes. Status hues are fixed, so "danger" reads as danger whatever the
  /// brand colour.
  factory BrewColors.fromSeed(
    Color seed, {
    Brightness brightness = Brightness.light,
    DynamicSchemeVariant variant = DynamicSchemeVariant.tonalSpot,
  }) => BrewColors.fromScheme(
    ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: variant,
    ),
  );

  /// Derives the roles from an existing [ColorScheme]. This is also the
  /// fallback when an app hasn't installed [BrewColors] yet, so brew_ui
  /// widgets render sensibly in an app mid-migration.
  factory BrewColors.fromScheme(ColorScheme s) {
    final dark = s.brightness == Brightness.dark;
    return BrewColors(
      brightness: s.brightness,
      background: s.surface,
      surface: s.surfaceContainerLow,
      surfaceElevated: s.surfaceContainerHigh,
      surfaceMuted: s.surfaceContainerHighest,
      accent: s.primary,
      accentStrong: dark ? s.primaryFixedDim : s.onPrimaryContainer,
      accentSubtle: s.primaryContainer,
      onAccent: s.onPrimary,
      secondary: s.tertiary,
      secondarySubtle: s.tertiaryContainer,
      onSecondary: s.onTertiary,
      text: s.onSurface,
      textSecondary: s.onSurfaceVariant,
      textTertiary: s.outline,
      success: dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
      successText: dark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
      warning: dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
      warningText: dark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
      danger: s.error,
      dangerText: dark ? s.error : s.onErrorContainer,
      onDanger: s.onError,
      info: dark ? const Color(0xFF6FB4FF) : const Color(0xFF2563EB),
      infoText: dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
      divider: s.outlineVariant,
      focusRing: s.primary,
      scrim: const Color(0x99000000),
      shimmerBase: s.surfaceContainerHighest,
      shimmerHighlight: s.surfaceContainerLow,
    );
  }

  final Brightness brightness;

  /// Behind everything: the scaffold.
  final Color background;

  /// Cards and sheets.
  final Color surface;

  /// Surfaces that sit above [surface]: menus, raised cards, inputs.
  final Color surfaceElevated;

  /// Recessed wells: tracks, skeletons, inactive chips.
  final Color surfaceMuted;

  /// Brand colour for fills: primary buttons, selected states.
  final Color accent;

  /// Accent for text and icons on [surface]; darker (light theme) or
  /// lighter (dark theme) than [accent] so it clears 4.5:1.
  final Color accentStrong;

  /// Tinted backgrounds: selected rows, icon wells.
  final Color accentSubtle;

  /// Text and icons on [accent].
  final Color onAccent;

  final Color secondary;
  final Color secondarySubtle;
  final Color onSecondary;

  final Color text;
  final Color textSecondary;

  /// Placeholders, disabled labels, metadata.
  final Color textTertiary;

  /// Status fills and icons.
  final Color success;

  /// Status as text on [surface] — readable where [success] may not be.
  final Color successText;
  final Color warning;
  final Color warningText;
  final Color danger;
  final Color dangerText;

  /// Text on a [danger] fill (a destructive button).
  final Color onDanger;
  final Color info;
  final Color infoText;

  final Color divider;
  final Color focusRing;

  /// Behind modals.
  final Color scrim;
  final Color shimmerBase;
  final Color shimmerHighlight;

  bool get isDark => brightness == Brightness.dark;

  /// The Material [ColorScheme] these roles imply, so stock Material widgets
  /// (dialogs, chips, switches) match brew_ui ones.
  ColorScheme toColorScheme() => ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: onAccent,
    primaryContainer: accentSubtle,
    onPrimaryContainer: accentStrong,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondarySubtle,
    onSecondaryContainer: text,
    tertiary: secondary,
    onTertiary: onSecondary,
    tertiaryContainer: secondarySubtle,
    onTertiaryContainer: text,
    error: danger,
    onError: onDanger,
    errorContainer: danger.withValues(alpha: 0.16),
    onErrorContainer: dangerText,
    surface: background,
    onSurface: text,
    onSurfaceVariant: textSecondary,
    surfaceContainerLowest: background,
    surfaceContainerLow: surface,
    surfaceContainer: surface,
    surfaceContainerHigh: surfaceElevated,
    surfaceContainerHighest: surfaceMuted,
    outline: textTertiary,
    outlineVariant: divider,
    shadow: const Color(0xFF000000),
    scrim: scrim,
    inverseSurface: text,
    onInverseSurface: background,
    inversePrimary: accentSubtle,
  );

  @override
  BrewColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceMuted,
    Color? accent,
    Color? accentStrong,
    Color? accentSubtle,
    Color? onAccent,
    Color? secondary,
    Color? secondarySubtle,
    Color? onSecondary,
    Color? text,
    Color? textSecondary,
    Color? textTertiary,
    Color? success,
    Color? successText,
    Color? warning,
    Color? warningText,
    Color? danger,
    Color? dangerText,
    Color? onDanger,
    Color? info,
    Color? infoText,
    Color? divider,
    Color? focusRing,
    Color? scrim,
    Color? shimmerBase,
    Color? shimmerHighlight,
  }) => BrewColors(
    brightness: brightness,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceElevated: surfaceElevated ?? this.surfaceElevated,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    accent: accent ?? this.accent,
    accentStrong: accentStrong ?? this.accentStrong,
    accentSubtle: accentSubtle ?? this.accentSubtle,
    onAccent: onAccent ?? this.onAccent,
    secondary: secondary ?? this.secondary,
    secondarySubtle: secondarySubtle ?? this.secondarySubtle,
    onSecondary: onSecondary ?? this.onSecondary,
    text: text ?? this.text,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    success: success ?? this.success,
    successText: successText ?? this.successText,
    warning: warning ?? this.warning,
    warningText: warningText ?? this.warningText,
    danger: danger ?? this.danger,
    dangerText: dangerText ?? this.dangerText,
    onDanger: onDanger ?? this.onDanger,
    info: info ?? this.info,
    infoText: infoText ?? this.infoText,
    divider: divider ?? this.divider,
    focusRing: focusRing ?? this.focusRing,
    scrim: scrim ?? this.scrim,
    shimmerBase: shimmerBase ?? this.shimmerBase,
    shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
  );

  @override
  BrewColors lerp(BrewColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return BrewColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceElevated: l(surfaceElevated, other.surfaceElevated),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      accent: l(accent, other.accent),
      accentStrong: l(accentStrong, other.accentStrong),
      accentSubtle: l(accentSubtle, other.accentSubtle),
      onAccent: l(onAccent, other.onAccent),
      secondary: l(secondary, other.secondary),
      secondarySubtle: l(secondarySubtle, other.secondarySubtle),
      onSecondary: l(onSecondary, other.onSecondary),
      text: l(text, other.text),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      success: l(success, other.success),
      successText: l(successText, other.successText),
      warning: l(warning, other.warning),
      warningText: l(warningText, other.warningText),
      danger: l(danger, other.danger),
      dangerText: l(dangerText, other.dangerText),
      onDanger: l(onDanger, other.onDanger),
      info: l(info, other.info),
      infoText: l(infoText, other.infoText),
      divider: l(divider, other.divider),
      focusRing: l(focusRing, other.focusRing),
      scrim: l(scrim, other.scrim),
      shimmerBase: l(shimmerBase, other.shimmerBase),
      shimmerHighlight: l(shimmerHighlight, other.shimmerHighlight),
    );
  }
}

/// A status, for pills, banners and icons.
enum BrewTone { neutral, info, success, warning, danger }

extension BrewToneColors on BrewColors {
  /// Fill/icon colour for [tone].
  Color toneColor(BrewTone tone) => switch (tone) {
    BrewTone.neutral => textSecondary,
    BrewTone.info => info,
    BrewTone.success => success,
    BrewTone.warning => warning,
    BrewTone.danger => danger,
  };

  /// Text colour for [tone] on a surface or a [toneBackground].
  Color toneText(BrewTone tone) => switch (tone) {
    BrewTone.neutral => textSecondary,
    BrewTone.info => infoText,
    BrewTone.success => successText,
    BrewTone.warning => warningText,
    BrewTone.danger => dangerText,
  };

  /// A low-contrast tint of [tone] for pill and banner backgrounds.
  Color toneBackground(BrewTone tone) => tone == BrewTone.neutral
      ? surfaceMuted
      : toneColor(tone).withValues(alpha: isDark ? 0.18 : 0.12);
}
