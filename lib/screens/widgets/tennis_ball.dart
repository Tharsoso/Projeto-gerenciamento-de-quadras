import 'package:flutter/material.dart';
import '../../app_theme.dart';

class TennisBall extends StatelessWidget {
  final double size;
  const TennisBall({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _BallPainter()));
}

class _BallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1.5;
    canvas.drawCircle(c, r, Paint()..color = AppColors.ball);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.green,
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width / 16
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    final left = Path()
      ..moveTo(size.width * 0.17, size.height * 0.19)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.32,
        size.width * 0.32,
        size.height * 0.68,
        size.width * 0.17,
        size.height * 0.81,
      );
    final right = Path()
      ..moveTo(size.width * 0.83, size.height * 0.19)
      ..cubicTo(
        size.width * 0.68,
        size.height * 0.32,
        size.width * 0.68,
        size.height * 0.68,
        size.width * 0.83,
        size.height * 0.81,
      );
    canvas.drawPath(left, stroke);
    canvas.drawPath(right, stroke);
  }

  @override
  bool shouldRepaint(covariant _BallPainter oldDelegate) => false;
}
