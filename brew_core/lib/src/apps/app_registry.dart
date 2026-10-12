import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/brew_supabase.dart';

/// One row of `core.apps`, the registry of Brew apps on this backend.
@immutable
class BrewApp {
  const BrewApp({
    required this.key,
    required this.displayName,
    this.description = '',
    this.icon,
    this.repoUrl,
    this.enabled = true,
    this.sortOrder = 100,
  });

  /// Tolerant of older backends: `description` only exists from BREW
  /// migration 0050 on, so every column but the key is optional here.
  factory BrewApp.fromRow(Map<String, dynamic> row) => BrewApp(
    key: row['app'] as String,
    displayName: (row['display_name'] as String?) ?? row['app'] as String,
    description: (row['description'] as String?) ?? '',
    icon: row['icon'] as String?,
    repoUrl: row['repo_url'] as String?,
    enabled: (row['enabled'] as bool?) ?? true,
    sortOrder: (row['sort_order'] as int?) ?? 100,
  );

  final String key;
  final String displayName;
  final String description;
  final String? icon;
  final String? repoUrl;
  final bool enabled;
  final int sortOrder;
}

/// Reads `core.apps`.
///
/// This is how an app learns what else is installed. On the shared hosted
/// project every app is registered; on a standalone install only the apps
/// whose migrations ran have a row. So a cross-app link (BrewWire's "Learn
/// this" into NeuroBrew, say) checks [appAvailableProvider] and hides itself
/// when the target isn't there, instead of opening a dead end.
class AppRegistry {
  AppRegistry(this._client);

  final SupabaseClient _client;

  Future<List<BrewApp>> list() async {
    final rows = await _client
        .schema('core')
        .from('apps')
        .select()
        .order('sort_order');
    return [for (final row in rows) BrewApp.fromRow(row)];
  }
}

final appRegistryProvider = Provider<AppRegistry>(
  (ref) => AppRegistry(ref.watch(brewClientProvider)),
);

/// Every registered app, in display order.
final brewAppsProvider = FutureProvider<List<BrewApp>>(
  (ref) => ref.watch(appRegistryProvider).list(),
  retry: _retryTransient,
);

/// A PostgREST error (schema not exposed, no `core` on this backend) won't
/// fix itself, and Riverpod's default retry would keep the provider loading
/// forever. Network blips get a few short retries.
Duration? _retryTransient(int retryCount, Object error) {
  if (error is PostgrestException || retryCount >= 3) return null;
  return Duration(milliseconds: 200 * (1 << retryCount));
}

/// Whether the app with this key is registered and enabled on this backend.
///
/// False while loading and on error: a link that only appears once its target
/// is confirmed beats one that flashes in and then disappears.
final appAvailableProvider = Provider.family<bool, String>((ref, key) {
  final apps = ref.watch(brewAppsProvider).value;
  if (apps == null) return false;
  return apps.any((a) => a.key == key && a.enabled);
});
