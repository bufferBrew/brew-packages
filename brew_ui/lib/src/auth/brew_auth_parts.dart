import 'package:flutter/material.dart';

import '../theme/brew_theme.dart';
import '../tokens/brew_layout.dart';
import '../widgets/brew_button.dart';
import '../widgets/brew_fields.dart';

/// The ways a login screen can offer to sign in. brew_ui doesn't depend on
/// Supabase; map these to `OAuthProvider` in the app.
enum BrewSignInKind {
  google('Continue with Google', Icons.g_mobiledata_rounded),
  github('Continue with GitHub', Icons.code_rounded),
  apple('Continue with Apple', Icons.apple),
  email('Continue with email', Icons.mail_outline_rounded),
  anonymous('Continue without an account', Icons.person_outline_rounded);

  const BrewSignInKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// One "Continue with …" button.
class BrewSignInButton extends StatelessWidget {
  const BrewSignInButton({
    super.key,
    required this.kind,
    required this.onPressed,
    this.loading = false,
    this.label,
    this.leading,
    this.variant = BrewButtonVariant.secondary,
  });

  final BrewSignInKind kind;
  final VoidCallback? onPressed;
  final bool loading;

  /// Overrides the default label, e.g. "Link Google" in settings.
  final String? label;

  /// The provider's own mark, replacing the generic icon.
  final Widget? leading;

  /// Secondary by default; an app whose main way in is this provider (BREW
  /// with Google) makes it primary.
  final BrewButtonVariant variant;

  @override
  Widget build(BuildContext context) => BrewButton(
    label: label ?? kind.label,
    icon: kind.icon,
    leading: leading,
    onPressed: onPressed,
    loading: loading,
    fullWidth: true,
    size: BrewButtonSize.lg,
    variant: variant,
  );
}

/// The frame of a login screen: a centred, width-capped card with the app's
/// mark, a title, and whatever sign-in parts the app puts in [children].
class BrewAuthCard extends StatelessWidget {
  const BrewAuthCard({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.logo,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final Widget? logo;
  final List<Widget> children;

  /// Small print under the card: terms, a self-hosting note, a version.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final type = context.brewType;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BrewSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (logo != null) ...[
                Center(child: logo),
                const SizedBox(height: BrewSpacing.xl),
              ],
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: type.headline,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: BrewSpacing.sm),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: type.bodySmall,
                ),
              ],
              const SizedBox(height: BrewSpacing.xl),
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: BrewSpacing.md),
                children[i],
              ],
              if (footer != null) ...[
                const SizedBox(height: BrewSpacing.xl),
                DefaultTextStyle.merge(
                  style: type.bodySmall,
                  textAlign: TextAlign.center,
                  child: footer!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A rule with a word in it: "or".
class BrewDividerLabel extends StatelessWidget {
  const BrewDividerLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: BrewSpacing.md),
        child: Text(label, style: context.brewType.caption),
      ),
      const Expanded(child: Divider()),
    ],
  );
}

/// Email + password sign-in, with an optional switch to sign-up.
///
/// [onSubmit] does the work. Throw to show the error under the form (via
/// [describeError]); return a message to show it as a notice instead, e.g.
/// "Check your inbox to confirm your email".
class BrewEmailPasswordForm extends StatefulWidget {
  const BrewEmailPasswordForm({
    super.key,
    required this.onSubmit,
    this.allowSignUp = true,
    this.startInSignUp = false,
    this.describeError,
    this.minPasswordLength = 8,
    this.submitVariant = BrewButtonVariant.primary,
  });

  final Future<String?> Function(String email, String password, bool signUp)
  onSubmit;
  final bool allowSignUp;
  final bool startInSignUp;

  /// Turns a thrown error into a sentence. Defaults to its `message` if it
  /// has one, else `toString()`.
  final String Function(Object error)? describeError;
  final int minPasswordLength;

  /// Primary by default. When an OAuth button above is the main way in, make
  /// this secondary so the screen keeps one primary action.
  final BrewButtonVariant submitVariant;

  @override
  State<BrewEmailPasswordForm> createState() => _BrewEmailPasswordFormState();
}

