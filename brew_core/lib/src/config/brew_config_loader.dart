import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'brew_config.dart';

/// Persists a user-entered [BrewConfig] on the device.
abstract interface class BrewConfigStore {
  Future<BrewConfig?> read();
  Future<void> save(BrewConfig config);
  Future<void> clear();
}

/// [BrewConfigStore] on shared_preferences, which every platform (web
/// included) supports and supabase_flutter already pulls in.
class SharedPrefsConfigStore implements BrewConfigStore {
  const SharedPrefsConfigStore({this.key = 'brew.config.v1'});

  final String key;

  @override
  Future<BrewConfig?> read() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) return null;
      return BrewConfig.fromJson(json, BrewConfigSource.saved);
    } on FormatException {
      return null;
    } on BrewConfigException {
      // A value that no longer validates is as good as none: send the user
      // back to setup rather than refusing to start.
      return null;
    }
  }

  @override
  Future<void> save(BrewConfig config) async {
    await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode(config.toJson()),
    );
  }

  @override
  Future<void> clear() async {
    await (await SharedPreferences.getInstance()).remove(key);
  }
}

/// Fetches `/config.json` next to a web build and returns its JSON, or null
/// when there is none.
///
/// The SPA fallback in `nginx.conf` (and Vercel's rewrite) answers unknown
/// paths with `index.html` and a 200, so "not JSON" means "absent", not
/// "broken".
Future<Map<String, Object?>?> fetchHostedConfig({
  Uri? url,
  http.Client? client,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final target = url ?? Uri.base.resolve('/config.json');
  final c = client ?? http.Client();
  try {
    final res = await c.get(target).timeout(timeout);
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body);
    return body is Map<String, Object?> ? body : null;
  } on FormatException {
    return null;
  } on TimeoutException {
    return null;
  } on http.ClientException {
    return null;
  } finally {
    if (client == null) c.close();
  }
}

/// Resolves which backend this app should use, or null if none is set up.
///
/// Order, first hit wins:
///   1. `--dart-define` values — the developer workflow, and what CI uses.
///   2. On web, a hosted `config.json` — Docker and static hosting.
///   3. A config the user saved on this device — prebuilt releases.
///
/// Null means "show the setup screen". A half-set or malformed config throws
/// [BrewConfigException] instead, because that is a mistake to fix, not a
/// first run.
Future<BrewConfig?> loadBrewConfig({
  String definedUrl = const String.fromEnvironment(BrewConfig.urlKey),
  String definedAnonKey = const String.fromEnvironment(BrewConfig.anonKeyKey),
  Future<Map<String, Object?>?> Function()? fetchHosted,
  BrewConfigStore store = const SharedPrefsConfigStore(),
  bool isWeb = kIsWeb,
}) async {
  if (definedUrl.isNotEmpty || definedAnonKey.isNotEmpty) {
    if (definedUrl.isEmpty || definedAnonKey.isEmpty) {
      throw const BrewConfigException(
        'Only one of SUPABASE_URL / SUPABASE_ANON_KEY was defined. Build with '
        '--dart-define-from-file=env/dev.json, which sets both.',
      );
    }
    return BrewConfig.fromJson({
      BrewConfig.urlKey: definedUrl,
      BrewConfig.anonKeyKey: definedAnonKey,
    }, BrewConfigSource.dartDefine);
  }

  if (isWeb) {
    final hosted = await (fetchHosted ?? fetchHostedConfig)();
    if (hosted != null) {
      final config = BrewConfig.fromJson(hosted, BrewConfigSource.hosted);
      if (config != null) return config;
    }
  }

  return store.read();
}
