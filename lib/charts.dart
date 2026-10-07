import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

/// Kartu grafik dengan baris tanggal & pie mini — CustomPainter sederhana.
class DailyBucket {
  final String date;
  final int total;
  const DailyBucket(this.date, this.total);
}

List<DailyBucket> dailyBuckets(List<Expense> list) {
  final byDay = <String, int>{};
  for (final e in list) {
    byDay[e.dateKey] = (byDay[e.dateKey] ?? 0) + e.amount;
  }
  final keys = byDay.keys.toList()..sort();
  return keys.map((k) => DailyBucket(k, byDay[k] ?? 0)).toList();
}

Map<String, int> categoryTotals(List<Expense> list) {
  final out = <String, int>{};
  for (final e in list) {
    out[e.category] = (out[e.category] ?? 0) + e.amount;
  }
  return out;
}

class ChartView extends StatelessWidget {
  final ChartKind kind;
  final List<Expense> expenses;

  const ChartView({super.key, required this.kind, required this.expenses});

  @override
  Widget build(BuildContext context) {
    if (kind == ChartKind.pie) {
      return _ChartPie(expenses: expenses);
    }
    return _ChartBarsLine(kind: kind, expenses: expenses);
  }
}

class _ChartBarsLine extends StatelessWidget {
  final ChartKind kind;
  final List<Expense> expenses;

  const _ChartBarsLine({required this.kind, required this.expenses});

  @override
  Widget build(BuildContext context) {
    final buckets = dailyBuckets(expenses);
    if (buckets.isEmpty) {
      return emptyChart();
    }
    final view = buckets.length > 14 ? buckets.sublist(buckets.length - 14) : buckets;
    final maxV = view.map((b) => b.total).fold(1, (a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF4F0E9),
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          height: 150,
          width: double.infinity,
          child: CustomPaint(
            painter: _BarsLinePainter(
              dailyBuckets: view,
              maxValue: maxV,
              drawLine: kind == ChartKind.line,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          view.map((b) => b.date.substring(5)).join(' • '),
          style: const TextStyle(fontSize: 9, color: C.inkSoft),
          overflow: TextOverflow.clip,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget emptyChart() {
    return Container(
      height: 110,
      alignment: Alignment.center,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Belum ada data di rentang ini', style: TextStyle(fontSize: 12, color: C.ink)),
      ),
    );
  }
}

class _BarsLinePainter extends CustomPainter {
  final List<DailyBucket> dailyBuckets_;
  final int maxValue;
  final bool drawLine;

  _BarsLinePainter({
    required List<DailyBucket> dailyBuckets,
    required this.maxValue,
    required this.drawLine,
  }) : dailyBuckets_ = dailyBuckets;

  @override
  void paint(Canvas canvas, Size size) {
    final n = dailyBuckets_.length;
    if (n == 0) return;
    final slot = size.width / n;
    if (!drawLine) {
      final barW = slot * 0.52;
      for (var i = 0; i < n; i++) {
        final item = dailyBuckets_[i];
        final h = (item.total / maxValue) * (size.height * 0.86);
        final x = i * slot + (slot - barW) / 2;
        final y = size.height - h - 12;
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTRB(x, y, x + barW, size.height - 12),
          Radius.circular(barW / 2.2),
        );
        canvas.drawRRect(rrect, Paint()..color = C.warm);
      }
    } else {
      final path = Path();
      final paint = Paint()
        ..color = C.mintDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      final step = n == 1 ? 0.0 : size.width / (n - 1);
      for (var i = 0; i < n; i++) {
        final item = dailyBuckets_[i];
        final x = i * step;
        final y = size.height - (item.total / maxValue) * (size.height * 0.82) - 10;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
      for (var i = 0; i < n; i++) {
        final item = dailyBuckets_[i];
        final x = i * step;
        final y = size.height - (item.total / maxValue) * (size.height * 0.82) - 10;
        canvas.drawCircle(Offset(x, y), 5, Paint()..color = C.mint);
        canvas.drawCircle(Offset(x, y), 2.4, Paint()..color = C.mintDeep);
      }
    }
  }

  @override
  bool shouldRepaint(_BarsLinePainter oldDelegate) => false;
} // end of _BarsLinePainter

class _ChartPie extends StatelessWidget {
  final List<Expense> expenses;

  const _ChartPie({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final totals = categoryTotals(expenses);
    if (totals.isEmpty) {
      return Container(
        height: 110,
        alignment: Alignment.center,
        child: const Text('Belum ada data kategori', style: TextStyle(fontSize: 12, color: C.inkSoft)),
      );
    }
    final entries = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.map((e) => e.value).fold(1, (a, b) => a + b);
    return Column(
      children: [
        SizedBox(
          height: 150,
          width: double.infinity,
          child: CustomPaint(painter: _PiePainter(entries: entries, total: total)),
        ),
        const SizedBox(height: 8),
        Column(children: _legendRows(entries)),
      ],
    );
  }

  List<Widget> _legendRows(List<MapEntry<String, int>> entries) {
    final out = <Widget>[];
    final top = entries.take(6).toList();
    for (var i = 0; i < top.length; i++) {
      final color = C.palette[i % C.palette.length];
      out.add(Row(
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
          ),
          Expanded(child: Text(top[i].key, style: const TextStyle(fontSize: 12))),
          Text(formatRupiah(top[i].value), style: const TextStyle(fontSize: 12, color: C.inkSoft)),
        ],
      ));
    }
    return out;
  }
}

class _PiePainter extends CustomPainter {
  final List<MapEntry<String, int>> entries;
  final int total;

  _PiePainter({required this.entries, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width, size.height) / 2.4;
    final center = Offset(size.width / 2, size.height / 2);
    var start = -math.pi / 2;
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final sweep = 2 * math.pi * (e.value / total);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        Paint()..color = C.palette[i % C.palette.length],
      );
      start += sweep;
    }
    canvas.drawCircle(center, radius * 0.45, Paint()..color = C.card);
  }

  @override
  bool shouldRepaint(_PiePainter oldDelegate) => false;
}

