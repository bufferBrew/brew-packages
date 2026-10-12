import 'package:brew_core/brew_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_options.dart';
import 'auth_phase.dart';
import 'brew_auth.dart';

/// This app's sign-in methods. Override in the root `ProviderScope`.
final brewAuthOptionsProvider = Provider<BrewAuthOptions>(
  (ref) => throw UnimplementedError(
    'Override brewAuthOptionsProvider in the root ProviderScope',
  ),
);

/// The app's [BrewAuth], built from [brewClientProvider],
/// [brewConfigProvider] and [brewAuthOptionsProvider].
final brewAuthProvider = Provider<BrewAuth>((ref) {
  final auth = BrewAuth(
    client: ref.watch(brewClientProvider),
    config: ref.watch(brewConfigProvider),
    options: ref.watch(brewAuthOptionsProvider),
  );
  ref.onDispose(auth.dispose);
  return auth;
});

/// Rebuilds whenever [BrewAuth] notifies.
Provider<T> _fromAuth<T>(T Function(BrewAuth auth) read) => Provider<T>((ref) {
  final auth = ref.watch(brewAuthProvider);
  void changed() => ref.invalidateSelf();
  auth.addListener(changed);
  ref.onDispose(() => auth.removeListener(changed));
  return read(auth);
});

/// What a router's redirect keys off. A plain enum, so a widget test can
/// override it without a live Supabase client.
final authPhaseProvider = _fromAuth<AuthPhase>((a) => a.phase);

final brewUserProvider = _fromAuth<User?>((a) => a.user);

/// Signed in with a real identity, not anonymously.
final isRealUserProvider = _fromAuth<bool>((a) => a.isRealUser);

/// Display name or email for an account row; null when signed out or
/// anonymous.
final accountLabelProvider = _fromAuth<String?>((a) => a.accountLabel);
