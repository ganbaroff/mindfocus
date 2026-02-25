import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  ThemeMode _mode = ThemeMode.dark;
  ThemeProvider(this._prefs);
  ThemeMode get themeMode => _mode;
  void loadTheme() {
    final s = _prefs.getString('theme');
    if (s == 'light') _mode = ThemeMode.light;
    notifyListeners();
  }

  void toggleTheme() {
    _mode = (_mode == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    _prefs.setString('theme', _mode == ThemeMode.light ? 'light' : 'dark');
    notifyListeners();
  }
}
