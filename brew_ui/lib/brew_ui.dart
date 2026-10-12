/// Design tokens and widget primitives for Brew apps.
///
/// Apps share the *system* (colour roles, type scale, spacing, motion, shape,
/// component themes, primitives) and keep their *identity*: each passes its own
/// palette, font and radii to [buildBrewTheme], and composes its own screens
/// from the parts here. Related, not identical.
///
/// Widgets read tokens through `context.brewColors` / `brewType` /
/// `brewShape`, which fall back to the ambient Material theme. So brew_ui
/// widgets can go into an app before its theme is migrated.
///
/// No Brew dependencies: widgets take callbacks, and the app wires them to
/// brew_auth and brew_core.
library;

export 'src/auth/brew_auth_parts.dart';
export 'src/gallery.dart';
export 'src/settings/brew_settings_parts.dart';
export 'src/shell/brew_adaptive_shell.dart';
export 'src/theme/brew_theme.dart';
export 'src/theme/theme_mode.dart';
export 'src/tokens/brew_colors.dart';
export 'src/tokens/brew_layout.dart';
export 'src/tokens/brew_typography.dart';
export 'src/widgets/brew_button.dart';
export 'src/widgets/brew_dialogs.dart';
export 'src/widgets/brew_fields.dart';
export 'src/widgets/brew_states.dart';
export 'src/widgets/brew_surfaces.dart';
