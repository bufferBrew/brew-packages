import 'package:flutter/material.dart';

import '../theme/brew_theme.dart';
import '../tokens/brew_layout.dart';
import 'brew_identity.dart';

/// One app in the [BrewAppSwitcher].
///
/// brew_ui doesn't depend on brew_core, so this is a plain value: map
/// brew_core's `BrewApp` rows (from `brewAppsProvider`, backed by
/// `core.apps`) onto it with [BrewSwitcherApp.new]:
///
/// ```dart
/// BrewSwitcherApp(
///   key: app.key,
///   name: app.displayName,
///   description: app.description,
///   icon: brewIconByName(app.icon),
///   url: knownUrls[app.key] ?? app.repoUrl,
/// )
/// ```
@immutable
class BrewSwitcherApp {
  const BrewSwitcherApp({
    required this.key,
    required this.name,
    this.description = '',
    this.icon = Icons.apps_rounded,
    this.accent,
    this.url,
  });

  final String key;
  final String name;
  final String description;
  final IconData icon;

  /// The app's accent, when this app knows it. Falls back to the theme's.
  final Color? accent;

  /// Where tapping goes. Null shows the app but doesn't open anything.
  final Uri? url;
}

/// The Material icon for a `core.apps.icon` name such as
/// `dashboard_rounded`. Unknown or null names fall back to a generic grid.
///
/// Icons can't be looked up by name at runtime without defeating tree
/// shaking, so this covers the names in the registry; add to it when a new
/// app registers a new one.
IconData brewIconByName(String? name) => switch (name) {
  'dashboard_rounded' => Icons.dashboard_rounded,
  'article_rounded' => Icons.article_rounded,
  'luggage_rounded' => Icons.luggage_rounded,
  'work_rounded' => Icons.work_rounded,
  'help_rounded' => Icons.help_rounded,
  'mic_rounded' => Icons.mic_rounded,
  'auto_stories_rounded' => Icons.auto_stories_rounded,
  'child_care_rounded' => Icons.child_care_rounded,
  'translate_rounded' => Icons.translate_rounded,
  'school_rounded' => Icons.school_rounded,
  'psychology_rounded' => Icons.psychology_rounded,
  'rss_feed_rounded' => Icons.rss_feed_rounded,
  'notes_rounded' => Icons.notes_rounded,
  'savings_rounded' => Icons.savings_rounded,
  'record_voice_over_rounded' => Icons.record_voice_over_rounded,
  _ => Icons.apps_rounded,
};

/// A list of the other Brew apps, the current one marked. Use it in a sheet
/// ([showBrewAppSwitcher]) or on a page of its own.
class BrewAppSwitcher extends StatelessWidget {
  const BrewAppSwitcher({
    super.key,
    required this.apps,
    required this.onOpen,
    this.currentKey,
  });

  final List<BrewSwitcherApp> apps;

  /// Called with an app that has a [BrewSwitcherApp.url]. The app decides how
  /// to open it (`url_launcher`, a new tab, an in-app route).
  final ValueChanged<BrewSwitcherApp> onOpen;

  /// The running app, from [BrewAppIdentity.key]. Defaults to the ambient
  /// [BrewIdentityScope].
  final String? currentKey;

  @override
  Widget build(BuildContext context) {
    final current = currentKey ?? BrewAppIdentity.maybeOf(context)?.key;
    final c = context.brewColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final app in apps)
          _row(context, app, isCurrent: app.key == current, accent: c.accent),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    BrewSwitcherApp app, {
    required bool isCurrent,
    required Color accent,
  }) {
    final mark = BrewAppMark(
      identity: BrewAppIdentity(
        key: app.key,
        name: app.name,
        accent: app.accent ?? accent,
        icon: app.icon,
      ),
    );
    final canOpen = !isCurrent && app.url != null;
    return ListTile(
      leading: mark,
      title: Text(app.name),
      subtitle: app.description.isEmpty
          ? null
          : Text(app.description, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: isCurrent
          ? Text('You are here', style: context.brewType.caption)
          : canOpen
          ? const Icon(Icons.open_in_new_rounded)
          : null,
      selected: isCurrent,
      enabled: isCurrent || canOpen,
      onTap: canOpen ? () => onOpen(app) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: BrewSpacing.lg),
    );
  }
}

/// Opens [BrewAppSwitcher] in a bottom sheet titled "Brew apps".
///
/// An empty [apps] list (registry not loaded, or no `core` on this backend)
/// shows a short "no other apps" note rather than an empty sheet.
Future<void> showBrewAppSwitcher(
  BuildContext context, {
  required List<BrewSwitcherApp> apps,
  required ValueChanged<BrewSwitcherApp> onOpen,
  String? currentKey,
}) {
  final key = currentKey ?? BrewAppIdentity.maybeOf(context)?.key;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: BrewSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BrewSpacing.lg,
                0,
                BrewSpacing.lg,
                BrewSpacing.sm,
              ),
              child: Semantics(
                header: true,
                child: Text('Brew apps', style: sheetContext.brewType.title),
              ),
            ),
            if (apps.isEmpty)
              const Padding(
                padding: EdgeInsets.all(BrewSpacing.xl),
                child: Center(child: Text('No other Brew apps here yet.')),
              )
            else
              BrewAppSwitcher(
                apps: apps,
                currentKey: key,
                onOpen: (app) {
                  Navigator.of(sheetContext).pop();
                  onOpen(app);
                },
              ),
          ],
        ),
      ),
    ),
  );
}
