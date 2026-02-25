import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FinanceProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  double _budget = 2500;
  double _spent = 0;
  List<Map<String, dynamic>> _expenses = [];

  static const categories = [
    {'name': 'Food', 'icon': '🍕', 'color': 0xFFFF7043},
    {'name': 'Transport', 'icon': '🚕', 'color': 0xFF42A5F5},
    {'name': 'Shopping', 'icon': '🛍️', 'color': 0xFFAB47BC},
    {'name': 'Bills', 'icon': '📄', 'color': 0xFF66BB6A},
    {'name': 'Fun', 'icon': '🎮', 'color': 0xFFFFCA28},
    {'name': 'Other', 'icon': '📌', 'color': 0xFF78909C},
  ];

  FinanceProvider(this._prefs);

  double get budget => _budget;
  double get spent => _spent;
  double get freeMoney => _budget - _spent;
  double get spentPercent => _budget > 0 ? (_spent / _budget).clamp(0, 1) : 0;
  List<Map<String, dynamic>> get expenses => _expenses;
  List<String> get history =>
      _expenses.map((e) => "-${e['amount']} AZN ${e['category']}").toList();

  Map<String, double> get categoryTotals {
    final map = <String, double>{};
    for (var e in _expenses) {
      final cat = e['category'] as String? ?? 'Other';
      map[cat] = (map[cat] ?? 0) + (e['amount'] as double);
    }
    return map;
  }

  void add(double amt, {String category = 'Other'}) {
    if (amt <= 0) return;
    _spent += amt;
    _expenses.insert(0, {
      'amount': amt,
      'category': category,
      'time': DateTime.now().toIso8601String(),
    });
    _save();
    notifyListeners();
  }

  void setBudget(double b) {
    _budget = b;
    _prefs.setDouble('budget', b);
    notifyListeners();
  }

  void loadFinanceData() {
    _spent = _prefs.getDouble('spent') ?? 0;
    _budget = _prefs.getDouble('budget') ?? 2500;
    final raw = _prefs.getString('expenses_v2');
    if (raw != null) {
      final List<dynamic> decoded = jsonDecode(raw);
      _expenses = decoded.cast<Map<String, dynamic>>();
    }
    notifyListeners();
  }

  void _save() {
    _prefs.setDouble('spent', _spent);
    _prefs.setString('expenses_v2', jsonEncode(_expenses));
  }
}
