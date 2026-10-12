/// Web stub; see `loopback_io.dart`.
Future<T> runLoopbackRedirect<T>({
  required Future<void> Function(String redirectTo) launch,
  required Future<T> Function(Uri callback) complete,
  required Duration timeout,
  required String appName,
}) => throw UnsupportedError('Loopback OAuth is not available on web');
