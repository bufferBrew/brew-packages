/// Sign-in for Brew apps.
///
/// One [BrewAuth] per app, configured with [BrewAuthOptions]: which methods
/// the app offers and where OAuth returns. It runs the right OAuth flow per
/// platform (web redirect, Android/iOS deep link, desktop loopback) and keeps
/// an anonymous user's data when they upgrade to a real account.
///
/// Logic only. Login and settings screens stay in each app, built from
/// brew_ui's parts, so apps look related rather than identical.
///
/// ```dart
/// final config = await loadBrewConfig();
/// await BrewSupabase.init(config!, schema: 'brewwire');
/// runApp(ProviderScope(overrides: [
///   brewConfigProvider.overrideWithValue(config),
///   brewAuthOptionsProvider.overrideWithValue(const BrewAuthOptions(
///     anonymous: true,
///     oauthProviders: [OAuthProvider.google, OAuthProvider.github],
///     nativeRedirect: 'com.bufferbrew.brewwire://login-callback',
///   )),
/// ], child: const App()));
/// ```
library;

export 'src/auth_gate.dart';
export 'src/auth_options.dart';
export 'src/auth_phase.dart';
export 'src/brew_auth.dart';
export 'src/pending_location.dart';
export 'src/riverpod.dart';
