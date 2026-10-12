import 'package:flutter/widgets.dart';

import 'auth_phase.dart';
import 'brew_auth.dart';

/// Shows [signedIn] or [signedOut] depending on [auth], for apps without a
/// URL router (WealthBrew, BrewHire). Router apps use `brewAuthRedirect`.
///
/// Unstyled on purpose: [unknown] defaults to an empty box because what a
/// "restoring your session" moment looks like belongs to the app.
class BrewAuthGate extends StatelessWidget {
  const BrewAuthGate({
    super.key,
    required this.auth,
    required this.signedIn,
    required this.signedOut,
    this.unknown,
  });

  final BrewAuth auth;
  final WidgetBuilder signedIn;
  final WidgetBuilder signedOut;
  final WidgetBuilder? unknown;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: auth,
    builder: (context, _) => switch (auth.phase) {
      AuthPhase.signedIn => signedIn(context),
      AuthPhase.signedOut => signedOut(context),
      AuthPhase.unknown => unknown?.call(context) ?? const SizedBox.shrink(),
    },
  );
}
