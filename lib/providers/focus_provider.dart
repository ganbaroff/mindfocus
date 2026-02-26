import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FocusProvider with ChangeNotifier {
  Timer? _t;
  int _totalSeconds = 1500; // 25 min default
  int _remaining = 1500;
  bool _run = false;
  int _sessionsToday = 0;
  int _totalMinutesToday = 0;
  final List<String> _log = [];
  SharedPreferences? _prefs;

  // Presets
  static const presets = [
    {'label': '25 min', 'seconds': 1500},
    {'label': '50 min', 'seconds': 3000},
    {'label': '5 min', 'seconds': 300},
    {'label': '10 min', 'seconds': 600},
  ];

  int get totalSeconds => _totalSeconds;
  int get remaining => _remaining;
  int get seconds => _remaining;
  bool get isRunning => _run;
  int get sessionsToday => _sessionsToday;
  int get totalMinutesToday => _totalMinutesToday;
  List<String> get log => _log;
  double get progress =>
      _totalSeconds > 0 ? 1.0 - (_remaining / _totalSeconds) : 0.0;

  /// Load persisted focus data from SharedPreferences
  Future<void> loadData(SharedPreferences prefs) async {
    _prefs = prefs;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString('focus_date') ?? '';

    if (savedDate == today) {
      _sessionsToday = prefs.getInt('focus_sessions') ?? 0;
      _totalMinutesToday = prefs.getInt('focus_minutes') ?? 0;
      final logRaw = prefs.getString('focus_log');
      if (logRaw != null) {
        final List<dynamic> decoded = jsonDecode(logRaw);
        _log.clear();
        _log.addAll(decoded.cast<String>());
      }
    } else {
      // New day — reset
      _sessionsToday = 0;
      _totalMinutesToday = 0;
      _log.clear();
      _save(today);
    }
    notifyListeners();
  }

  void _save([String? date]) {
    if (_prefs == null) return;
    final today = date ?? DateTime.now().toIso8601String().substring(0, 10);
    _prefs!.setString('focus_date', today);
    _prefs!.setInt('focus_sessions', _sessionsToday);
    _prefs!.setInt('focus_minutes', _totalMinutesToday);
    _prefs!.setString('focus_log', jsonEncode(_log));
  }

  void setDuration(int seconds) {
    if (_run) return;
    _totalSeconds = seconds;
    _remaining = seconds;
    notifyListeners();
  }

  void toggle() {
    if (_run) {
      _t?.cancel();
      _run = false;
    } else {
      _run = true;
      _t = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_remaining > 0) {
          _remaining--;
          notifyListeners();
        } else {
          t.cancel();
          _run = false;
          _sessionsToday++;
          final mins = _totalSeconds ~/ 60;
          _totalMinutesToday += mins;
          _log.insert(0,
              '${mins}min session @ ${DateTime.now().hour.toString().padLeft(2, "0")}:${DateTime.now().minute.toString().padLeft(2, "0")}');
          _save();
          notifyListeners();
        }
      });
    }
    notifyListeners();
  }

  void reset() {
    _t?.cancel();
    _run = false;
    _remaining = _totalSeconds;
    notifyListeners();
  }
}
