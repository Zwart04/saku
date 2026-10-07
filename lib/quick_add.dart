import 'dart:async';

import 'package:flutter/material.dart';

import 'agent.dart';
import 'mascot.dart';
import 'models.dart';
import 'ocr.dart';
import 'theme.dart';
import 'voice.dart';

/// Lembar catat cepat: teks multi-item, suara, atau hasil scan struk.
class QuickAddSheet extends StatefulWidget {
  final VoiceHelper voice;
  final Future<void> Function()? onScanRequested;

  const QuickAddSheet({super.key, required this.voice, this.onScanRequested});

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final TextEditingController controller = TextEditingController();
  List<ParsedItem> preview = <ParsedItem>[];
  bool listening = false;
  StreamSubscription<String>? sub;
  StreamSubscription<String>? errSub;

  @override
  void initState() {
    super.initState();
    controller.addListener(_updatePreview);
  }

  void _updatePreview() {
    final items = MoneyAgent.parseExpenseItems(controller.text);
    if (!mounted) return;
    setState(() {
      preview = items;
    });
  }

  @override
  void dispose() {
    controller.removeListener(_updatePreview);
    controller.dispose();
    sub?.cancel();
    errSub?.cancel();
    super.dispose();
  }

  Future<void> _voice() async {
    final ok = await widget.voice.initialize();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice recognition tidak tersedia di HP ini.')),
        );
      }
      return;
    }
    setState(() => listening = true);
    sub ??= widget.voice.results.listen((String text) {
      if (!mounted) return;
      setState(() {
        listening = widget.voice.isListening;
      });
      controller.text = text;
      controller.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
    });
    errSub ??= widget.voice.errors.listen((String text) {
      if (!mounted) return;
      setState(() => listening = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    });
    await widget.voice.start();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Mascot(mood: listening ? Mood.listening : Mood.idle, size: 44),
                const SizedBox(width: 12),
                const Text('Titip pengeluaran', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop('::scan'),
                  icon: const Icon(Icons.receipt_long_outlined),
                  tooltip: 'Scan struk',
                ),
                IconButton(
                  onPressed: _voice,
                  icon: Icon(Icons.mic, color: listening ? C.warmDeep : C.inkSoft),
                  tooltip: 'Rekam suara',
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'makan bakso 25 ribu, kopi 7k',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onSubmitted: (v) => Navigator.of(context).pop(v),
            ),
            const SizedBox(height: 10),
            if (preview.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${preview.length} pengeluaran terlihat:',
                      style: const TextStyle(fontSize: 12, color: C.inkSoft),
                    ),
                    for (final p in preview)
                      Row(
                        children: [
                          Text('• ${p.merchant}', style: const TextStyle(fontSize: 13)),
                          const Spacer(),
                          Text(formatRupiah(p.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(controller.text),
                  icon: const Icon(Icons.check),
                  label: const Text('Catat'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lembar konfirmasi hasil scan struk — pilih baris yang mau dicatat.
class ScanConfirmSheet extends StatelessWidget {
  final List<ScannedLine> lines;

  const ScanConfirmSheet({super.key, required this.lines});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Mascot(size: 80, mood: Mood.surprised),
              const SizedBox(height: 12),
              const Text('Tidak ada nominal terbaca dari struk ini.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tutup')),
            ],
          ),
        ),
      );
    }
    return SafeArea(
      child: _ScanPicker(lines: lines),
    );
  }
}

class _ScanPicker extends StatefulWidget {
  final List<ScannedLine> lines;

  const _ScanPicker({required this.lines});

  @override
  State<_ScanPicker> createState() => _ScanPickerState();
}

class _ScanPickerState extends State<_ScanPicker> {
  late List<ScannedLine> lines = widget.lines;

  int get selectedTotal => lines.where((l) => l.selected).fold(0, (a, l) => a + (l.amount ?? 0));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Baris struk terbaca', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const Spacer(),
              Text(
                formatRupiah(selectedTotal),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: lines.length,
              itemBuilder: (context, i) {
                final line = lines[i];
                return CheckboxListTile(
                  dense: true,
                  value: line.selected,
                  onChanged: (v) => setState(() => lines[i] = line.copyWith(selected: v ?? false)),
                  title: Text(line.text, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(formatRupiah(line.amount ?? 0)),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  final chosen = lines.where((l) => l.selected).map((l) => l.text).join(', ');
                  Navigator.of(context).pop(chosen);
                },
                icon: const Icon(Icons.check),
                label: const Text('Catat yang dipilih'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
