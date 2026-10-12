import 'package:flutter/foundation.dart';

/// Where a [BrewConfig] came from. Shown on the setup screen and in error
/// messages, because "which file is this coming from?" is the first question
/// whenever an app points at the wrong backend.
enum BrewConfigSource {
  /// `--dart-define` / `--dart-define-from-file` at build time. What every
  /// app's `env/dev.json` workflow produces.
  dartDefine,

  /// A `config.json` served next to a web build. Lets one Docker image serve
  /// any backend: the container writes the file from its env at start-up.
  hosted,

  /// Entered on the device by the user, for prebuilt releases that ship
  /// without a backend baked in.
  saved,
}

/// Which Supabase backend an app talks to.
///
/// The JSON keys match the dart-define names (`SUPABASE_URL`,
/// `SUPABASE_ANON_KEY`), so `env/dev.json`, a hosted `config.json` and a
/// container's env all use one vocabulary.
@immutable
class BrewConfig {
  const BrewConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.source,
  });

  static const String urlKey = 'SUPABASE_URL';
  static const String anonKeyKey = 'SUPABASE_ANON_KEY';

  final String supabaseUrl;

  /// Public by design: RLS is what protects the data behind it.
  final String supabaseAnonKey;

  final BrewConfigSource source;

  /// Parses the shared JSON shape. Returns null when either value is missing
  /// or blank, which is how a container started without its env looks.
  /// Throws [BrewConfigException] when values are present but unusable.
  static BrewConfig? fromJson(
    Map<String, Object?> json,
    BrewConfigSource source,
  ) {
    final url = (json[urlKey] as String?)?.trim() ?? '';
    final key = (json[anonKeyKey] as String?)?.trim() ?? '';
    if (url.isEmpty || key.isEmpty) return null;
    final problem = validate(url, key);
    if (problem != null) {
      throw BrewConfigException('$problem (from ${source.name})');
    }
    return BrewConfig(supabaseUrl: url, supabaseAnonKey: key, source: source);
  }

  Map<String, String> toJson() => {
    urlKey: supabaseUrl,
    anonKeyKey: supabaseAnonKey,
  };

  /// Null when [url] and [anonKey] look usable, otherwise a message fit to
  /// show next to the field. Setup forms call this before saving.
  static String? validate(String url, String anonKey) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.host.isEmpty) {
      return 'Supabase URL must be an http(s) URL, e.g. '
          'https://<project>.supabase.co';
    }
    if (anonKey.trim().isEmpty) return 'Supabase anon key is empty';
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is BrewConfig &&
      other.supabaseUrl == supabaseUrl &&
      other.supabaseAnonKey == supabaseAnonKey &&
      other.source == source;

  @override
  int get hashCode => Object.hash(supabaseUrl, supabaseAnonKey, source);

  @override
  String toString() => 'BrewConfig($supabaseUrl via ${source.name})';
}

/// A configuration that exists but cannot work. Distinct from "no
/// configuration", which sends the user to a setup screen instead.
class BrewConfigException implements Exception {
  const BrewConfigException(this.message);
  final String message;

  @override
  String toString() => 'BrewConfigException: $message';
}
