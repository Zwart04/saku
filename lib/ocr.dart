import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'agent.dart';

class ScannedLine {
  final String text;
  final int? amount;
  final String merchant;
  final bool selected;

  const ScannedLine({
    required this.text,
    required this.amount,
    required this.merchant,
    required this.selected,
  });

  ScannedLine copyWith({bool? selected}) => ScannedLine(
        text: text,
        amount: amount,
        merchant: merchant,
        selected: selected ?? this.selected,
      );
}

/// Baca struk dari foto (offline, ML Kit) lalu ubah per-baris bernominal jadi draft.
class BillScanner {
  TextRecognizer? _recognizer;

  TextRecognizer get _rx => _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

  Future<List<ScannedLine>> scanFromPath(String filePath) async {
    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final result = await _rx.processImage(inputImage);
      final lines = <ScannedLine>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();
          if (text.isEmpty) continue;
          final amount = MoneyAgent.parseAmountOf(text);
          if (amount == null || amount <= 0) continue;
          final (_, merchant) = MoneyAgent.guessCategoryAndMerchant(text);
          lines.add(ScannedLine(
            text: text.length > 60 ? text.substring(0, 60) : text,
            amount: amount,
            merchant: merchant,
            selected: true,
          ));
        }
      }
      return lines;
    } catch (e) {
      return <ScannedLine>[];
    }
  }

  Future<void> dispose() async {
    try {
      await _recognizer?.close();
    } catch (_) {}
    _recognizer = null;
  }
}
