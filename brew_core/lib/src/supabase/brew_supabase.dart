import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/brew_config.dart';

/// Boots Supabase the same way in every Brew app.
abstract final class BrewSupabase {
  /// Initialises the global client against [config].
  ///
  /// [schema] is the app's own Postgres schema (`brewwire`, `wealth`, ...),
  /// set as the default so every `.from()`/`.rpc()` resolves against it. Apps
  /// on `public` (BREW, NeuroBrew) leave it null. Cross-schema reads go
  /// through `client.schema('core')`, never another app's schema.
  ///
  /// Throws [BrewInitException] with a user-facing message on timeout, so the
  /// app's error screen can show it as-is.
  static Future<SupabaseClient> init(
    BrewConfig config, {
    String? schema,
    FlutterAuthClientOptions authOptions = const FlutterAuthClientOptions(),
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      await Supabase.initialize(
        url: config.supabaseUrl,
        publishableKey: config.supabaseAnonKey,
        postgrestOptions: schema == null
            ? const PostgrestClientOptions()
            : PostgrestClientOptions(schema: schema),
        authOptions: authOptions,
      ).timeout(timeout);
    } on TimeoutException {
      throw BrewInitException(
        'Could not reach ${config.supabaseUrl} within ${timeout.inSeconds}s. '
        'Check your network and try again.',
      );
    }
    return Supabase.instance.client;
  }
}

/// Start-up failed in a way the user should see.
class BrewInitException implements Exception {
  const BrewInitException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The client brew_core's repositories use. Override in tests, or to hand
/// brew_core a client that isn't `Supabase.instance`.
final brewClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// The signed-in user's id, for writes whose RLS policy checks `user_id`.
///
/// Throws rather than returning null: Postgres would refuse the write anyway,
/// with a less useful message. [target] names what was being written.
String requireUserId(SupabaseClient client, String target) {
  final user = client.auth.currentUser;
  if (user == null) {
    throw StateError('no Supabase session — cannot write $target');
  }
  return user.id;
}
