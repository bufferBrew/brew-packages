import 'package:flutter/material.dart';

import '../theme/brew_theme.dart';
import '../tokens/brew_colors.dart';
import '../tokens/brew_layout.dart';
import '../widgets/brew_button.dart';
import '../widgets/brew_dialogs.dart';
import '../widgets/brew_fields.dart';
import '../widgets/brew_surfaces.dart';

/// A titled group of settings rows on one card, dividers between rows.
class BrewSettingsSection extends StatelessWidget {
  const BrewSettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.footer,
  });

  final String title;
  final List<Widget> children;

  /// Explanatory text under the card.
  final String? footer;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: BrewSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: BrewSpacing.xs,
            bottom: BrewSpacing.sm,
          ),
          child: Semantics(
            header: true,
            child: Text(title.toUpperCase(), style: context.brewType.caption),
          ),
        ),
        BrewCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(indent: BrewSpacing.lg),
                children[i],
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BrewSpacing.xs,
              BrewSpacing.sm,
              BrewSpacing.xs,
              0,
            ),
            child: Text(footer!, style: context.brewType.bodySmall),
          ),
      ],
    ),
  );
}

/// One settings row.
class BrewSettingsTile extends StatelessWidget {
  const BrewSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: icon == null ? null : Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing:
        trailing ??
        (onTap == null ? null : const Icon(Icons.chevron_right_rounded)),
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: BrewSpacing.lg),
  );
}

/// System / Light / Dark.
class BrewThemeModeTile extends StatelessWidget {
  const BrewThemeModeTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title = 'Appearance',
  });

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(BrewSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.brewType.titleSmall),
        const SizedBox(height: BrewSpacing.md),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined),
                label: Text('System'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Dark'),
              ),
            ],
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.single),
          ),
        ),
      ],
    ),
  );
}

/// Who's signed in, how to upgrade an anonymous session, and sign-out.
///
/// [linkActions] are the app's own buttons (`BrewSignInButton`s labelled
/// "Link Google", say), shown only while [isAnonymous].
class BrewAccountSection extends StatelessWidget {
  const BrewAccountSection({
    super.key,
    required this.accountLabel,
    required this.onSignOut,
    this.isAnonymous = false,
    this.linkActions = const [],
    this.title = 'Account',
  });

  /// Name or email; null when anonymous.
  final String? accountLabel;
  final bool isAnonymous;
  final Future<void> Function() onSignOut;
  final List<Widget> linkActions;
  final String title;

  @override
  Widget build(BuildContext context) {
    final type = context.brewType;
    return BrewSettingsSection(
      title: title,
      children: [
        Padding(
          padding: const EdgeInsets.all(BrewSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isAnonymous
                    ? 'You’re using the app without an account'
                    : 'Signed in as ${accountLabel ?? 'you'}',
                style: type.titleSmall,
              ),
              if (isAnonymous) ...[
                const SizedBox(height: BrewSpacing.xs),
                Text(
                  'Sign in to keep your data if you switch devices.',
                  style: type.bodySmall,
                ),
                for (final action in linkActions) ...[
                  const SizedBox(height: BrewSpacing.md),
                  action,
                ],
              ],
            ],
          ),
        ),
        if (!isAnonymous)
          BrewSettingsTile(
            title: 'Sign out',
            icon: Icons.logout_rounded,
            onTap: () async {
              final ok = await showBrewConfirmDialog(
                context,
                title: 'Sign out?',
                confirmLabel: 'Sign out',
              );
              if (ok) await onSignOut();
            },
          ),
      ],
    );
  }
}

