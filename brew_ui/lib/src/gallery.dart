import 'package:flutter/material.dart';

import 'auth/brew_auth_parts.dart';
import 'settings/brew_settings_parts.dart';
import 'theme/brew_theme.dart';
import 'tokens/brew_colors.dart';
import 'tokens/brew_layout.dart';
import 'widgets/brew_button.dart';
import 'widgets/brew_fields.dart';
import 'widgets/brew_states.dart';
import 'widgets/brew_surfaces.dart';

/// Every brew_ui primitive on one scrollable page, in the ambient theme.
///
/// Mount it on a debug route to see how your palette renders the shared
/// parts. It's also what the golden and accessibility tests render.
class BrewComponentGallery extends StatelessWidget {
  const BrewComponentGallery({super.key, this.animate = true});

  /// False freezes shimmers, for golden tests.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = context.brewColors;
    Widget gap([double h = BrewSpacing.lg]) => SizedBox(height: h);
    return ListView(
      padding: const EdgeInsets.all(BrewSpacing.lg),
      children: [
        const BrewSectionHeader(title: 'Buttons', eyebrow: 'Primitives'),
        Wrap(
          spacing: BrewSpacing.sm,
          runSpacing: BrewSpacing.sm,
          children: [
            BrewButton(label: 'Primary', onPressed: () {}),
            BrewButton(
              label: 'Secondary',
              variant: BrewButtonVariant.secondary,
              onPressed: () {},
            ),
            BrewButton(
              label: 'Ghost',
              variant: BrewButtonVariant.ghost,
              onPressed: () {},
            ),
            BrewButton(
              label: 'Delete',
              variant: BrewButtonVariant.danger,
              icon: Icons.delete_outline_rounded,
              onPressed: () {},
            ),
            const BrewButton(label: 'Disabled', onPressed: null),
            BrewButton(label: 'Saving', loading: true, onPressed: () {}),
          ],
        ),
        gap(),
        const BrewSectionHeader(title: 'Status'),
        const Wrap(
          spacing: BrewSpacing.sm,
          runSpacing: BrewSpacing.sm,
          children: [
            BrewStatusPill(label: 'Neutral'),
            BrewStatusPill(label: 'New', tone: BrewTone.info),
            BrewStatusPill(
              label: 'Connected',
              tone: BrewTone.success,
              icon: Icons.check_rounded,
            ),
            BrewStatusPill(label: 'Expiring', tone: BrewTone.warning),
            BrewStatusPill(label: 'Failed', tone: BrewTone.danger),
          ],
        ),
        gap(),
        const BrewSectionHeader(title: 'Cards'),
        BrewCard(
          onTap: () {},
          child: Text('Flat, tappable', style: context.brewType.titleSmall),
        ),
        gap(BrewSpacing.sm),
        const BrewCard(
          variant: BrewCardVariant.outlined,
          child: Text('Outlined'),
        ),
        gap(),
        const BrewSectionHeader(title: 'Fields'),
        const BrewTextField(label: 'Name', hint: 'Ada Lovelace'),
        gap(BrewSpacing.sm),
        const BrewTextField(label: 'Password', obscure: true),
        gap(BrewSpacing.sm),
        BrewApiKeyField(controller: TextEditingController(), keyHint: '1234'),
        gap(),
        const BrewSectionHeader(title: 'Loading'),
        if (animate)
          BrewShimmer.lines()
        else
          Container(height: 48, color: c.shimmerBase),
        gap(),
        const BrewSectionHeader(title: 'Auth'),
        BrewSignInButton(kind: BrewSignInKind.google, onPressed: () {}),
        gap(BrewSpacing.sm),
        const BrewDividerLabel('or'),
        gap(),
        BrewSettingsSection(
          title: 'Settings',
          footer: 'Credentials are shared across your Brew apps.',
          children: [
            BrewThemeModeTile(value: ThemeMode.system, onChanged: (_) {}),
            BrewCredentialTile(
              title: 'Anthropic',
              icon: Icons.auto_awesome_outlined,
              keyHint: '9f2a',
              onSave: (_) async {},
              onTest: () async {},
            ),
            BrewSettingsTile(
              title: 'Notifications',
              icon: Icons.notifications_none_rounded,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(
          height: 260,
          child: BrewEmptyState(
            title: 'No stories yet',
            message: 'Add a feed and they’ll show up here.',
            compact: true,
          ),
        ),
        SizedBox(
          height: 260,
          child: BrewErrorState(
            error: Exception('failed host lookup: abc.supabase.co'),
            onRetry: () {},
            compact: true,
          ),
        ),
      ],
    );
  }
}
