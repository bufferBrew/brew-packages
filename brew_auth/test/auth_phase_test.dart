import 'package:brew_auth/brew_auth.dart';
import 'package:flutter_test/flutter_test.dart';

String? go(AuthPhase phase, String location, {bool Function(Uri)? isPublic}) =>
    brewAuthRedirect(
      phase: phase,
      location: Uri.parse(location),
      isPublic: isPublic,
    );

void main() {
  group('brewAuthRedirect', () {
    test('waits while auth is unknown', () {
      expect(go(AuthPhase.unknown, '/generate?topic=x'), isNull);
      expect(go(AuthPhase.unknown, '/login'), isNull);
    });

    test('signed out: to login, carrying the requested location', () {
      expect(
        go(AuthPhase.signedOut, '/generate?topic=rust'),
        '/login?from=%2Fgenerate%3Ftopic%3Drust',
      );
      expect(go(AuthPhase.signedOut, '/'), '/login');
      expect(go(AuthPhase.signedOut, '/login'), isNull);
    });

    test('signed out: public paths are let through', () {
      expect(
        go(AuthPhase.signedOut, '/about', isPublic: (u) => u.path == '/about'),
        isNull,
      );
    });

    test('signed in at login: back to from, or home', () {
      expect(
        go(AuthPhase.signedIn, '/login?from=%2Fgenerate%3Ftopic%3Drust'),
        '/generate?topic=rust',
      );
      expect(go(AuthPhase.signedIn, '/login'), '/');
      expect(go(AuthPhase.signedIn, '/settings'), isNull);
    });

    test('a hostile from never leaves the app', () {
      expect(go(AuthPhase.signedIn, '/login?from=https://evil.com'), '/');
      expect(go(AuthPhase.signedIn, '/login?from=//evil.com'), '/');
    });
  });

  group('safeReturnPath', () {
    test('accepts in-app paths only', () {
      expect(safeReturnPath('/reader/1'), '/reader/1');
      expect(safeReturnPath(null), '/');
      expect(safeReturnPath('reader/1'), '/');
      expect(safeReturnPath('//evil.com/x'), '/');
      expect(safeReturnPath('/login?from=/x'), '/');
      expect(safeReturnPath(null, home: '/home'), '/home');
    });
  });
}
