import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// A PKCE verifier/challenge pair (RFC 7636, S256).
class Pkce {
  Pkce._(this.verifier, this.challenge);

  factory Pkce.generate([Random? random]) {
    final r = random ?? Random.secure();
    final verifier = _b64(List<int>.generate(64, (_) => r.nextInt(256)));
    return Pkce._(verifier, challengeFor(verifier));
  }

  static String challengeFor(String verifier) =>
      _b64(sha256.convert(utf8.encode(verifier)).bytes);

  static String _b64(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  final String verifier;
  final String challenge;
}

/// The GoTrue `/authorize` URL for [provider], returning to [redirectTo].
///
/// Built by hand rather than with `getOAuthSignInUrl`, because that stores its
/// own verifier inside the SDK and exchanges the code itself, with no way to
/// attach the current session (see [exchangePkceCode]).
Uri authorizeUrl({
  required String supabaseUrl,
  required OAuthProvider provider,
  required String redirectTo,
  required Pkce pkce,
}) => Uri.parse('${_trimSlash(supabaseUrl)}/auth/v1/authorize').replace(
  queryParameters: {
    'provider': provider.name,
    'code_challenge': pkce.challenge,
    'code_challenge_method': 'S256',
    'redirect_to': redirectTo,
  },
);

/// Exchanges an OAuth [code] for tokens and returns the refresh token.
///
/// When [currentAccessToken] is given, GoTrue links the new identity to that
/// user instead of creating a second one. That is what keeps an anonymous
/// user's data (BrewWire's API keys, topic subscriptions…) when they upgrade
/// to Google or GitHub.
Future<String> exchangePkceCode({
  required http.Client client,
  required String supabaseUrl,
  required String anonKey,
  required String code,
  required String verifier,
  String? currentAccessToken,
}) async {
  final res = await client.post(
    Uri.parse('${_trimSlash(supabaseUrl)}/auth/v1/token?grant_type=pkce'),
    headers: {
      'apikey': anonKey,
      'Content-Type': 'application/json',
      if (currentAccessToken != null)
        'Authorization': 'Bearer $currentAccessToken',
    },
    body: jsonEncode({'auth_code': code, 'code_verifier': verifier}),
  );
  if (res.statusCode != 200) {
    throw AuthException(
      'Sign-in failed (${res.statusCode}): ${res.body}',
      statusCode: '${res.statusCode}',
    );
  }
  final refresh =
      (jsonDecode(res.body) as Map<String, dynamic>)['refresh_token'];
  if (refresh is! String) {
    throw const AuthException('Sign-in response had no refresh token');
  }
  return refresh;
}

/// The `code` from an OAuth redirect, or throws the provider's error.
/// Returns null if the URI carries neither.
String? codeFromRedirect(Uri uri) {
  final code = uri.queryParameters['code'];
  if (code != null) return code;
  final error =
      uri.queryParameters['error_description'] ?? uri.queryParameters['error'];
  if (error != null) {
    throw AuthException('Sign-in was cancelled or failed: $error');
  }
  return null;
}

String _trimSlash(String s) =>
    s.endsWith('/') ? s.substring(0, s.length - 1) : s;
