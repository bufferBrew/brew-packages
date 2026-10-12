/// Whether auth has settled, and if so which way.
///
/// [unknown] is a real third state: on web, the page may have just come back
/// from OAuth with a code the SDK is still exchanging. Redirecting to login
/// during that would flash a sign-in wall at someone who is signing in.
///
/// An anonymous session counts as [signedIn]; check `BrewAuth.isAnonymous`
/// to tell it apart from a real account.
enum AuthPhase { unknown, signedIn, signedOut }

/// Where to go after sign-in: back to [from] if it's an in-app path, else
/// [home].
///
/// Only a path starting with a single `/` is accepted, so a crafted `from`
/// can't send anyone to another site, and the login page itself is never a
/// destination.
String safeReturnPath(
  String? from, {
  String home = '/',
  String login = '/login',
}) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return home;
  }
  if (Uri.tryParse(from)?.path == login) return home;
  return from;
}

/// The sign-in gate for a URL router, as a pure function.
///
/// Call it from go_router's `redirect` (or any router's equivalent):
///
/// ```dart
/// redirect: (context, state) =>
///     brewAuthRedirect(phase: phase.value, location: state.uri),
/// ```
///
/// - [AuthPhase.unknown]: stay put until auth settles.
/// - Signed out: go to [loginPath], carrying the requested location as
///   `?from=` so a link from another app (`/generate?topic=…`) still lands
///   where it pointed. [isPublic] paths are let through.
/// - Signed in on the login page: go back to `from`, or [homePath].
String? brewAuthRedirect({
  required AuthPhase phase,
  required Uri location,
  String loginPath = '/login',
  String homePath = '/',
  bool Function(Uri location)? isPublic,
}) {
  final atLogin = location.path == loginPath;
  switch (phase) {
    case AuthPhase.unknown:
      return null;
    case AuthPhase.signedOut:
      if (atLogin || (isPublic?.call(location) ?? false)) return null;
      return Uri(
        path: loginPath,
        queryParameters: location.path == homePath
            ? null
            : {'from': location.toString()},
      ).toString();
    case AuthPhase.signedIn:
      if (!atLogin) return null;
      return safeReturnPath(
        location.queryParameters['from'],
        home: homePath,
        login: loginPath,
      );
  }
}
