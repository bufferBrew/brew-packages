import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Which sign-in methods an app offers, and where OAuth sends users back.
///
/// Each app declares its own: BREW and WealthBrew use email + Google,
/// BrewWire and brewfeed are anonymous-first with Google/GitHub to upgrade,
/// NeuroBrew is Google-only. A login screen renders exactly what's listed here.
@immutable
class BrewAuthOptions {
  const BrewAuthOptions({
    this.emailPassword = false,
    this.oauthProviders = const [],
    this.anonymous = false,
    this.nativeRedirect,
    this.webRedirect,
    this.appName = 'Brew',
    this.oauthTimeout = const Duration(minutes: 5),
  });

  /// Email + password sign-in and sign-up.
  final bool emailPassword;

  /// OAuth providers the login screen offers, in button order, e.g.
  /// `[OAuthProvider.google]`. A list rather than a set: `OAuthProvider`
  /// overrides `==`, which rules out const sets, and order matters on screen.
  final List<OAuthProvider> oauthProviders;

  /// Sign in anonymously when there is no session, so the app works before
  /// the user makes an account. If the project has anonymous sign-in turned
  /// off, the app falls back to its login screen.
  final bool anonymous;

  /// Custom-scheme deep link OAuth returns to on Android and iOS, e.g.
  /// `com.bufferbrew.brewwire://login-callback`.
  ///
  /// Must match three things or the round trip dead-ends after the account
  /// picker: the intent filter in `AndroidManifest.xml` (and the URL type in
  /// iOS `Info.plist`), the Supabase redirect allowlist, and this value.
  final String? nativeRedirect;

  /// Where OAuth returns to on web. Defaults to the origin currently being
  /// served, read at call time: localhost, preview URLs and production are
  /// different origins, and a compiled-in value would send two of them to the
  /// third.
  ///
  /// Never null on web. GoTrue would fall back to the project's Site URL,
  /// which the shared Supabase project sets to BREW, so sign-in would succeed
  /// and land on the wrong app.
  final String Function()? webRedirect;

  /// Shown on the page the desktop browser tab lands on after sign-in.
  final String appName;

  /// How long to wait for the user to finish in the browser.
  final Duration oauthTimeout;

  String get resolvedWebRedirect => webRedirect?.call() ?? Uri.base.origin;
}
