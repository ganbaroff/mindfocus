import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../services/gemini_service.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _tc = TextEditingController();
  final ScrollController _sc = ScrollController();
  final List<ChatMessage> _msgs = [];
  bool _loading = false;
  bool _isRecording = false;

  final _gemini = GeminiService.instance;

  @override
  void initState() {
    super.initState();
    _loadChat();
  }

  Future<void> _loadChat() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('unified_chat');
    if (raw != null) {
      final List<dynamic> decoded = jsonDecode(raw);
      setState(() {
        _msgs.addAll(decoded.map((e) => ChatMessage.fromJson(e)));
      });
    }
  }

  Future<void> _saveChat() async {
    final prefs = await SharedPreferences.getInstance();
    final last20 = _msgs.length > 20 ? _msgs.sublist(_msgs.length - 20) : _msgs;
    prefs.setString(
        'unified_chat', jsonEncode(last20.map((m) => m.toJson()).toList()));
  }

  Future<void> _send([String? prefill]) async {
    final text = (prefill ?? _tc.text).trim();
    if (text.isEmpty) return;
    _tc.clear();

    setState(() {
      _msgs.add(ChatMessage(role: 'user', text: text));
      _loading = true;
    });
    _scrollDown();

    final (sysPrompt, prefix) = _gemini.route(text);

    final contents = _msgs
        .map((m) => {
              'role': m.role == 'user' ? 'user' : 'model',
              'parts': [
                {'text': m.text}
              ],
            })
        .toList();

    try {
      final result = await _gemini.generateContent(
        systemPrompt: sysPrompt,
        contents: contents,
      );
      setState(() {
        _msgs.add(ChatMessage(
            role: 'model',
            text: prefix.isNotEmpty ? '$prefix$result' : result));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _msgs.add(ChatMessage(role: 'model', text: 'Error: $e'));
        _loading = false;
      });
    }
    _saveChat();
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sc.hasClients) {
        _sc.animateTo(_sc.position.maxScrollExtent + 100,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _startVoice() async {
    setState(() => _isRecording = true);
    final text = await VoiceService.instance.listen();
    setState(() => _isRecording = false);
    if (text.isNotEmpty) {
      _tc.text = text;
      _tc.selection =
          TextSelection.fromPosition(TextPosition(offset: text.length));
    }
  }

  void _exportChat() {
    if (_msgs.isEmpty) return;
    final buffer = StringBuffer();
    buffer.writeln('MindFocus Chat Export');
    buffer.writeln('=' * 40);
    for (final m in _msgs) {
      final label = m.role == 'user' ? '👤 You' : '🤖 AI';
      buffer.writeln('\n$label:');
      buffer.writeln(m.text);
    }
    // Copy to clipboard
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Chat copied to clipboard ✅'),
          duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.pageGradient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('AI Chat'),
          actions: [
            if (_msgs.isNotEmpty) ...[
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Export chat',
                onPressed: _exportChat,
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep, size: 20),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.surfaceLight,
                      title: const Text('Clear chat?',
                          style: TextStyle(color: AppTheme.textPrimary)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () async {
                              setState(() => _msgs.clear());
                              final prefs =
                                  await SharedPreferences.getInstance();
                              prefs.remove('unified_chat');
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: const Text('Clear',
                                style: TextStyle(color: AppTheme.danger))),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
        body: Column(children: [
          // Quick tag chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _tagChip('#task', AppTheme.warning),
                const SizedBox(width: 8),
                _tagChip('#linkedin', const Color(0xFF0077B5)),
                const SizedBox(width: 8),
                _tagChip('#azlife', AppTheme.success),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: _msgs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 56, color: AppTheme.primary.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        const Text('Ask me anything',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 16)),
                        const SizedBox(height: 8),
                        const Text('Use #task, #linkedin for specialized AI',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _sc,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _msgs.length + (_loading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _msgs.length && _loading) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.card.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.accent)),
                                const SizedBox(width: 12),
                                const Text('Thinking...',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        );
                      }
                      final msg = _msgs[i];
                      final isUser = msg.role == 'user';
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(14),
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.8),
                          decoration: BoxDecoration(
                            gradient: isUser
                                ? const LinearGradient(colors: [
                                    AppTheme.primary,
                                    Color(0xFF5A52D5)
                                  ])
                                : null,
                            color:
                                isUser ? null : AppTheme.card.withOpacity(0.4),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isUser ? 18 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 18),
                            ),
                            border: isUser
                                ? null
                                : Border.all(
                                    color: Colors.white.withOpacity(0.05)),
                          ),
                          child: SelectableText(
                            msg.text,
                            style: TextStyle(
                              color:
                                  isUser ? Colors.white : AppTheme.textPrimary,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border:
                  Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _tc,
                  onSubmitted: (_) => _send(),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Message MindFocus...',
                    filled: true,
                    fillColor: AppTheme.surfaceLight.withOpacity(0.8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Mic button
              if (VoiceService.isSupported)
                GestureDetector(
                  onTap: _loading || _isRecording ? null : _startVoice,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording
                          ? AppTheme.danger.withOpacity(0.2)
                          : AppTheme.surfaceLight,
                    ),
                    child: Icon(_isRecording ? Icons.mic : Icons.mic_none,
                        color: _isRecording
                            ? AppTheme.danger
                            : AppTheme.textSecondary,
                        size: 20),
                  ),
                ),
              const SizedBox(width: 6),
              // Send button
              GestureDetector(
                onTap: _loading ? null : () => _send(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: _loading
                            ? [AppTheme.divider, AppTheme.divider]
                            : [AppTheme.primary, AppTheme.accent]),
                  ),
                  child: const Icon(Icons.arrow_upward,
                      color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _tagChip(String tag, Color color) {
    return GestureDetector(
      onTap: () {
        _tc.text = '$tag ';
        _tc.selection =
            TextSelection.fromPosition(TextPosition(offset: _tc.text.length));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(tag,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
