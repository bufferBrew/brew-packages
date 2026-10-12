import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Catches one OAuth redirect on `http://localhost:<port>` (RFC 8252).
///
/// Desktop only. Supabase accepts any `http://localhost:*` redirect without an
/// allowlist entry, and every browser resolves a plain http redirect, unlike
/// a custom scheme. Not used on Android: a backgrounded app's network can be
/// suspended while the user is in Chrome, so the server is gone by the time
/// the redirect arrives (`ERR_CONNECTION_REFUSED`).
///
/// Binds [port] (0, the default, picks a free one), calls [launch] with the redirect URL, waits for
/// the browser to come back, runs [complete] on the callback URL, and only
/// then answers the browser, so the tab can say whether it worked.
Future<T> runLoopbackRedirect<T>({
  required Future<void> Function(String redirectTo) launch,
  required Future<T> Function(Uri callback) complete,
  required Duration timeout,
  required String appName,
  int port = 0,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  try {
    final redirectTo = 'http://localhost:${server.port}';
    await launch(redirectTo);

    // Browsers also ask for /favicon.ico; only the callback carries a query.
    final request = await server
        .firstWhere((r) => r.uri.path != '/favicon.ico')
        .timeout(
          timeout,
          onTimeout: () => throw TimeoutException('Sign-in timed out'),
        );
    final callback = Uri.parse(redirectTo).replace(query: request.uri.query);

    Object? error;
    StackTrace? stack;
    T? result;
    try {
      result = await complete(callback);
    } catch (e, s) {
      error = e;
      stack = s;
    }

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(_page(appName, success: error == null));
    await request.response.close();

    if (error != null) Error.throwWithStackTrace(error, stack!);
    return result as T;
  } finally {
    unawaited(server.close(force: true));
  }
}

String _page(String appName, {required bool success}) {
  final name = const HtmlEscape().convert(appName);
  final message = success
      ? 'Signed in to $name — you can close this tab.'
      : 'Sign-in to $name failed — you can close this tab and try again.';
  final script = success ? '<script>window.close();</script>' : '';
  return '<!DOCTYPE html><html><head><meta charset="utf-8"><title>$name</title>'
      '</head><body style="font-family:sans-serif;text-align:center;'
      'padding-top:3rem"><p>$message</p>$script</body></html>';
}
