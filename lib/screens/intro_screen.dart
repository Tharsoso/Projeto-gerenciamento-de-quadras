import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';

class IntroScreen extends StatefulWidget {
  final VoidCallback onDone;
  const IntroScreen({super.key, required this.onDone});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {
  late final AnimationController _master;
  late final AnimationController _bounce;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _master = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..forward();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _master.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_ending) _finish();
    });
  }

  void _finish() {
    if (_ending) return;
    _ending = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _master.dispose();
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F8F3),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _GridBackdrop(),
          AnimatedBuilder(
            animation: _master,
            builder: (_, __) => CustomPaint(
              painter: _DiscPainter(
                t: Curves.easeOutCubic.transform(
                  (_master.value / 0.55).clamp(0, 1),
                ),
                floodProgress: Curves.easeInOutCubic.transform(
                  ((_master.value - 0.6) / 0.3).clamp(0, 1),
                ),
                brand: _master.value > 0.75,
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StaggerLine(
                    text: 'RESERVE',
                    controller: _master,
                    start: 0.05,
                    end: 0.35,
                    style: AppTheme.display(
                      size: _displaySize(context, 72, 120),
                      color: Colors.transparent,
                    ).copyWith(
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 2.5
                        ..color = AppColors.green,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _StaggerLine(
                    text: 'sua quadra',
                    controller: _master,
                    start: 0.15,
                    end: 0.45,
                    style: AppTheme.serif(
                      size: _displaySize(context, 54, 92),
                      color: AppColors.greenDark,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _BouncingBall(bounce: _bounce, master: _master),
                  const SizedBox(height: 20),
                  _StaggerLine(
                    text: 'em segundos',
                    controller: _master,
                    start: 0.28,
                    end: 0.55,
                    style: AppTheme.display(
                      size: _displaySize(context, 44, 66),
                      color: AppColors.green,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _BrandReveal(controller: _master),
          _Hud(controller: _master),
          Positioned(
            right: 20,
            bottom: 36,
            child: TextButton(
              onPressed: _finish,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.greenDark,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                textStyle: AppTheme.mono(
                  size: 11,
                  color: Colors.white,
                  letterSpacing: 1.4,
                ),
              ),
              child: const Text('PULAR ▸'),
            ),
          ),
        ],
      ),
    );
  }

  double _displaySize(BuildContext ctx, double min, double max) {
    final w = MediaQuery.sizeOf(ctx).width;
    return (w * 0.18).clamp(min, max);
  }
}

class _GridBackdrop extends StatelessWidget {
  const _GridBackdrop();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _GridPainter(), size: Size.infinite);
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE6ECE4)
      ..strokeWidth = 1;
    const step = 64.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final grad = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, Colors.white.withValues(alpha: 0)],
        stops: const [0.0, 0.7],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.3),
          radius: size.width * 0.7,
        ),
      );
    canvas.drawRect(Offset.zero & size, grad);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DiscPainter extends CustomPainter {
  final double t;
  final double floodProgress;
  final bool brand;
  _DiscPainter({
    required this.t,
    required this.floodProgress,
    required this.brand,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (brand) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = AppColors.ball,
      );
      return;
    }
    final cx = size.width / 2;
    final cy = size.height * 0.45;
    final maxR = math.min(size.width * 0.42, size.height * 0.3);
    final r = maxR * t;
    if (r > 0) {
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()..color = AppColors.ball,
      );
    }
    if (floodProgress > 0) {
      final floodR = math.max(size.width, size.height) * floodProgress * 1.2;
      canvas.drawCircle(
        Offset(cx, cy),
        floodR,
        Paint()..color = AppColors.ball,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DiscPainter old) =>
      old.t != t || old.floodProgress != floodProgress || old.brand != brand;
}

class _StaggerLine extends StatelessWidget {
  final String text;
  final AnimationController controller;
  final double start;
  final double end;
  final TextStyle style;
  const _StaggerLine({
    required this.text,
    required this.controller,
    required this.start,
    required this.end,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final chars = text.characters.toList();
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return ClipRect(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < chars.length; i++)
                _animChar(chars[i], i, chars.length),
            ],
          ),
        );
      },
    );
  }

  Widget _animChar(String c, int i, int n) {
    final progress = controller.value;
    final step = (end - start) / (n + 2);
    final charStart = start + i * step;
    final charEnd = charStart + step * 3;
    final local =
        ((progress - charStart) / (charEnd - charStart)).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(local);
    final hitOut = ((progress - 0.78) / 0.1).clamp(0.0, 1.0);
    final yUp = -1.1 * hitOut;
    final opacity = (1 - hitOut).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(0, (1.05 - eased) * 60 + yUp * 40),
      child: Opacity(
        opacity: opacity,
        child: Text(c, style: style),
      ),
    );
  }
}

