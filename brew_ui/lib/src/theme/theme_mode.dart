import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's light/dark/system choice on the device.
///
/// One implementation for the four controllers BREW, BrewWire, brewfeed and
/// NeuroBrew each had. Apps that also sync the choice to their backend
/// (BrewWire's `user_prefs`) wrap this and add the sync.
class ThemeModeStore {
  const ThemeModeStore({this.key = 'theme_mode'});

  final String key;

  Future<ThemeMode> load() async {
    try {
      final stored = (await SharedPreferences.getInstance()).getString(key);
      return ThemeMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => ThemeMode.system,
      );
    } catch (_) {
      // Storage unavailable (private window): follow the system.
      return ThemeMode.system;
    }
  }

  Future<void> save(ThemeMode mode) async {
    try {
      await (await SharedPreferences.getInstance()).setString(key, mode.name);
    } catch (_) {
      // Not persisting is better than failing the toggle.
    }
  }
}

/// Override to change the storage key, or to swap in a syncing store.
final themeModeStoreProvider = Provider<ThemeModeStore>(
  (ref) => const ThemeModeStore(),
);

/// The app's [ThemeMode]. `ThemeMode.system` until the stored choice loads.
final brewThemeModeProvider =
    AsyncNotifierProvider<BrewThemeModeController, ThemeMode>(
      BrewThemeModeController.new,
    );

class BrewThemeModeController extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() => ref.watch(themeModeStoreProvider).load();

  Future<void> set(ThemeMode mode) async {
    state = AsyncData(mode);
    await ref.read(themeModeStoreProvider).save(mode);
  }
}
