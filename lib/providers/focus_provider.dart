import 'dart:async';
import 'package:flutter/material.dart';

class FocusProvider with ChangeNotifier {
  Timer? _t;
  int _totalSeconds = 1500; // 25 min default
  int _remaining = 1500;
  bool _run = false;
  int _sessionsToday = 0;
  final List<String> _log = [];

  // Presets
  static const presets = [
    {'label': '25 min', 'seconds': 1500},
    {'label': '50 min', 'seconds': 3000},
    {'label': '5 min', 'seconds': 300},
    {'label': '10 min', 'seconds': 600},
  ];

  int get totalSeconds => _totalSeconds;
  int get remaining => _remaining;
  int get seconds => _remaining; // backward compat
  bool get isRunning => _run;
  int get sessionsToday => _sessionsToday;
  List<String> get log => _log;
  double get progress =>
      _totalSeconds > 0 ? 1.0 - (_remaining / _totalSeconds) : 0.0;

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
          _log.insert(0, '${mins}min session completed');
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
