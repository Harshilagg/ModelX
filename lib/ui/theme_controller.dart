import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the day/night switch is reachable by a user.
///
/// The dark theme is finished and correct, but only the screens that have
/// been retyped know how to render on it; the brand and agency sides are
/// still on the old light-only palette. Letting someone switch before
/// those land would show them a half-black app and read as a bug, so the
/// controller is pinned to light and the settings toggle is hidden.
///
/// Flip this to true once the migration reaches the agency screens. It is
/// the only thing that needs to change -- everything downstream already
/// honours the mode.
///
/// Onboarding is unaffected either way: it is dark by construction, via a
/// local [Theme] override rather than the app-wide mode.
const bool kThemeSwitchingEnabled = false;

/// Holds the chosen [ThemeMode] and remembers it across launches.
///
/// The value is read from disk *before* `runApp`, not in an initState or
/// a FutureBuilder. Loading it after the first frame means the app paints
/// light, then repaints dark a frame or two later -- the flash this is
/// meant to avoid. [load] is therefore awaited in `main()`, alongside the
/// Firebase init that is already blocking startup.
class ThemeController extends ChangeNotifier {
  static const String _prefsKey = 'theme_mode';

  ThemeMode _mode;

  ThemeController([ThemeMode initial = ThemeMode.system]) : _mode = initial;

  /// What [MaterialApp] should be given.
  ///
  /// While switching is disabled this reports light regardless of what is
  /// stored, so a preference saved by a future build -- or by a developer
  /// flipping the flag locally -- cannot leak into a release.
  ThemeMode get mode => kThemeSwitchingEnabled ? _mode : ThemeMode.light;

  /// The stored preference, whatever the gate says. Settings reads this
  /// so the UI shows what the user actually chose.
  ThemeMode get storedMode => _mode;

  /// Reads the saved preference. Never throws: a failure here would
  /// block startup, and the cost of getting it wrong is one wrong-themed
  /// launch, so it falls back to following the phone.
  static Future<ThemeController> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return ThemeController(_decode(prefs.getString(_prefsKey)));
    } catch (e) {
      debugPrint('ThemeController: could not read $_prefsKey ($e)');
      return ThemeController();
    }
  }

  Future<void> setMode(ThemeMode next) async {
    if (next == _mode) return;
    _mode = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _encode(next));
    } catch (e) {
      // The mode is already applied; it just will not survive a restart.
      debugPrint('ThemeController: could not save $_prefsKey ($e)');
    }
  }

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  static ThemeMode _decode(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
