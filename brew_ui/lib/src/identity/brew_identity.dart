import 'package:flutter/material.dart';

import '../theme/brew_theme.dart';
import '../tokens/brew_layout.dart';

/// The background every Brew launcher icon and [BrewAppMark] sits on: the
/// near-black of the shared icon template (`branding/` in brew-packages).
const brewIconInk = Color(0xFF060811);

/// Who this app is inside the Brew family: its one-word name, its accent,
/// and its icon.
///
/// The family resemblance comes from what's shared (this lockup, the icon
/// template, brew_ui's parts), not from the names. Install one at the top of
/// the app with [BrewIdentityScope]; [BrewAboutTile], [BrewFooter] and
/// [BrewAppSwitcher] read it from there.
@immutable
class BrewAppIdentity {
  const BrewAppIdentity({
    required this.key,
    required this.name,
    required this.accent,
    this.glyph,
    this.icon = Icons.apps_rounded,
    this.tagline = '',
    this.version,
    this.webUrl,
  });

  /// The app's key in `core.apps` (`synapse`, `wire`, `brew`…), so the
  /// switcher can mark the current app.
  final String key;

  /// One-word product name, e.g. "Synapse".
  final String name;

  /// The app's brand colour. Also the neon rim on its launcher icon.
  final Color accent;

  /// The launcher icon artwork, usually
  /// `AssetImage('assets/branding/app_icon.png')`. Null draws [icon] on the
  /// icon template's background instead.
  final ImageProvider? glyph;

  /// Fallback glyph when there's no [glyph] image.
  final IconData icon;

  /// One line on what the app is for.
  final String tagline;

  /// Shown in the about tile and dialog, e.g. "1.4.0".
  final String? version;

  /// Where the app lives on the web, if it does.
  final Uri? webUrl;

  /// "Synapse · a Brew app": how every app presents itself.
  String get lockup => '$name · a Brew app';

  static BrewAppIdentity? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BrewIdentityScope>()?.identity;

  static BrewAppIdentity of(BuildContext context) {
    final identity = maybeOf(context);
    assert(identity != null, 'No BrewIdentityScope above this widget.');
    return identity!;
  }

  @override
  bool operator ==(Object other) =>
      other is BrewAppIdentity &&
      other.key == key &&
      other.name == name &&
      other.accent == accent &&
      other.glyph == glyph &&
      other.icon == icon &&
      other.tagline == tagline &&
      other.version == version &&
      other.webUrl == webUrl;

  @override
  int get hashCode =>
      Object.hash(key, name, accent, glyph, icon, tagline, version, webUrl);
}

/// Makes a [BrewAppIdentity] available below it. Put it in
/// `MaterialApp.builder` so dialogs and sheets see it too.
class BrewIdentityScope extends InheritedWidget {
  const BrewIdentityScope({
    super.key,
    required this.identity,
    required super.child,
  });

  final BrewAppIdentity identity;

  @override
  bool updateShouldNotify(BrewIdentityScope oldWidget) =>
      identity != oldWidget.identity;
}

/// An app's icon as a rounded square: its [BrewAppIdentity.glyph] image, or
/// its fallback icon in the accent on the template's dark background.
class BrewAppMark extends StatelessWidget {
  const BrewAppMark({
    super.key,
    required this.identity,
    this.size = 40,
    this.semanticLabel,
  });

  final BrewAppIdentity identity;
  final double size;

  /// Defaults to excluding the mark from semantics: it usually sits next to
  /// the app's name, which already says it.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.225);
    final glyph = identity.glyph;
    final Widget mark = glyph != null
        ? ClipRRect(
            borderRadius: radius,
            child: Image(
              image: glyph,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(radius),
            ),
          )
        : _fallback(radius);
    final sized = SizedBox.square(dimension: size, child: mark);
    if (semanticLabel == null) return ExcludeSemantics(child: sized);
    return Semantics(image: true, label: semanticLabel, child: sized);
  }

  Widget _fallback(BorderRadius radius) => DecoratedBox(
    decoration: BoxDecoration(
      color: brewIconInk,
      borderRadius: radius,
      border: Border.all(
        color: identity.accent.withValues(alpha: 0.55),
        width: (size / 40).clamp(1.0, 2.0),
      ),
    ),
    child: Center(
      child: Icon(identity.icon, size: size * 0.55, color: identity.accent),
    ),
  );
}

/// "Synapse · a Brew app" as a single quiet line, for the end of a settings
/// page or a drawer.
class BrewFooter extends StatelessWidget {
  const BrewFooter({super.key, this.identity});

  /// Defaults to the ambient [BrewIdentityScope].
  final BrewAppIdentity? identity;

  @override
  Widget build(BuildContext context) {
    final id = identity ?? BrewAppIdentity.of(context);
    final version = id.version;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BrewSpacing.lg),
      child: Text(
        version == null ? id.lockup : '${id.lockup} · v$version',
        textAlign: TextAlign.center,
        style: context.brewType.caption,
      ),
    );
  }
}

/// The "about" row every Brew app carries in its settings: icon, name, "a
/// Brew app", version. Tapping opens [showBrewAboutDialog] unless [onTap]
/// says otherwise.
class BrewAboutTile extends StatelessWidget {
  const BrewAboutTile({super.key, this.identity, this.onTap});

  /// Defaults to the ambient [BrewIdentityScope].
  final BrewAppIdentity? identity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final id = identity ?? BrewAppIdentity.of(context);
    final version = id.version;
    return ListTile(
      leading: BrewAppMark(identity: id),
      title: Text(id.name),
      subtitle: Text(version == null ? 'a Brew app' : 'a Brew app · v$version'),
      trailing: const Icon(Icons.info_outline_rounded),
      onTap: onTap ?? () => showBrewAboutDialog(context, identity: id),
      contentPadding: const EdgeInsets.symmetric(horizontal: BrewSpacing.lg),
    );
  }
}

/// Flutter's about dialog (licences included) dressed as a Brew app.
void showBrewAboutDialog(
  BuildContext context, {
  BrewAppIdentity? identity,
  List<Widget> children = const [],
}) {
  final id = identity ?? BrewAppIdentity.of(context);
  showAboutDialog(
    context: context,
    applicationName: id.name,
    applicationVersion: id.version,
    applicationIcon: BrewAppMark(identity: id, size: 48),
    applicationLegalese: 'a Brew app by bufferBrew',
    children: [
      if (id.tagline.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: BrewSpacing.lg),
          child: Text(id.tagline),
        ),
      ...children,
    ],
  );
}
