import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:brew_core/brew_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_options.dart';
import 'auth_phase.dart';
import 'oauth/loopback.dart';
import 'oauth/pkce.dart';

/// Sign-in state and actions for one Brew app.
///
/// A plain [ChangeNotifier] so Riverpod apps (via `brewAuthProvider`) and
/// Provider apps (WealthBrew, BrewHire) can both use it.
///
/// How OAuth runs on each platform:
///
/// | Platform | Flow |
/// |---|---|
/// | Web | same-tab redirect; the SDK exchanges the code on return |
/// | Android/iOS | browser → [BrewAuthOptions.nativeRedirect] deep link; the SDK exchanges it, which survives Android killing the app meanwhile |
/// | Android/iOS, anonymous user | same deep link, but exchanged here with the anonymous session attached so the account is upgraded, not replaced |
/// | macOS/Windows/Linux | browser → `http://localhost:<port>` loopback, exchanged here |
///
/// Every Android/iOS launch goes through `launchUrl(platformDefault)`, not
/// `signInWithOAuth()`: the SDK forces `externalApplication`, which adds
/// `FLAG_ACTIVITY_REQUIRE_NON_BROWSER` and throws `ActivityNotFoundException`
/// for https URLs on Android 11+.
class BrewAuth extends ChangeNotifier {
  BrewAuth({
    required SupabaseClient client,
    required this.config,
    required this.options,
    @visibleForTesting TargetPlatform? platform,
    @visibleForTesting bool? isWeb,
    @visibleForTesting Uri? pageUrl,
    @visibleForTesting Future<bool> Function(Uri url)? launch,
    @visibleForTesting Stream<Uri> Function()? deepLinks,
    @visibleForTesting http.Client? httpClient,
  }) : _client = client,
       _platform = platform ?? defaultTargetPlatform,
       _isWeb = isWeb ?? kIsWeb,
       _launch = launch ?? _launchPlatformDefault,
       _deepLinks = deepLinks ?? (() => AppLinks().uriLinkStream),
       _http = httpClient ?? http.Client(),
       _ownsHttp = httpClient == null {
    _user = client.auth.currentUser;
    if (_user != null) {
      _phase = AuthPhase.signedIn;
    } else if (_isWeb && _isAuthCallback(pageUrl ?? Uri.base)) {
      // Back from OAuth with a code the SDK is still exchanging. Hold off on
      // the login redirect until it lands or clearly isn't going to.
      _phase = AuthPhase.unknown;
      _settleTimer = Timer(const Duration(seconds: 10), () {
        if (_phase == AuthPhase.unknown) _set(null);
      });
    } else {
      _phase = AuthPhase.signedOut;
    }
    _sub = client.auth.onAuthStateChange.listen(_onAuthState, onError: (_) {});
  }

  final SupabaseClient _client;

  /// The backend, for the OAuth flows exchanged here rather than by the SDK.
  final BrewConfig config;
  final BrewAuthOptions options;
  final TargetPlatform _platform;
  final bool _isWeb;
  final Future<bool> Function(Uri url) _launch;
  final Stream<Uri> Function() _deepLinks;
  final http.Client _http;
  final bool _ownsHttp;

  late final StreamSubscription<AuthState> _sub;
  Timer? _settleTimer;
  Completer<void>? _settled;
  late AuthPhase _phase;
  User? _user;

  AuthPhase get phase => _phase;
  User? get user => _user;
  bool get isAnonymous => _user?.isAnonymous ?? false;

  /// Signed in with a real identity, not anonymously. Gate "your account"
  /// UI and per-user data on this.
  bool get isRealUser => _user != null && !isAnonymous;

  /// Display name or email for an account row; null when anonymous.
  String? get accountLabel {
    final u = _user;
    if (u == null || u.isAnonymous) return null;
    final name = u.userMetadata?['full_name'];
    if (name is String && name.isNotEmpty) return name;
    return u.email;
  }

