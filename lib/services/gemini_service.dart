import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Unified Gemini 2.5 Flash service — singleton entry point for all AI calls.
/// Used by BrainDumpProvider, ChatPage, and any future module.
class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const _model = 'gemini-2.5-flash';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const _lang = 'Respond in the same language as the user input.';
  static const _noMarkdown =
      'Do NOT use asterisks, bold (**), italic (*), or any markdown. Use plain text and numbered lists only.';

  /// Route text to the correct system prompt based on tag prefix.
  (String, String) route(String text) {
    if (text.startsWith('#task')) {
      return (
        'You are a PMP project management assistant. '
            'The user describes a task. Analyze it and create a CONCRETE ACTION PLAN. '
            'Output a numbered list of 5-10 specific steps to complete this task. '
            'Each step must start with an action verb. '
            'Do NOT explain what the topic is. Do NOT write background info. '
            'Do NOT generate the deliverable itself, only the steps to produce it. '
            'Base your steps entirely on what the user wrote. '
            '$_noMarkdown $_lang',
        '',
      );
    } else if (text.startsWith('#azlife')) {
      return (
        'You are a game architect. Analyze the input and write concise game mechanic specs. '
            '$_noMarkdown $_lang',
        '',
      );
    } else if (text.startsWith('#linkedin')) {
      return (
        'You are a LinkedIn content writer for a Senior Event & Project Manager. '
            'Draft a LinkedIn post based on the topic provided. Write clean paragraphs. '
            '$_noMarkdown $_lang',
        '',
      );
    } else {
      return (
        'You are MindFocus AI, a direct executive assistant. '
            'Follow the user instruction EXACTLY. '
            'If they ask to rewrite text, return ONLY the rewritten text. '
            'If they ask a question, answer concisely. '
            'If they ask to improve text, return ONLY the improved version. '
            'Do NOT add explanations or preambles unless asked. '
            'Analyze the actual content the user provides and respond based on it. '
            '$_noMarkdown $_lang',
        '',
      );
    }
  }

  /// Strip markdown formatting from model output programmatically.
  static String cleanMarkdown(String input) {
    var t = input;
    t = t.replaceAllMapped(
        RegExp(r'\*\*(.+?)\*\*', dotAll: true), (m) => m.group(1)!);
    t = t.replaceAllMapped(RegExp(r'\*([^\*\n]+?)\*'), (m) => m.group(1)!);
    t = t.replaceAll(RegExp(r'^\*\s+', multiLine: true), '- ');
    t = t.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return t.trim();
  }

  /// Call Gemini via REST API.
  Future<String> generateContent({
    required String systemPrompt,
    required List<Map<String, dynamic>> contents,
  }) async {
    final url = Uri.parse('$_baseUrl/$_model:generateContent?key=$_apiKey');
    final payload = {
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': contents,
    };

    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (resp.statusCode != 200) {
      throw Exception('Gemini API Error: ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body);
    final candidates = data['candidates'] as List? ?? [];
    if (candidates.isNotEmpty) {
      final parts = candidates[0]['content']?['parts'] as List? ?? [];
      if (parts.isNotEmpty) {
        final raw = parts[0]['text'] ?? 'No content generated.';
        return cleanMarkdown(raw);
      }
    }
    return 'No content generated.';
  }
}
