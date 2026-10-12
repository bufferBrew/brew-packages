import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:brew_auth/brew_auth.dart';
import 'package:brew_auth/src/oauth/pkce.dart';
import 'package:brew_core/brew_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_gotrue.dart';

const _native = 'com.bufferbrew.test://login-callback';

const _anonFirst = BrewAuthOptions(
  anonymous: true,
  oauthProviders: [OAuthProvider.google, OAuthProvider.github],
  nativeRedirect: _native,
);

const _emailAndGoogle = BrewAuthOptions(
  emailPassword: true,
  oauthProviders: [OAuthProvider.google],
  nativeRedirect: _native,
);

void main() {
  late FakeGoTrue gotrue;
  late List<Uri> launched;
  late StreamController<Uri> links;

  setUp(() {
    gotrue = FakeGoTrue();
    launched = [];
    links = StreamController<Uri>.broadcast();
  });
  tearDown(() => links.close());

  BrewAuth make(
    BrewAuthOptions options, {
    TargetPlatform platform = TargetPlatform.android,
    bool isWeb = false,
    Uri? pageUrl,
    Future<bool> Function(Uri)? launch,
  }) {
    final auth = BrewAuth(
      client: gotrue.client(),
      config: config,
      options: options,
      platform: platform,
      isWeb: isWeb,
      pageUrl: pageUrl ?? Uri.parse('https://app.example.com/'),
      launch:
          launch ??
          (url) async {
            launched.add(url);
            return true;
          },
      deepLinks: () => links.stream,
      httpClient: gotrue.http_,
    );
    addTearDown(auth.dispose);
    return auth;
  }

  group('anonymous-first', () {
    test('ensureSession signs in anonymously and notifies', () async {
      gotrue.answer(
        'POST /auth/v1/signup',
        sessionJson(id: 'anon-1', anonymous: true),
      );
      final auth = make(_anonFirst);
      var notified = 0;
      auth.addListener(() => notified++);

      expect(auth.phase, AuthPhase.signedOut);
      await auth.ensureSession();

      expect(auth.phase, AuthPhase.signedIn);
      expect(auth.isAnonymous, isTrue);
      expect(auth.isRealUser, isFalse);
      expect(auth.accountLabel, isNull);
      expect(notified, greaterThan(0));
    });

    test('falls back to the login screen when anonymous is disabled', () async {
      gotrue.answer('POST /auth/v1/signup', {
        'error_code': 'anonymous_provider_disabled',
        'msg': 'Anonymous sign-ins are disabled',
      }, status: 422);
      final auth = make(_anonFirst);

      await auth.ensureSession();
      expect(auth.phase, AuthPhase.signedOut);
    });

    test('is a no-op for apps that do not opt in', () async {
      final auth = make(_emailAndGoogle);
      await auth.ensureSession();
      expect(gotrue.requests, isEmpty);
    });

    test(
      'Android upgrade links the anonymous session to the new identity',
      () async {
        final anon = sessionJson(id: 'anon-1', anonymous: true);
        gotrue.answer('POST /auth/v1/signup', anon);
        gotrue.routes['POST /auth/v1/token?pkce'] = (req) {
          // The anonymous session rides along, so GoTrue links, not replaces.
          expect(
            req.headers['Authorization'],
            'Bearer ${anon['access_token']}',
          );
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['auth_code'], 'the-code');
          expect(
            Pkce.challengeFor(body['code_verifier'] as String),
            launched.single.queryParameters['code_challenge'],
          );
          return FakeGoTrue.json({'refresh_token': 'r-google'}, 200, req);
        };
        gotrue.routes['POST /auth/v1/token?refresh_token'] = (req) {
          expect(jsonDecode(req.body), {'refresh_token': 'r-google'});
          return FakeGoTrue.json(
            sessionJson(id: 'anon-1', email: 'kj@example.com'),
            200,
            req,
          );
        };

        final auth = make(_anonFirst);
        await auth.ensureSession();

        final done = auth.signInWithOAuth(OAuthProvider.google);
        await pumpEventQueue();
        expect(launched.single.path, '/auth/v1/authorize');
        expect(launched.single.queryParameters['redirect_to'], _native);
        // The SDK must leave this redirect alone while BrewAuth owns it.
        expect(
          BrewAuth.detectSessionInUri(Uri.parse('$_native?code=the-code')),
          isFalse,
        );

        links.add(Uri.parse('com.other.app://x?code=not-ours'));
        links.add(Uri.parse('$_native?code=the-code'));
        await done;

        expect(auth.isRealUser, isTrue);
        expect(auth.user?.id, 'anon-1', reason: 'same user, now with Google');
        expect(auth.accountLabel, 'kj@example.com');
        expect(
          BrewAuth.detectSessionInUri(Uri.parse('$_native?code=later')),
          isTrue,
          reason: 'released once the upgrade finishes',
        );
      },
    );

    test('a cancelled upgrade surfaces the provider error', () async {
      gotrue.answer(
        'POST /auth/v1/signup',
        sessionJson(id: 'anon-1', anonymous: true),
      );
      final auth = make(_anonFirst);
      await auth.ensureSession();

      final done = auth.signInWithOAuth(OAuthProvider.github);
      await pumpEventQueue();
      links.add(Uri.parse('$_native?error=access_denied'));

      await expectLater(done, throwsA(isA<AuthException>()));
      expect(auth.isAnonymous, isTrue);
    });
  });

  group('email and password', () {
    test('signs in and labels the account', () async {
      gotrue.answer(
        'POST /auth/v1/token?password',
        sessionJson(id: 'u1', email: 'kj@example.com', fullName: 'KJ'),
      );
      final auth = make(_emailAndGoogle);

      await auth.signInWithEmail(' kj@example.com ', 'pw');

      expect(auth.phase, AuthPhase.signedIn);
      expect(auth.isRealUser, isTrue);
      expect(auth.accountLabel, 'KJ');
      final body = jsonDecode(gotrue.requests.single.body) as Map;
      expect(body['email'], 'kj@example.com', reason: 'trimmed');
    });

    test('wrong password is an AuthException and stays signed out', () async {
      gotrue.answer('POST /auth/v1/token?password', {
        'error_code': 'invalid_credentials',
        'msg': 'Invalid login credentials',
      }, status: 400);
      final auth = make(_emailAndGoogle);

      await expectLater(
        auth.signInWithEmail('kj@example.com', 'nope'),
        throwsA(isA<AuthException>()),
      );
      expect(auth.phase, AuthPhase.signedOut);
    });

    test('sign-up awaiting email confirmation stays signed out', () async {
      gotrue.answer('POST /auth/v1/signup', {
        'id': 'u2',
        'aud': 'authenticated',
        'role': '',
        'email': 'new@example.com',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-01-01T00:00:00Z',
      });
      final auth = make(_emailAndGoogle);

      final res = await auth.signUpWithEmail('new@example.com', 'pw123456');
      expect(res.session, isNull);
      expect(auth.phase, AuthPhase.signedOut);
    });

    test('sign out returns to signed out', () async {
      gotrue.answer(
        'POST /auth/v1/token?password',
        sessionJson(id: 'u1', email: 'kj@example.com'),
      );
      gotrue.routes['POST /auth/v1/logout'] = (req) =>
          http.Response('', 204, request: req);
      final auth = make(_emailAndGoogle);
      await auth.signInWithEmail('kj@example.com', 'pw');

      await auth.signOut();
      await pumpEventQueue();
      expect(auth.phase, AuthPhase.signedOut);
    });
  });

  group('OAuth routing per platform', () {
    test('Android, real user: SDK flow to the deep link', () async {
      final auth = make(_emailAndGoogle);
      await auth.signInWithOAuth(OAuthProvider.google);

      final url = launched.single;
      expect(url.path, '/auth/v1/authorize');
      expect(url.queryParameters['provider'], 'google');
      expect(url.queryParameters['redirect_to'], _native);
    });

    test('desktop: loopback redirect, exchanged here', () async {
      gotrue.answer('POST /auth/v1/token?pkce', {'refresh_token': 'r-desk'});
      gotrue.answer(
        'POST /auth/v1/token?refresh_token',
        sessionJson(id: 'u9', email: 'desk@example.com'),
      );
      final auth = make(
        _emailAndGoogle,
        platform: TargetPlatform.macOS,
        launch: (url) async {
          launched.add(url);
          // The browser coming back to the loopback server.
          final back = url.queryParameters['redirect_to']!;
          expect(back, startsWith('http://localhost:'));
          // Real HTTP: the widget-test binding otherwise fakes HttpClient.
          unawaited(
            HttpOverrides.runWithHttpOverrides(
              () => http.get(Uri.parse('$back/?code=desk-code')),
              _RealHttp(),
            ),
          );
          return true;
        },
      );

      await auth.signInWithOAuth(OAuthProvider.google);

      expect(auth.isRealUser, isTrue);
      expect(auth.accountLabel, 'desk@example.com');
    });

    test('a browser that will not open is an error', () {
      final auth = make(_emailAndGoogle, launch: (_) async => false);
      expect(
        auth.signInWithOAuth(OAuthProvider.google),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('web OAuth return', () {
    test('a code in the page URL holds the phase at unknown', () async {
      gotrue.answer(
        'POST /auth/v1/token?password',
        sessionJson(id: 'u1', email: 'kj@example.com'),
      );
      final auth = make(
        _emailAndGoogle,
        isWeb: true,
        pageUrl: Uri.parse('https://app.example.com/?code=abc'),
      );
      expect(auth.phase, AuthPhase.unknown);

      // Stands in for the SDK finishing its exchange.
      await auth.signInWithEmail('kj@example.com', 'pw');
      expect(auth.phase, AuthPhase.signedIn);
    });

    test('a plain page load is signed out straight away', () {
      final auth = make(_emailAndGoogle, isWeb: true);
      expect(auth.phase, AuthPhase.signedOut);
    });
  });

  test('native OAuth without a redirect is a clear error', () {
    final auth = make(
      const BrewAuthOptions(oauthProviders: [OAuthProvider.google]),
    );
    expect(
      auth.signInWithOAuth(OAuthProvider.google),
      throwsA(isA<StateError>()),
    );
  });

  test('detectSessionInUri matches the SDK heuristic otherwise', () {
    expect(BrewAuth.detectSessionInUri(Uri.parse('x://cb?code=1')), isTrue);
    expect(
      BrewAuth.detectSessionInUri(Uri.parse('https://a/#access_token=t')),
      isTrue,
    );
    expect(BrewAuth.detectSessionInUri(Uri.parse('x://cb?error=e')), isTrue);
    expect(
      BrewAuth.detectSessionInUri(Uri.parse('https://a/reader/1')),
      isFalse,
    );
  });

  group('Riverpod', () {
    test('authPhaseProvider follows sign-in', () async {
      gotrue.answer(
        'POST /auth/v1/token?password',
        sessionJson(id: 'u1', email: 'kj@example.com'),
      );
      final c = ProviderContainer(
        overrides: [
          brewClientProvider.overrideWithValue(gotrue.client()),
          brewConfigProvider.overrideWithValue(config),
          brewAuthOptionsProvider.overrideWithValue(_emailAndGoogle),
        ],
      );
      addTearDown(c.dispose);
      final phases = <AuthPhase>[];
      c.listen(
        authPhaseProvider,
        (_, p) => phases.add(p),
        fireImmediately: true,
      );

      await c.read(brewAuthProvider).signInWithEmail('kj@example.com', 'pw');
      await pumpEventQueue();

      expect(phases, [AuthPhase.signedOut, AuthPhase.signedIn]);
      expect(c.read(isRealUserProvider), isTrue);
      expect(c.read(accountLabelProvider), 'kj@example.com');
    });
  });

  testWidgets('BrewAuthGate swaps on sign-in', (tester) async {
    gotrue.answer(
      'POST /auth/v1/token?password',
      sessionJson(id: 'u1', email: 'kj@example.com'),
    );
    final auth = make(_emailAndGoogle);
    await tester.pumpWidget(
      MaterialApp(
        home: BrewAuthGate(
          auth: auth,
          signedIn: (_) => const Text('home'),
          signedOut: (_) => const Text('login'),
        ),
      ),
    );
    expect(find.text('login'), findsOneWidget);

    await tester.runAsync(() => auth.signInWithEmail('kj@example.com', 'pw'));
    await tester.pump();
    expect(find.text('home'), findsOneWidget);
  });
}

class _RealHttp extends HttpOverrides {}
