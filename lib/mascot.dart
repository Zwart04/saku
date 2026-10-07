import 'package:flutter/material.dart';

import 'theme.dart';

enum Mood { idle, happy, listening, thinking, surprised }

/// Mascot "Saku" — kantong uang lucu, digambar dengan CustomPaint (tanpa aset).
class Mascot extends StatelessWidget {
  final Mood mood;
  final double size;

  const Mascot({super.key, this.mood = Mood.idle, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFF2EDE4),
        shape: BoxShape.circle,
      ),
      child: CustomPaint(painter: _MascotPainter(mood)),
    );
  }
}

class _MascotPainter extends CustomPainter {
  final Mood mood;

  _MascotPainter(this.mood);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Paint()..color = C.mascotBody;
    final line = Paint()
      ..color = C.mascotLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round;
    final fillLine = Paint()..color = C.mascotLine;
    final cheek = Paint()..color = C.rose.withOpacity(0.55);

    final center = Offset(w * 0.5, h * 0.56);
    canvas.drawCircle(center, w * 0.34, body);
    canvas.drawCircle(center, w * 0.34, line);

    final knot = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.225),
        width: w * 0.16,
        height: h * 0.09,
      ),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(knot, fillLine);

    final eyeR = w * 0.055;
    final eyeY = h * 0.5;
    final spacing = w * 0.11;
    if (mood == Mood.happy) {
      final arch = Rect.fromCenter(
        center: Offset(w * 0.5 - spacing, eyeY + eyeR * 0.2),
        width: eyeR * 2,
        height: eyeR * 1.6,
      );
      final arch2 = Rect.fromCenter(
        center: Offset(w * 0.5 + spacing, eyeY + eyeR * 0.2),
        width: eyeR * 2,
        height: eyeR * 1.6,
      );
      canvas.drawArc(arch, mathPi, -math2Pi / 2, false, line);
      canvas.drawArc(arch2, mathPi, -math2Pi / 2, false, line);
    } else {
      canvas.drawCircle(Offset(w * 0.5 - spacing, eyeY), eyeR, fillLine);
      canvas.drawCircle(Offset(w * 0.5 + spacing, eyeY), eyeR, fillLine);
    }

    canvas.drawCircle(Offset(w * 0.5 - w * 0.19, h * 0.6), w * 0.05, cheek);
    canvas.drawCircle(Offset(w * 0.5 + w * 0.19, h * 0.6), w * 0.05, cheek);

    if (mood == Mood.listening || mood == Mood.surprised) {
      canvas.drawCircle(Offset(w * 0.5, h * 0.68), w * 0.05, fillLine);
    } else {
      final mouth = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.6),
        width: w * 0.22,
        height: h * 0.14,
      );
      final sweepDeg = mood == Mood.happy ? 100.0 : 65.0;
      canvas.drawArc(mouth, 200 * mathPi / 180, sweepDeg * mathPi / 180, false, line);
    }
  }

  @override
  bool shouldRepaint(_MascotPainter oldDelegate) => oldDelegate.mood != mood;
}

const double mathPi = 3.1415926535897932;
const double math2Pi = mathPi * 2;