class _BrewEmailPasswordFormState extends State<BrewEmailPasswordForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late bool _signUp = widget.startInSignUp;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _describe(Object e) {
    if (widget.describeError != null) return widget.describeError!(e);
    try {
      final message = (e as dynamic).message;
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {}
    return '$e';
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final notice = await widget.onSubmit(
        _email.text.trim(),
        _password.text,
        _signUp,
      );
      if (mounted) setState(() => _notice = notice);
    } catch (e) {
      if (mounted) setState(() => _error = _describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brewColors;
    final type = context.brewType;
    return AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            BrewTextField(
              controller: _email,
              label: 'Email',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              enabled: !_busy,
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'Enter your email';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
                  return 'That doesn’t look like an email address';
                }
                return null;
              },
            ),
            const SizedBox(height: BrewSpacing.md),
            BrewTextField(
              controller: _password,
              label: 'Password',
              prefixIcon: Icons.lock_outline_rounded,
              obscure: true,
              enabled: !_busy,
              textInputAction: TextInputAction.done,
              autofillHints: [
                _signUp ? AutofillHints.newPassword : AutofillHints.password,
              ],
              onSubmitted: (_) => _submit(),
              validator: (v) {
                final s = v ?? '';
                if (s.isEmpty) return 'Enter your password';
                if (_signUp && s.length < widget.minPasswordLength) {
                  return 'Use at least ${widget.minPasswordLength} characters';
                }
                return null;
              },
            ),
            if (_error != null || _notice != null) ...[
              const SizedBox(height: BrewSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error ?? _notice!,
                  style: type.bodySmall.copyWith(
                    color: _error != null ? c.dangerText : c.successText,
                  ),
                ),
              ),
            ],
            const SizedBox(height: BrewSpacing.lg),
            BrewButton(
              label: _signUp ? 'Create account' : 'Sign in',
              variant: widget.submitVariant,
              onPressed: _submit,
              loading: _busy,
              fullWidth: true,
              size: BrewButtonSize.lg,
            ),
            if (widget.allowSignUp) ...[
              const SizedBox(height: BrewSpacing.sm),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _signUp = !_signUp;
                        _error = null;
                        _notice = null;
                      }),
                child: Text(
                  _signUp
                      ? 'Have an account? Sign in'
                      : 'New here? Create an account',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// First-run form for a prebuilt release: which Supabase backend to use.
///
/// Pair with brew_core: `validate: BrewConfig.validate`, and save through
/// `SharedPrefsConfigStore` in [onSubmit].
class BrewBackendSetupForm extends StatefulWidget {
  const BrewBackendSetupForm({
    super.key,
    required this.onSubmit,
    this.validate,
    this.initialUrl = '',
  });

  final Future<void> Function(String url, String anonKey) onSubmit;

  /// Returns a message when the pair is unusable, else null.
  final String? Function(String url, String anonKey)? validate;
  final String initialUrl;

  @override
  State<BrewBackendSetupForm> createState() => _BrewBackendSetupFormState();
}

class _BrewBackendSetupFormState extends State<BrewBackendSetupForm> {
  late final _url = TextEditingController(text: widget.initialUrl);
  final _key = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final url = _url.text.trim();
    final key = _key.text.trim();
    final problem = widget.validate?.call(url, key);
    if (problem != null) return setState(() => _error = problem);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(url, key);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      BrewTextField(
        controller: _url,
        label: 'Supabase URL',
        hint: 'https://<project>.supabase.co',
        prefixIcon: Icons.dns_outlined,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.next,
        enabled: !_busy,
      ),
      const SizedBox(height: BrewSpacing.md),
      BrewTextField(
        controller: _key,
        label: 'Anon (publishable) key',
        helper:
            'Project Settings → API. It’s public; never paste the '
            'service-role key here.',
        prefixIcon: Icons.key_outlined,
        obscure: true,
        enabled: !_busy,
        onSubmitted: (_) => _submit(),
        errorText: _error,
      ),
      const SizedBox(height: BrewSpacing.lg),
      BrewButton(
        label: 'Connect',
        onPressed: _submit,
        loading: _busy,
        fullWidth: true,
        size: BrewButtonSize.lg,
      ),
    ],
  );
}
