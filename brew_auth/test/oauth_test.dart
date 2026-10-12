import 'dart:async';
import 'dart:convert';

import 'package:brew_auth/src/oauth/loopback.dart';
import 'package:brew_auth/src/oauth/pkce.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Pkce', () {
    test('matches the RFC 7636 appendix B vector', () {
      expect(
        Pkce.challengeFor('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('generates unpadded url-safe values', () {
      final p = Pkce.generate();
      expect(p.verifier, matches(RegExp(r'^[A-Za-z0-9_-]{43,128}$')));
      expect(p.challenge, Pkce.challengeFor(p.verifier));
    });
  });

  test('authorizeUrl keeps any base path and sends S256', () {
    final p = Pkce.generate();
    final url = authorizeUrl(
      supabaseUrl: 'https://example.com/supabase/',
      provider: OAuthProvider.github,
      redirectTo: 'http://localhost:1234',
      pkce: p,
    );
    expect(url.path, '/supabase/auth/v1/authorize');
    expect(url.queryParameters, {
      'provider': 'github',
      'code_challenge': p.challenge,
      'code_challenge_method': 'S256',
      'redirect_to': 'http://localhost:1234',
    });
  });

  group('exchangePkceCode', () {
    test('attaches the current session so GoTrue links identities', () async {
      late http.Request seen;
      final refresh = await exchangePkceCode(
        client: MockClient((req) async {
          seen = req;
          return http.Response(jsonEncode({'refresh_token': 'r2'}), 200);
        }),
        supabaseUrl: 'https://abc.supabase.co',
        anonKey: 'anon',
        code: 'the-code',
        verifier: 'the-verifier',
        currentAccessToken: 'anon-session',
      );
      expect(refresh, 'r2');
      expect(seen.url.toString(), endsWith('/auth/v1/token?grant_type=pkce'));
      expect(seen.headers['Authorization'], 'Bearer anon-session');
      expect(seen.headers['apikey'], 'anon');
      expect(jsonDecode(seen.body), {
        'auth_code': 'the-code',
        'code_verifier': 'the-verifier',
      });
    });

    test('a non-200 is an AuthException', () {
      expect(
        exchangePkceCode(
          client: MockClient((_) async => http.Response('bad code', 400)),
          supabaseUrl: 'https://abc.supabase.co',
          anonKey: 'anon',
          code: 'c',
          verifier: 'v',
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('codeFromRedirect', () {
    test('code, provider error, or nothing', () {
      expect(codeFromRedirect(Uri.parse('x://cb?code=abc')), 'abc');
      expect(codeFromRedirect(Uri.parse('x://cb')), isNull);
      expect(
        () => codeFromRedirect(
          Uri.parse('x://cb?error=access_denied&error_description=Nope'),
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Nope'),
          ),
        ),
      );
    });
  });

  group('runLoopbackRedirect', () {
    /// Plays the browser: follows the redirect once it's handed out.
    Future<void> Function(String) browser(
      String query,
      Completer<String> page,
    ) => (redirectTo) async {
      unawaited(
        http
            .get(Uri.parse('$redirectTo/?$query'))
            .then((r) => page.complete(r.body)),
      );
    };

    test('returns what complete returns and tells the tab it worked', () async {
      final page = Completer<String>();
      final result = await runLoopbackRedirect<String>(
        launch: browser('code=abc', page),
        complete: (cb) async => cb.queryParameters['code']!,
        timeout: const Duration(seconds: 5),
        appName: 'BrewWire',
      );
      expect(result, 'abc');
      expect(await page.future, contains('Signed in to BrewWire'));
    });

    test('a failing complete is rethrown and the tab says so', () async {
      final page = Completer<String>();
      await expectLater(
        runLoopbackRedirect<String>(
          launch: browser('error=denied', page),
          complete: (_) async => throw const AuthException('denied'),
          timeout: const Duration(seconds: 5),
          appName: '<b>x</b>',
        ),
        throwsA(isA<AuthException>()),
      );
      final body = await page.future;
      expect(body, contains('failed'));
      expect(body, isNot(contains('<b>x</b>')), reason: 'appName is escaped');
    });

    test('times out when the browser never comes back', () {
      expect(
        runLoopbackRedirect<String>(
          launch: (_) async {},
          complete: (_) async => 'never',
          timeout: const Duration(milliseconds: 100),
          appName: 'x',
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
