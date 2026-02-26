import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gemini_service.dart';

class BrainDumpProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  List<String> _thoughts = [];
  bool _isGenerating = false;
  final List<Map<String, String>> _history = [];

  BrainDumpProvider(this._prefs) {
    loadThoughts();
    loadHistory();
  }

  List<String> get thoughts => _thoughts;
  bool get isGenerating => _isGenerating;

  void addThought(String t) {
    if (t.isEmpty) return;
    _thoughts.insert(0, t);
    _prefs.setStringList('thoughts', _thoughts);
    notifyListeners();
  }

  void deleteThought(int i) {
    _thoughts.removeAt(i);
    _prefs.setStringList('thoughts', _thoughts);
    notifyListeners();
  }

  void loadThoughts() {
    _thoughts = _prefs.getStringList('thoughts') ?? [];
    notifyListeners();
  }

  void _saveHistory() {
    _prefs.setString('chat_history', jsonEncode(_history));
  }

  void loadHistory() {
    final raw = _prefs.getString('chat_history');
    if (raw != null) {
      final List<dynamic> decoded = jsonDecode(raw);
      _history.clear();
      for (var item in decoded) {
        _history.add({
          'role': item['role'] as String,
          'text': item['text'] as String,
        });
      }
    }
    print("History Loaded: ${_history.length} items");
  }

  Future<String> processThought(String thought) async {
    if (thought.isEmpty) return '';
    _isGenerating = true;
    notifyListeners();

    final gemini = GeminiService.instance;
    final (systemPrompt, outputPrefix) = gemini.route(thought);

    _history.add({'role': 'user', 'text': thought});
    if (_history.length > 10) {
      _history.removeRange(0, _history.length - 10);
    }
    _saveHistory();

    try {
      final contents = _history
          .map((h) => {
                'role': h['role']!,
                'parts': [
                  {'text': h['text']!}
                ],
              })
          .toList();

      final result = await gemini.generateContent(
        systemPrompt: systemPrompt,
        contents: contents,
      );

      _history.add({'role': 'model', 'text': result});
      if (_history.length > 10) {
        _history.removeRange(0, _history.length - 10);
      }
      _saveHistory();

      _isGenerating = false;
      notifyListeners();
      return outputPrefix + result;
    } catch (e) {
      if (_history.isNotEmpty) _history.removeLast();
      _isGenerating = false;
      notifyListeners();
      return "Error: $e";
    }
  }
}
