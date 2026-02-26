import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FinanceProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  double _budget = 2500;
  double _spent = 0;
  double _income = 0;
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
  double get income => _income;
  double get freeMoney => _budget - _spent + _income;
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
    _expenses.insert(0, {
      'amount': amt,
      'category': category,
      'time': DateTime.now().toIso8601String(),
    });
    _recalculate();
    _save();
    notifyListeners();
  }

  void deleteExpense(int index) {
    if (index < 0 || index >= _expenses.length) return;
    _expenses.removeAt(index);
    _recalculate();
    _save();
    notifyListeners();
  }

  void addIncome(double amt) {
    if (amt <= 0) return;
    _income += amt;
    _prefs.setDouble('income', _income);
    notifyListeners();
  }

  void setBudget(double b) {
    _budget = b;
    _prefs.setDouble('budget', b);
    notifyListeners();
  }

  void loadFinanceData() {
    _budget = _prefs.getDouble('budget') ?? 2500;
    _income = _prefs.getDouble('income') ?? 0;
    final raw = _prefs.getString('expenses_v2');
    if (raw != null) {
      final List<dynamic> decoded = jsonDecode(raw);
      _expenses = decoded.cast<Map<String, dynamic>>();
    }

    // Check monthly reset
    _checkMonthlyReset();

    // Always recalculate _spent from actual expenses (fixes desync)
    _recalculate();
    notifyListeners();
  }

  void _recalculate() {
    _spent = 0;
    for (var e in _expenses) {
      _spent += (e['amount'] as double?) ?? 0;
    }
  }

  void _checkMonthlyReset() {
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month}';
    final savedMonth = _prefs.getString('finance_month') ?? '';

    if (savedMonth != currentMonth) {
      // New month — archive old expenses, reset
      if (_expenses.isNotEmpty) {
        final archiveKey = 'expenses_archive_$savedMonth';
        _prefs.setString(archiveKey, jsonEncode(_expenses));
      }
      _expenses.clear();
      _spent = 0;
      _income = 0;
      _prefs.setDouble('income', 0);
      _prefs.setString('finance_month', currentMonth);
      _save();
    }
  }

  void _save() {
    _prefs.setDouble('spent', _spent);
    _prefs.setString('expenses_v2', jsonEncode(_expenses));
  }
}
