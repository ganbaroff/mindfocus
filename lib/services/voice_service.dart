import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';

/// Voice input service — calls Web Speech API via JS helper in index.html.
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  bool _listening = false;
  bool get isListening => _listening;

  /// Check if Web Speech API is available
  static bool get isSupported {
    if (!kIsWeb) return false;
    try {
      return _isSpeechSupported();
    } catch (_) {
      return false;
    }
  }

  /// Start listening. Returns recognized text or empty string on failure.
  Future<String> listen({String lang = 'ru-RU'}) async {
    if (!isSupported || _listening) return '';
    _listening = true;
    try {
      final result = await _startRecognition(lang).toDart;
      return (result as JSString?)?.toDart ?? '';
    } catch (e) {
      debugPrint('Voice listen error: $e');
      return '';
    } finally {
      _listening = false;
    }
  }
}

@JS('isSpeechSupported')
external bool _isSpeechSupported();

@JS('startSpeechRecognition')
external JSPromise _startRecognition(String lang);
