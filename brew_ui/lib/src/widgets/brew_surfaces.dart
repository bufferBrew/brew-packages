import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/brew_theme.dart';
import '../tokens/brew_colors.dart';
import '../tokens/brew_layout.dart';

enum BrewCardVariant { flat, elevated, outlined }

/// A card on the app's surface colour and card radius.
///
/// Tappable when [onTap] is set, with the ripple clipped to the shape and a
/// button role for screen readers.
class BrewCard extends StatelessWidget {
  const BrewCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BrewSpacing.lg),
    this.onTap,
    this.variant = BrewCardVariant.flat,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BrewCardVariant variant;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.brewColors;
    final body = Padding(padding: padding, child: child);
    final card = Material(
      color: variant == BrewCardVariant.elevated
          ? c.surfaceElevated
          : c.surface,
      elevation: variant == BrewCardVariant.elevated ? 2 : 0,
      shadowColor: Colors.black.withValues(alpha: c.isDark ? 0.5 : 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: context.brewShape.cardRadius,
        side: variant == BrewCardVariant.outlined
            ? BorderSide(color: c.divider)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
    if (onTap == null && semanticLabel == null) return card;
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      container: true,
      child: card,
    );
  }
}

/// Scale-on-press wrapper for custom tappable surfaces (from BREW's
/// `Pressable`). Shrinks to 0.97 while pressed, with a light haptic on tap;
/// no scale under reduced motion.
class BrewPressable extends StatefulWidget {
  const BrewPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  State<BrewPressable> createState() => _BrewPressableState();
}

class _BrewPressableState extends State<BrewPressable> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final radius = widget.borderRadius ?? context.brewShape.cardRadius;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _pressed && !BrewMotion.reduced(context) ? 0.97 : 1,
        duration: const Duration(milliseconds: 100),
        curve: BrewMotion.enter,
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled
                ? () {
                    HapticFeedback.lightImpact();
                    widget.onTap!();
                  }
                : null,
            onLongPress: widget.onLongPress == null
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    widget.onLongPress!();
                  },
            onHighlightChanged: enabled ? _set : null,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// A section title with an optional eyebrow and trailing action.
class BrewSectionHeader extends StatelessWidget {
  const BrewSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(bottom: BrewSpacing.sm),
  });

  final String title;

  /// Small uppercase label above the title.
  final String? eyebrow;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final type = context.brewType;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (eyebrow != null) ...[
                    Text(eyebrow!.toUpperCase(), style: type.caption),
                    const SizedBox(height: BrewSpacing.xs),
                  ],
                  Text(title, style: type.title),
                ],
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// A small status label: "Connected", "Needs attention", "Beta".
class BrewStatusPill extends StatelessWidget {
  const BrewStatusPill({
    super.key,
    required this.label,
    this.tone = BrewTone.neutral,
    this.icon,
  });

  final String label;
  final BrewTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.brewColors;
    final fg = c.toneText(tone);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BrewSpacing.sm + 2,
        vertical: BrewSpacing.xs,
      ),
      decoration: ShapeDecoration(
        color: c.toneBackground(tone),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: BrewSpacing.xs),
          ],
          Text(label, style: context.brewType.label.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// Animated skeleton placeholder. Static under reduced motion.
class BrewShimmer extends StatefulWidget {
  const BrewShimmer({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  /// A column of [count] text-line skeletons, the last one shorter.
  static Widget lines({int count = 3, double lineHeight = 14}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < count; i++) ...[
        if (i > 0) const SizedBox(height: BrewSpacing.sm),
        FractionallySizedBox(
          widthFactor: i == count - 1 && count > 1 ? 0.6 : 1,
          child: BrewShimmer(height: lineHeight),
        ),
      ],
    ],
  );

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<BrewShimmer> createState() => _BrewShimmerState();
}

class _BrewShimmerState extends State<BrewShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (BrewMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brewColors;
    final radius = widget.borderRadius ?? BorderRadius.circular(6);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * 2 - 0.5;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                colors: [c.shimmerBase, c.shimmerHighlight, c.shimmerBase],
                stops: [
                  (t - 0.3).clamp(0.0, 1.0),
                  t.clamp(0.0, 1.0),
                  (t + 0.3).clamp(0.0, 1.0),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
