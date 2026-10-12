# brew_auth

Sign-in for Brew apps. One `BrewAuth` per app, configured with the methods the
app offers; it runs the right OAuth flow on each platform and tells the router
whether to show the login screen.

**Logic only.** Login and settings screens stay in each app, composed from
`brew_ui` parts, so apps look related rather than identical. `BrewAuthGate` is
the one widget here, and it's unstyled.

It replaces five copies of the same code (BREW, BrewWire, brewfeed, NeuroBrew,
WealthBrew), taking the best of each:

| From | What |
|---|---|
| NeuroBrew | `AuthPhase` (with a real `unknown`), the `?from=` redirect, the pending-location trick for web |
| BrewWire | anonymous-first, and the Android PKCE exchange that upgrades an anonymous user instead of replacing them |
| BREW | desktop loopback sign-in, and email/password |

## Wiring an app up

```yaml
dependencies:
  brew_auth:
    git:
      url: https://github.com/bufferBrew/brew-packages.git
      path: brew_auth
      ref: 9102a5b4101a92621e7005c2f20445a5d180d3df # v0.2.2
```

```dart
final config = await loadBrewConfig();              // brew_core
await BrewSupabase.init(
  config!,
  schema: 'brewwire',
  // Only needed for anonymous → real upgrades on Android/iOS
  // (supabase_flutter >= 2.17.1).
  authOptions: const FlutterAuthClientOptions(
    detectSessionInUriPredicate: BrewAuth.detectSessionInUri,
  ),
);

runApp(ProviderScope(
  overrides: [
    brewConfigProvider.overrideWithValue(config),
    brewAuthOptionsProvider.overrideWithValue(const BrewAuthOptions(
      anonymous: true,
      oauthProviders: [OAuthProvider.google, OAuthProvider.github],
      nativeRedirect: 'com.bufferbrew.brewwire://login-callback',
      appName: 'BrewWire',
    )),
  ],
  child: const App(),
));
```

Anonymous-first apps then call `ref.read(brewAuthProvider).ensureSession()`
once at start-up. If the project has anonymous sign-in off, the phase stays
`signedOut` and the app shows its login screen.

### Router apps (go_router)

```dart
final phase = ValueNotifier(ref.read(authPhaseProvider));
ref.listen(authPhaseProvider, (_, next) => phase.value = next);

GoRouter(
  refreshListenable: phase,
  redirect: (context, state) =>
      brewAuthRedirect(phase: phase.value, location: state.uri),
  ...
);
```

On web, call `savePendingLocation(from)` before starting OAuth, and on
`AuthPhase.signedIn` follow `safeReturnPath(await takePendingLocation())`,
because the round trip reloads the page and loses `?from=`.

### Apps without a router, or on `provider`

```dart
BrewAuthGate(
  auth: auth,
  signedIn: (_) => const HomeShell(),
  signedOut: (_) => const LoginScreen(),
)
```

`BrewAuth` is a `ChangeNotifier`, so `ChangeNotifierProvider.value(value: auth)`
works too.

## OAuth per platform

| Platform | Flow | Setup needed |
|---|---|---|
| Web | same-tab redirect to the current origin | origin in Supabase → Auth → Redirect URLs |
| Android / iOS | browser → `nativeRedirect` deep link, exchanged by the SDK | intent filter / URL type for the scheme, and the scheme in Redirect URLs |
| Android / iOS, anonymous user | same deep link, exchanged by `BrewAuth` with the anonymous session attached | plus `detectSessionInUriPredicate` above |
| macOS / Windows / Linux | browser → `http://localhost:<random port>` | none; Supabase allows localhost |

Self-hosters: Google and GitHub need their own OAuth client IDs configured in
Supabase. Email/password works with no extra setup.

## Not done yet

- Anonymous → real upgrade on **web and desktop** creates a new user rather
  than linking (the existing behaviour in BrewWire). Linking there needs
  GoTrue manual linking (`linkIdentity`) enabled on the project.
