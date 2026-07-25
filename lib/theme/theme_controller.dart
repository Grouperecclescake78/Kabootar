import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's light/dark/system preference, persisted across launches.
/// Provided above [MaterialApp] so a change instantly re-themes the whole app.
class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs) : _mode = _read(_prefs);

  final SharedPreferences _prefs;
  ThemeMode _mode;

  static const String _key = 'studchat.themeMode';

  ThemeMode get mode => _mode;

  static Future<ThemeController> create() async =>
      ThemeController(await SharedPreferences.getInstance());

  static ThemeMode _read(SharedPreferences prefs) {
    switch (prefs.getString(_key)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _prefs.setString(_key, mode.name);
  }
}
