import 'package:shared_preferences/shared_preferences.dart';

/// A location that sign-in interrupted, kept across the web OAuth round trip.
///
/// On web, OAuth leaves the page and comes back to the site root, so a `from`
/// carried in the URL or held in memory is gone by the time the session
/// arrives. Native sign-in never reloads the app and the router's `?from=` is
/// enough there, so the login screen only needs to call [savePendingLocation]
/// on web.
const String _key = 'brew.pending_location';

Future<void> savePendingLocation(String location) async {
  try {
    await (await SharedPreferences.getInstance()).setString(_key, location);
  } catch (_) {
    // Storage unavailable (private window, blocked site data): the user lands
    // on home instead of the linked screen. Not worth failing sign-in over.
  }
}

/// Returns the stored location and clears it, so it is followed at most once.
/// Pass the result through `safeReturnPath` before navigating.
Future<String?> takePendingLocation() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final location = prefs.getString(_key);
    if (location != null) await prefs.remove(_key);
    return location;
  } catch (_) {
    return null;
  }
}
