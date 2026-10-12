import 'package:flutter/material.dart';

import '../tokens/brew_colors.dart';
import '../tokens/brew_layout.dart';
import '../tokens/brew_typography.dart';

/// Builds a Material 3 [ThemeData] from Brew tokens.
///
/// Apps pass their own palette (and font, and shape); everything else (the
/// component themes, the token extensions) is shared. Add app-specific
/// ThemeExtensions through [extensions].
///
/// ```dart
/// MaterialApp(
///   theme: buildBrewTheme(colors: BrewColors.fromSeed(seed)),
///   darkTheme: buildBrewTheme(
///     colors: BrewColors.fromSeed(seed, brightness: Brightness.dark),
///   ),
/// )
/// ```
ThemeData buildBrewTheme({
  required BrewColors colors,
  BrewTypography? typography,
  BrewShape shape = const BrewShape(),
  String? fontFamily,
  List<String>? fontFamilyFallback,
  Iterable<ThemeExtension<dynamic>> extensions = const [],
}) {
  final type =
      typography ??
      BrewTypography.standard(
        ink: colors.text,
        muted: colors.textSecondary,
        fontFamily: fontFamily,
      );
  final scheme = colors.toColorScheme();
  final control = shape.controlRadius;
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: control,
    borderSide: BorderSide(color: c, width: w),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: colors.brightness,
    colorScheme: scheme,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    textTheme: type.toTextTheme(),
    scaffoldBackgroundColor: colors.background,
    canvasColor: colors.background,
    dividerTheme: DividerThemeData(color: colors.divider, space: 1),
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: shape.cardRadius),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceElevated,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: BrewSpacing.md + 2,
        vertical: BrewSpacing.md,
      ),
      border: border(colors.divider),
      enabledBorder: border(colors.divider),
      focusedBorder: border(colors.focusRing, 2),
      errorBorder: border(colors.danger),
      focusedErrorBorder: border(colors.danger, 2),
      disabledBorder: border(colors.divider.withValues(alpha: 0.5)),
      hintStyle: type.body.copyWith(color: colors.textTertiary, fontSize: 14),
      labelStyle: type.body.copyWith(color: colors.textSecondary, fontSize: 14),
      helperStyle: type.bodySmall,
      errorStyle: type.bodySmall.copyWith(color: colors.dangerText),
      prefixIconColor: colors.textSecondary,
      suffixIconColor: colors.textSecondary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: control),
        textStyle: type.label.copyWith(fontSize: 14),
        minimumSize: const Size(64, 44),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.accentStrong,
        side: BorderSide(color: colors.accent),
        shape: RoundedRectangleBorder(borderRadius: control),
        textStyle: type.label.copyWith(fontSize: 14),
        minimumSize: const Size(64, 44),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.accentStrong,
        shape: RoundedRectangleBorder(borderRadius: control),
        textStyle: type.label.copyWith(fontSize: 14),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: colors.accentSubtle,
        selectedForegroundColor: colors.accentStrong,
        foregroundColor: colors.textSecondary,
        side: BorderSide(color: colors.divider),
        shape: RoundedRectangleBorder(borderRadius: control),
        textStyle: type.label,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surfaceMuted,
      selectedColor: colors.accentSubtle,
      side: BorderSide.none,
      labelStyle: type.label.copyWith(color: colors.text),
      shape: const StadiumBorder(),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: shape.sheetRadius),
      titleTextStyle: type.title,
      contentTextStyle: type.body.copyWith(color: colors.textSecondary),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surfaceElevated,
      modalBarrierColor: colors.scrim,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(shape.sheet)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colors.text,
      contentTextStyle: type.body.copyWith(color: colors.background),
      actionTextColor: colors.accentSubtle,
      shape: RoundedRectangleBorder(borderRadius: control),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      indicatorColor: colors.accentSubtle,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? colors.accentStrong
              : colors.textSecondary,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => type.caption.copyWith(
          letterSpacing: 0.2,
          color: s.contains(WidgetState.selected)
              ? colors.accentStrong
              : colors.textSecondary,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colors.surface,
      indicatorColor: colors.accentSubtle,
      selectedIconTheme: IconThemeData(color: colors.accentStrong),
      unselectedIconTheme: IconThemeData(color: colors.textSecondary),
      selectedLabelTextStyle: type.label.copyWith(color: colors.accentStrong),
      unselectedLabelTextStyle: type.label.copyWith(
        color: colors.textSecondary,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colors.textSecondary,
      titleTextStyle: type.titleSmall.copyWith(fontWeight: FontWeight.w500),
      subtitleTextStyle: type.bodySmall,
      shape: RoundedRectangleBorder(borderRadius: control),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.accent,
      linearTrackColor: colors.surfaceMuted,
      circularTrackColor: Colors.transparent,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? colors.onAccent : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? colors.accent : null,
      ),
    ),
    extensions: [colors, type, shape, ...extensions],
  );
}

/// Token access from widgets. Falls back to values derived from the ambient
/// [ThemeData] when an app hasn't installed the extensions yet, so brew_ui
/// widgets can be dropped into an app before its theme is migrated.
extension BrewThemeContext on BuildContext {
  BrewColors get brewColors {
    final theme = Theme.of(this);
    return theme.extension<BrewColors>() ??
        BrewColors.fromScheme(theme.colorScheme);
  }

  BrewTypography get brewType {
    final theme = Theme.of(this);
    return theme.extension<BrewTypography>() ??
        BrewTypography.standard(
          ink: theme.colorScheme.onSurface,
          muted: theme.colorScheme.onSurfaceVariant,
        );
  }

  BrewShape get brewShape =>
      Theme.of(this).extension<BrewShape>() ?? const BrewShape();
}
