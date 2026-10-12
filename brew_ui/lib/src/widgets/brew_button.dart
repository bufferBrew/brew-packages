import 'package:flutter/material.dart';

import '../theme/brew_theme.dart';

enum BrewButtonVariant {
  /// Filled with the accent. One per view.
  primary,

  /// Accent outline.
  secondary,

  /// Text only, for low-emphasis actions.
  ghost,

  /// Filled with danger, for destructive confirms.
  danger,
}

enum BrewButtonSize { sm, md, lg }

/// The Brew button.
///
/// Built on [TextButton] rather than a hand-rolled InkWell (which BREW's
/// `AppButton` was), so focus, keyboard activation, hover and the button
/// semantics role come from Material. Heights are 36/44/52 with a padded tap
/// target, so even `sm` meets the 48dp minimum.
class BrewButton extends StatelessWidget {
  const BrewButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.variant = BrewButtonVariant.primary,
    this.size = BrewButtonSize.md,
    this.loading = false,
    this.fullWidth = false,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final IconData? icon;

  /// A custom mark before the label (a brand logo), used instead of [icon].
  /// Keep it decorative: the label is what screen readers announce.
  final Widget? leading;
  final BrewButtonVariant variant;
  final BrewButtonSize size;

  /// Shows a spinner and blocks presses; the label stays for screen readers.
  final bool loading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.brewColors;
    final type = context.brewType;
    final (double height, double hPad, double fontSize) = switch (size) {
      BrewButtonSize.sm => (36.0, 14.0, 13.0),
      BrewButtonSize.md => (44.0, 20.0, 14.0),
      BrewButtonSize.lg => (52.0, 28.0, 15.0),
    };
    final (Color? bg, Color fg, BorderSide? side) = switch (variant) {
      BrewButtonVariant.primary => (c.accent, c.onAccent, null),
      BrewButtonVariant.secondary => (
        null,
        c.accentStrong,
        BorderSide(color: c.accent),
      ),
      BrewButtonVariant.ghost => (null, c.accentStrong, null),
      BrewButtonVariant.danger => (c.danger, c.onDanger, null),
    };
    bool off(Set<WidgetState> s) => s.contains(WidgetState.disabled);

    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(fullWidth ? double.infinity : 64, height),
      ),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: hPad)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: context.brewShape.controlRadius),
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => bg == null
            ? null
            : off(s) && !loading
            ? bg.withValues(alpha: 0.38)
            : bg,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => off(s) && !loading ? fg.withValues(alpha: 0.5) : fg,
      ),
      overlayColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.pressed)
            ? fg.withValues(alpha: 0.14)
            : s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)
            ? fg.withValues(alpha: 0.08)
            : null,
      ),
      side: WidgetStateProperty.resolveWith(
        (s) => side == null
            ? null
            : off(s) && !loading
            ? side.copyWith(color: side.color.withValues(alpha: 0.38))
            : side,
      ),
      textStyle: WidgetStatePropertyAll(
        type.label.copyWith(fontSize: fontSize),
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
      elevation: const WidgetStatePropertyAll(0),
    );

    final Widget child = loading
        ? Semantics(
            label: label,
            child: SizedBox.square(
              dimension: fontSize + 4,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                ExcludeSemantics(child: leading!),
                const SizedBox(width: 8),
              ] else if (icon != null) ...[
                Icon(icon, size: fontSize + 4),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    return TextButton(
      onPressed: loading ? null : onPressed,
      style: style,
      child: child,
    );
  }
}
