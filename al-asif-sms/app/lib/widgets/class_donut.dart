import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config.dart';
import '../models/dashboard.dart';

/// The HTML dashboard's "Class-wise Strength" donut, drawn the same way
/// the HTML draws it (an SVG circle with one arc segment per class):
/// a ring whose segments are proportional to each class's share, the
/// school total in the centre, and the legend "Class — Teacher · n (p%)".
/// Segment colours are the HTML's DONUT_COLORS, in the same order.
class ClassDonut extends StatelessWidget {
  final List<ClassStrength> strength;
  final int total;

  const ClassDonut({super.key, required this.strength, required this.total});

  static const List<Color> segmentColors = [
    Color(0xFFC9A227),
    Color(0xFF1A237E),
    Color(0xFF1A7A2E),
    Color(0xFFB3261E),
    Color(0xFF00796B),
    Color(0xFFE65100),
    Color(0xFF6A1B9A),
    Color(0xFF5D4037),
    Color(0xFF1565C0),
    Color(0xFFC2185B),
    Color(0xFF689F38),
  ];

  @override
  Widget build(BuildContext context) {
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < strength.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: segmentColors[i % segmentColors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      children: [
                        TextSpan(
                          text: strength[i].teacher.isNotEmpty &&
                                  strength[i].teacher != '-'
                              ? '${strength[i].className} — ${strength[i].teacher} · '
                              : '${strength[i].className} · ',
                        ),
                        TextSpan(
                          text: '${strength[i].count}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: ' (${strength[i].pct}%)'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    final donut = SizedBox(
      width: 180,
      height: 180,
      child: CustomPaint(
        painter: _DonutPainter(strength, total),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$total',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              const Text(
                'Total Students',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (_, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: [
              donut,
              const SizedBox(height: 12),
              legend,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            donut,
            const SizedBox(width: 18),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

/// Draws the ring: a light track, then one arc per class with students.
/// The HTML svg is 180x180 with r=40 and stroke-width 22, and each
/// segment is shortened by 1.5 units (a hairline gap between segments).
class _DonutPainter extends CustomPainter {
  final List<ClassStrength> strength;
  final int total;

  _DonutPainter(this.strength, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Scale the HTML svg geometry (180 box, r 40, stroke 22) to the box.
    final scale = size.width / 180;
    final radius = 40 * scale;
    final stroke = 22 * scale;
    final gap = 1.5 / 40; // radians, same as the HTML's 1.5-unit shortening

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFFE8EAF6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (total <= 0) return;

    var start = -math.pi / 2;
    for (var i = 0; i < strength.length; i++) {
      final s = strength[i];
      if (s.count <= 0) continue;
      final sweep = 2 * math.pi * s.count / total;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep - gap,
        false,
        Paint()
          ..color = ClassDonut.segmentColors[i % ClassDonut.segmentColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.strength != strength || old.total != total;
}
