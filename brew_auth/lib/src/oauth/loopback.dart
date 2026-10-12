// dart:io isn't available on web, where OAuth is a same-tab redirect anyway.
export 'loopback_stub.dart' if (dart.library.io) 'loopback_io.dart';
