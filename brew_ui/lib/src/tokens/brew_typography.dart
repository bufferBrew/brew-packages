import 'dart:ui' show FontFeature, lerpDouble;

import 'package:flutter/material.dart';

/// The Brew type scale, as a ThemeExtension.
///
/// From BrewVoyage's `AppTypography`: tight, heavy display sizes with negative
/// tracking, relaxed body line-height, and a wide-tracked [caption] for
/// eyebrows. [numeric] uses tabular figures so counters don't jitter. The
/// font is the app's choice; the scale is shared.
@immutable
class BrewTypography extends ThemeExtension<BrewTypography> {
  const BrewTypography({
    required this.display,
    required this.headline,
    required this.title,
    required this.titleSmall,
    required this.body,
    required this.bodySmall,
    required this.label,
    required this.caption,
    required this.numeric,
  });

  /// The standard scale in [ink], with [muted] for secondary styles.
  factory BrewTypography.standard({
    required Color ink,
    required Color muted,
    String? fontFamily,
  }) {
    TextStyle s(
      double size,
      double height,
      FontWeight weight, {
      double tracking = 0,
      Color? color,
    }) => TextStyle(
      fontFamily: fontFamily,
      color: color ?? ink,
      fontSize: size,
      height: height,
      fontWeight: weight,
      letterSpacing: tracking,
    );
    return BrewTypography(
      display: s(36, 1.05, FontWeight.w800, tracking: -1.2),
      headline: s(26, 1.15, FontWeight.w700, tracking: -0.5),
      title: s(20, 1.2, FontWeight.w700, tracking: -0.2),
      titleSmall: s(16, 1.25, FontWeight.w600),
      body: s(15, 1.45, FontWeight.w400),
      bodySmall: s(13.5, 1.4, FontWeight.w400, color: muted),
      label: s(13, 1.2, FontWeight.w600, tracking: 0.1),
      caption: s(11.5, 1.2, FontWeight.w600, tracking: 0.8, color: muted),
      numeric: s(
        15,
        1.2,
        FontWeight.w600,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }

  /// Hero numbers and screen titles. 36/1.05, w800.
  final TextStyle display;

  /// Section-defining headline. 26/1.15, w700.
  final TextStyle headline;

  /// Card and dialog titles. 20/1.2, w700.
  final TextStyle title;

  /// Dense titles and list rows. 16/1.25, w600.
  final TextStyle titleSmall;

  /// Body copy. 15/1.45.
  final TextStyle body;

  /// Secondary body copy. 13.5/1.4, muted.
  final TextStyle bodySmall;

  /// Buttons, tabs, pills. 13/1.2, w600.
  final TextStyle label;

  /// Eyebrows and metadata. 11.5/1.2, w600, wide tracking, muted.
  final TextStyle caption;

  /// Tabular figures for counters, money, countdowns.
  final TextStyle numeric;

  /// The same scale mapped onto Material's [TextTheme], so stock widgets use
  /// it too.
  TextTheme toTextTheme() => TextTheme(
    displaySmall: display,
    headlineMedium: headline,
    headlineSmall: headline.copyWith(fontSize: 22),
    titleLarge: title,
    titleMedium: titleSmall,
    titleSmall: label.copyWith(fontSize: 14),
    bodyLarge: body,
    bodyMedium: body.copyWith(fontSize: 14),
    bodySmall: bodySmall,
    labelLarge: label.copyWith(fontSize: 14),
    labelMedium: label,
    labelSmall: caption,
  );

  @override
  BrewTypography copyWith({
    TextStyle? display,
    TextStyle? headline,
    TextStyle? title,
    TextStyle? titleSmall,
    TextStyle? body,
    TextStyle? bodySmall,
    TextStyle? label,
    TextStyle? caption,
    TextStyle? numeric,
  }) => BrewTypography(
    display: display ?? this.display,
    headline: headline ?? this.headline,
    title: title ?? this.title,
    titleSmall: titleSmall ?? this.titleSmall,
    body: body ?? this.body,
    bodySmall: bodySmall ?? this.bodySmall,
    label: label ?? this.label,
    caption: caption ?? this.caption,
    numeric: numeric ?? this.numeric,
  );

  @override
  BrewTypography lerp(BrewTypography? other, double t) {
    if (other == null) return this;
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return BrewTypography(
      display: l(display, other.display),
      headline: l(headline, other.headline),
      title: l(title, other.title),
      titleSmall: l(titleSmall, other.titleSmall),
      body: l(body, other.body),
      bodySmall: l(bodySmall, other.bodySmall),
      label: l(label, other.label),
      caption: l(caption, other.caption),
      numeric: l(numeric, other.numeric),
    );
  }
}

/// Corner radii, per app: BREW's dashboard is tight (8/10), BrewVoyage is
/// generous (12/20). Shape is a big part of an app's identity, so it's a
/// ThemeExtension rather than a constant.
@immutable
class BrewShape extends ThemeExtension<BrewShape> {
  const BrewShape({this.control = 10, this.card = 14, this.sheet = 24});

  /// Buttons, inputs, chips.
  final double control;

  /// Cards and tiles.
  final double card;

  /// Bottom sheets and dialogs.
  final double sheet;

  BorderRadius get controlRadius => BorderRadius.circular(control);
  BorderRadius get cardRadius => BorderRadius.circular(card);
  BorderRadius get sheetRadius => BorderRadius.circular(sheet);

  @override
  BrewShape copyWith({double? control, double? card, double? sheet}) =>
      BrewShape(
        control: control ?? this.control,
        card: card ?? this.card,
        sheet: sheet ?? this.sheet,
      );

  @override
  BrewShape lerp(BrewShape? other, double t) {
    if (other == null) return this;
    return BrewShape(
      control: lerpDouble(control, other.control, t)!,
      card: lerpDouble(card, other.card, t)!,
      sheet: lerpDouble(sheet, other.sheet, t)!,
    );
  }
}
