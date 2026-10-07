import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Pembungkus SpeechRecognizer (plugin speech_to_text, bahasa Indonesia).
/// Lebih aman seperti ini: voice recognition langsung pakai plugin-nya.
class VoiceHelper {
  final StreamController<String> _results = StreamController.broadcast();
  final StreamController<String> _errors = StreamController.broadcast();

  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _available = false;
  String? _localeId;

  Stream<String> get results => _results.stream;
  Stream<String> get errors => _errors.stream;

  Future<bool> initialize() async {
    if (_available) return true;
    try {
      _available = await _stt.initialize();
    } catch (_) {
      _available = false;
    }
    if (_available) {
      try {
        final locales = await _stt.locales();
        for (final l in locales) {
          final id = l.localeId.toLowerCase();
          if (id.startsWith('id')) {
            _localeId = l.localeId;
            break;
          }
        }
      } catch (_) {}
    }
    return _available;
  }

  bool get isListening => _stt.isListening;

  Future<void> start() async {
    if (!await initialize()) {
      _errors.add('Voice recognition tidak tersedia di HP ini.');
      return;
    }
    await _stt.listen(
      onResult: (r) {
        final words = r.recognizedWords;
        if (words.isNotEmpty) {
          _results.add(words);
        }
      },
      localeId: _localeId ?? 'id-ID',
    );
  }

  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }

  void dispose() {
    stop();
    _results.close();
    _errors.close();
  }
}
