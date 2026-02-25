class ChatMessage {
  final String role; // 'user' or 'model'
  final String text;

  ChatMessage({required this.role, required this.text});

  Map<String, String> toJson() => {'role': role, 'text': text};

  factory ChatMessage.fromJson(Map<String, dynamic> j) =>
      ChatMessage(role: j['role'] as String, text: j['text'] as String);
}