/// One credential (an LLM key, a connector token), collapsed to a row and
/// expanding to its form.
///
/// Follows the shape brew_core's README asks for: the saved key is only ever
/// a masked hint, Test sits next to Save, and the row says the credential is
/// shared across Brew apps, because it is.
class BrewCredentialTile extends StatefulWidget {
  const BrewCredentialTile({
    super.key,
    required this.title,
    required this.onSave,
    this.subtitle,
    this.icon,
    this.keyHint,
    this.onTest,
    this.onRemove,
    this.sharedNote = 'Shared across all your Brew apps.',
    this.initiallyExpanded = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Last characters of the saved key; null when nothing is saved.
  final String? keyHint;
  final Future<void> Function(String key) onSave;

  /// Tests the saved key. Throw to report failure.
  final Future<void> Function()? onTest;
  final Future<void> Function()? onRemove;
  final String? sharedNote;
  final bool initiallyExpanded;

  @override
  State<BrewCredentialTile> createState() => _BrewCredentialTileState();
}

class _BrewCredentialTileState extends State<BrewCredentialTile> {
  late bool _open = widget.initiallyExpanded;
  final _key = TextEditingController();
  String? _busy;
  String? _message;
  BrewTone _tone = BrewTone.neutral;

  bool get _saved => widget.keyHint != null && widget.keyHint!.isNotEmpty;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _run(
    String what,
    Future<void> Function() action,
    String done,
  ) async {
    setState(() {
      _busy = what;
      _message = null;
    });
    try {
      await action();
      if (mounted) {
        setState(() {
          _message = done;
          _tone = BrewTone.success;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = '$e';
          _tone = BrewTone.danger;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brewColors;
    final type = context.brewType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: widget.icon == null ? null : Icon(widget.icon),
          title: Text(widget.title),
          subtitle: Text(
            _saved
                ? 'Saved ••••${widget.keyHint}'
                : widget.subtitle ?? 'Not set',
          ),
          trailing: AnimatedRotation(
            turns: _open ? 0.5 : 0,
            duration: BrewMotion.of(context, BrewMotion.fast),
            child: const Icon(Icons.expand_more_rounded),
          ),
          onTap: () => setState(() => _open = !_open),
        ),
        AnimatedSize(
          duration: BrewMotion.of(context, BrewMotion.medium),
          curve: BrewMotion.emphasised,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BrewSpacing.lg,
                    0,
                    BrewSpacing.lg,
                    BrewSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BrewApiKeyField(
                        controller: _key,
                        keyHint: widget.keyHint,
                        enabled: _busy == null,
                      ),
                      if (widget.sharedNote != null) ...[
                        const SizedBox(height: BrewSpacing.sm),
                        Text(widget.sharedNote!, style: type.bodySmall),
                      ],
                      if (_message != null) ...[
                        const SizedBox(height: BrewSpacing.sm),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _message!,
                            style: type.bodySmall.copyWith(
                              color: c.toneText(_tone),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: BrewSpacing.md),
                      Wrap(
                        spacing: BrewSpacing.sm,
                        runSpacing: BrewSpacing.sm,
                        alignment: WrapAlignment.end,
                        children: [
                          if (_saved && widget.onRemove != null)
                            BrewButton(
                              label: 'Remove',
                              variant: BrewButtonVariant.ghost,
                              size: BrewButtonSize.sm,
                              loading: _busy == 'remove',
                              onPressed: _busy != null
                                  ? null
                                  : () async {
                                      final ok = await showBrewConfirmDialog(
                                        context,
                                        title: 'Remove ${widget.title}?',
                                        message: widget.sharedNote == null
                                            ? null
                                            : 'This removes it from every '
                                                  'Brew app.',
                                        confirmLabel: 'Remove',
                                        destructive: true,
                                      );
                                      if (ok) {
                                        await _run(
                                          'remove',
                                          widget.onRemove!,
                                          'Removed',
                                        );
                                      }
                                    },
                            ),
                          if (_saved && widget.onTest != null)
                            BrewButton(
                              label: 'Test',
                              variant: BrewButtonVariant.secondary,
                              size: BrewButtonSize.sm,
                              loading: _busy == 'test',
                              onPressed: _busy != null
                                  ? null
                                  : () => _run('test', widget.onTest!, 'Works'),
                            ),
                          BrewButton(
                            label: 'Save',
                            size: BrewButtonSize.sm,
                            loading: _busy == 'save',
                            onPressed: _busy != null
                                ? null
                                : () {
                                    final key = _key.text.trim();
                                    if (key.isEmpty) {
                                      setState(() {
                                        _message = 'Paste a key first';
                                        _tone = BrewTone.warning;
                                      });
                                      return;
                                    }
                                    _run('save', () async {
                                      await widget.onSave(key);
                                      _key.clear();
                                    }, 'Saved');
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