  bool get _isDesktop =>
      !_isWeb &&
      (_platform == TargetPlatform.macOS ||
          _platform == TargetPlatform.windows ||
          _platform == TargetPlatform.linux);

  void _onAuthState(AuthState state) {
    final user = state.session?.user;
    // While a web callback is being exchanged, a null session that isn't an
    // explicit sign-out is just "not yet".
    if (_phase == AuthPhase.unknown &&
        user == null &&
        state.event != AuthChangeEvent.signedOut) {
      return;
    }
    _set(user);
  }

  void _set(User? user) {
    _settleTimer?.cancel();
    final settled = _settled;
    _settled = null;
    if (settled != null && !settled.isCompleted) settled.complete();
    final phase = user == null ? AuthPhase.signedOut : AuthPhase.signedIn;
    if (identical(user, _user) && phase == _phase) return;
    _user = user;
    _phase = phase;
    notifyListeners();
  }

  /// Completes once [phase] is no longer [AuthPhase.unknown], e.g. after a
  /// web OAuth return has been exchanged (or given up on).
  Future<void> settled() {
    if (_phase != AuthPhase.unknown) return Future.value();
    return (_settled ??= Completer<void>()).future;
  }

  /// For anonymous-first apps: sign in anonymously if there's no session.
  ///
  /// Waits for a web OAuth return to settle first: signing in anonymously
  /// while the real session is still being exchanged would race it. While the
  /// anonymous sign-in runs, [phase] reads [AuthPhase.unknown], so the app
  /// doesn't flash its login screen.
  ///
  /// Returns quietly when the project has anonymous sign-in turned off; the
  /// phase becomes [AuthPhase.signedOut] and the app shows its login screen.
  Future<void> ensureSession() async {
    if (!options.anonymous) return;
    await settled();
    if (_user != null) return;
    _phase = AuthPhase.unknown;
    notifyListeners();
    try {
      final res = await _client.auth.signInAnonymously();
      _set(res.user ?? _client.auth.currentUser);
    } on AuthException catch (e) {
      _set(null);
      if (e.code == 'anonymous_provider_disabled') return;
      rethrow;
    } catch (_) {
      _set(null);
      rethrow;
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    assert(options.emailPassword, 'emailPassword is not enabled');
    final res = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    _set(res.user ?? _client.auth.currentUser);
  }

  /// Creates an account. With email confirmation on (the Supabase default)
  /// there is no session until the user clicks the link, so the phase stays
  /// signed out; check the result's `session` to tell the user to look in
  /// their inbox.
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    assert(options.emailPassword, 'emailPassword is not enabled');
    final res = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: _isWeb ? options.resolvedWebRedirect : null,
    );
    if (res.session != null) _set(res.user);
    return res;
  }

  /// Starts OAuth with [provider].
  ///
  /// On web and for the SDK-handled native flow this returns once the browser
  /// is open; the session arrives later on the auth stream, which is why
  /// routers key off [phase], never off this future. Desktop and the
  /// anonymous-upgrade flow complete here.
  Future<void> signInWithOAuth(OAuthProvider provider) async {
    assert(
      options.oauthProviders.contains(provider),
      '$provider is not in BrewAuthOptions.oauthProviders',
    );
    if (_isWeb) {
      await _client.auth.signInWithOAuth(
        provider,
        redirectTo: options.resolvedWebRedirect,
      );
      return;
    }
    if (_isDesktop) return _desktopLoopback(provider);
    if (options.nativeRedirect == null) {
      throw StateError(
        'OAuth on Android/iOS needs BrewAuthOptions.nativeRedirect '
        '(e.g. com.bufferbrew.<app>://login-callback)',
      );
    }
    if (isAnonymous) return _nativeUpgrade(provider);

    final res = await _client.auth.getOAuthSignInUrl(
      provider: provider,
      redirectTo: options.nativeRedirect,
    );
    await _open(Uri.parse(res.url));
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> _desktopLoopback(OAuthProvider provider) async {
    final pkce = Pkce.generate();
    final refresh = await runLoopbackRedirect<String>(
      appName: options.appName,
      timeout: options.oauthTimeout,
      launch: (redirectTo) => _open(
        authorizeUrl(
          supabaseUrl: config.supabaseUrl,
          provider: provider,
          redirectTo: redirectTo,
          pkce: pkce,
        ),
      ),
      complete: (callback) {
        final code = codeFromRedirect(callback);
        if (code == null) {
          throw const AuthException('Sign-in returned without a code');
        }
        return _exchange(code, pkce);
      },
    );
    await _adopt(refresh);
  }

  /// Anonymous → real account on Android/iOS. The SDK's own deep-link
  /// exchange has no hook to attach the anonymous session, so this one
  /// catches the redirect itself — see [detectSessionInUri].
  ///
  /// Only completes while the process stays alive. If Android kills the app
  /// while the user is in the browser, the upgrade silently doesn't happen;
  /// acceptable because it starts from a deliberate tap, not a login wall.
  Future<void> _nativeUpgrade(OAuthProvider provider) async {
    final redirect = options.nativeRedirect!;
    final pkce = Pkce.generate();
    final code = Completer<String>();
    final sub = _deepLinks().listen((uri) {
      if (code.isCompleted || !uri.toString().startsWith(redirect)) return;
      try {
        final c = codeFromRedirect(uri);
        if (c != null) code.complete(c);
      } catch (e) {
        code.completeError(e);
      }
    });
    _manualRedirect = redirect;
    try {
      await _open(
        authorizeUrl(
          supabaseUrl: config.supabaseUrl,
          provider: provider,
          redirectTo: redirect,
          pkce: pkce,
        ),
      );
      final c = await code.future.timeout(options.oauthTimeout);
      await _adopt(await _exchange(c, pkce));
    } finally {
      _manualRedirect = null;
      unawaited(sub.cancel());
    }
  }

  Future<String> _exchange(String code, Pkce pkce) => exchangePkceCode(
    client: _http,
    supabaseUrl: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
    code: code,
    verifier: pkce.verifier,
    currentAccessToken: _client.auth.currentSession?.accessToken,
  );

  Future<void> _adopt(String refreshToken) async {
    final res = await _client.auth.setSession(refreshToken);
    _set(res.user ?? _client.auth.currentUser);
  }

  Future<void> _open(Uri url) async {
    if (!await _launch(url)) {
      throw AuthException('Could not open the browser for $url');
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    unawaited(_sub.cancel());
    if (_ownsHttp) _http.close();
    super.dispose();
  }

  // ── SDK deep-link handling ────────────────────────────────────────────────

  static String? _manualRedirect;

  /// Pass as `FlutterAuthClientOptions.detectSessionInUriPredicate`
  /// (supabase_flutter ≥ 2.17.1) in apps whose Android/iOS users can upgrade
  /// from an anonymous session. It keeps the SDK off the redirect while
  /// [BrewAuth] is exchanging it itself, and otherwise matches the SDK's own
  /// heuristic.
  static bool detectSessionInUri(Uri uri) {
    final manual = _manualRedirect;
    if (manual != null && uri.toString().startsWith(manual)) return false;
    return _isAuthCallback(uri) ||
        _has(uri, 'error') ||
        _has(uri, 'error_code') ||
        _has(uri, 'error_description');
  }

  static bool _isAuthCallback(Uri uri) =>
      _has(uri, 'code') || _has(uri, 'access_token');

  static bool _has(Uri uri, String key) =>
      uri.queryParameters.containsKey(key) ||
      Uri.splitQueryString(uri.fragment).containsKey(key);
}

Future<bool> _launchPlatformDefault(Uri url) =>
    launchUrl(url, mode: LaunchMode.platformDefault);
