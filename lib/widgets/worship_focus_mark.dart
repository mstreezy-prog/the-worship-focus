import 'package:flutter/material.dart';

/// The planner's existing magnifying-glass / cross mark, drawn as a vector.
class WorshipFocusMark extends StatelessWidget {
  const WorshipFocusMark({this.size = 28, super.key});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size * 54 / 50,
    child: CustomPaint(
      painter: _MarkPainter(Theme.of(context).colorScheme.primary),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 50, size.height / 54);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(21, 20), 14.5, paint);
    canvas.drawLine(const Offset(31, 31), const Offset(45, 48), paint);
    canvas.drawLine(const Offset(33, 45), const Offset(43, 35), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => color != oldDelegate.color;
}