class _BouncingBall extends StatelessWidget {
  final Animation<double> bounce;
  final Animation<double> master;
  const _BouncingBall({required this.bounce, required this.master});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([bounce, master]),
      builder: (_, __) {
        final y = -40 * Curves.easeOutQuad.transform(bounce.value);
        final appear = Curves.easeOutBack.transform(
          (master.value / 0.3).clamp(0.0, 1.0),
        );
        return Transform.translate(
          offset: Offset(0, y),
          child: Transform.scale(
            scale: appear,
            child: _TennisBall(size: 70),
          ),
        );
      },
    );
  }
}

class _TennisBall extends StatelessWidget {
  final double size;
  const _TennisBall({this.size = 32});
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

class _BrandReveal extends StatelessWidget {
  final AnimationController controller;
  const _BrandReveal({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final v = controller.value;
        if (v < 0.75) return const SizedBox.shrink();
        final local = ((v - 0.75) / 0.25).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(local);
        return Opacity(
          opacity: eased,
          child: Container(
            color: AppColors.ball.withValues(alpha: eased * 0.98),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ACE.',
                  style: AppTheme.display(
                    size: MediaQuery.sizeOf(context).width * 0.3,
                    color: AppColors.greenDark,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'RESERVA DE QUADRAS',
                  style: AppTheme.mono(
                    size: 13,
                    color: AppColors.greenDark,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Hud extends StatelessWidget {
  final AnimationController controller;
  const _Hud({required this.controller});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final ms = (controller.value * 3800).toInt();
        final s = (ms ~/ 1000).clamp(0, 59);
        final f = ((ms % 1000) ~/ 33).clamp(0, 29);
        final frame = (controller.value * 8).floor().clamp(0, 7) + 1;
        return Stack(
          children: [
            _corner(Alignment.topLeft),
            _corner(Alignment.topRight),
            _corner(Alignment.bottomLeft),
            _corner(Alignment.bottomRight),
            Positioned(
              top: 18,
              left: 20,
              child: Row(
                children: [
                  _RecDot(),
                  const SizedBox(width: 8),
                  Text(
                    'REC 00:${s.toString().padLeft(2, '0')}:${f.toString().padLeft(2, '0')}',
                    style: AppTheme.mono(
                      size: 11,
                      color: AppColors.greenDark,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 18,
              right: 20,
              child: Text(
                'FRAME 0$frame/08',
                style: AppTheme.mono(
                  size: 11,
                  color: AppColors.greenDark,
                  letterSpacing: 2,
                ),
              ),
            ),
            Positioned(
              bottom: 18,
              left: 20,
              child: Text(
                'ACE SAIBRO · BACKHAND ×0.25',
                style: AppTheme.mono(
                  size: 11,
                  color: AppColors.greenDark,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _corner(Alignment a) => Positioned(
        top: a.y < 0 ? 14 : null,
        bottom: a.y > 0 ? 14 : null,
        left: a.x < 0 ? 14 : null,
        right: a.x > 0 ? 14 : null,
        child: SizedBox(
          width: 26,
          height: 26,
          child: CustomPaint(painter: _CornerPainter(a)),
        ),
      );
}

class _CornerPainter extends CustomPainter {
  final Alignment a;
  _CornerPainter(this.a);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.greenDark
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (a.x < 0 && a.y < 0) {
      canvas.drawLine(Offset(0, size.height), const Offset(0, 0), p);
      canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), p);
    } else if (a.x > 0 && a.y < 0) {
      canvas.drawLine(Offset(0, 0), Offset(size.width, 0), p);
      canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), p);
    } else if (a.x < 0 && a.y > 0) {
      canvas.drawLine(Offset(0, 0), Offset(0, size.height), p);
      canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), p);
    } else {
      canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), p);
      canvas.drawLine(
          Offset(size.width, size.height), Offset(0, size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => false;
}

class _RecDot extends StatefulWidget {
  @override
  State<_RecDot> createState() => _RecDotState();
}

class _RecDotState extends State<_RecDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _c,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppColors.red,
            shape: BoxShape.circle,
          ),
        ),
      );
}
