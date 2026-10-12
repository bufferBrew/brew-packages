import 'package:flutter/widgets.dart';

/// 4px-base spacing scale. Every gap and inset comes from here; no ad-hoc
/// `SizedBox(height: 13)`.
abstract final class BrewSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page gutter, widening with the viewport.
  static double gutter(double width) {
    if (width >= BrewBreakpoints.expanded) return xxl;
    if (width >= BrewBreakpoints.medium) return xl;
    return lg;
  }
}

/// Layout breakpoints, shared so every app switches from bottom bar to rail
/// at the same width.
abstract final class BrewBreakpoints {
  /// Below this: phones. One column, bottom navigation.
  static const double compact = 600;

  /// Tablet / small laptop. Navigation rail.
  static const double medium = 1000;

  /// Desktop. Extended rail with labels.
  static const double expanded = 1400;

  /// Widest a text column may get.
  static const double contentMaxWidth = 1080;

  /// Cap for forms and reading surfaces.
  static const double readingMaxWidth = 640;

  static bool isCompact(double width) => width < compact;
}

/// The named motion system. No magic millisecond literals in UI code.
///
/// Press/toggle feedback uses [fast]; entrances and state changes [medium];
/// route continuity [slow]. Decorative motion must check [reduced].
abstract final class BrewMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration deliberate = Duration(milliseconds: 700);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve transition = Curves.easeInOutCubic;
  static const Curve emphasised = Cubic(0.2, 0.0, 0.0, 1.0);

  /// The platform asked for reduced motion, or a screen reader is driving.
  static bool reduced(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    if (media == null) return false;
    return media.disableAnimations || media.accessibleNavigation;
  }

  /// [duration], or zero under reduced motion.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

/// Centres and width-caps [child] so wide viewports keep a readable measure.
///
/// `Align(heightFactor: 1)` rather than `Center`: a Center expands to the
/// tallest allowed size, which swallows the viewport in a height-loose slot.
class BrewContentWidth extends StatelessWidget {
  const BrewContentWidth({
    super.key,
    required this.child,
    this.maxWidth = BrewBreakpoints.contentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
