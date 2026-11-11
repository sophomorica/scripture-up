import 'dart:math';

import 'package:flutter/material.dart';

import 'style.dart';

class RingField extends StatelessWidget {
  const RingField({
    super.key,
    required this.color,
    required this.child,
    this.ringColor = Colors.white,
  });

  final Color color;
  final Color ringColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RingPainter(ringColor),
      child: ColoredBox(color: color, child: child),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22;
    for (var i = 0; i < 8; i++) {
      paint.color = color.withValues(alpha: 0.05 + (i % 3) * 0.02);
      canvas.drawCircle(center, 70 + i * 48, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.color != color;
}

class GoldInset extends StatelessWidget {
  const GoldInset({super.key, required this.child, this.radius = 28, this.inset = 14});

  final Widget child;
  final double radius;
  final double inset;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _InsetPainter(radius: radius, inset: inset),
      child: child,
    );
  }
}

class _InsetPainter extends CustomPainter {
  _InsetPainter({required this.radius, required this.inset});

  final double radius;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2),
      Radius.circular(radius),
    );
    final inner = RRect.fromRectAndRadius(
      outer.outerRect.deflate(5),
      Radius.circular(radius - 4),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..color = gold.withValues(alpha: 0.85),
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = gold.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant _InsetPainter oldDelegate) => false;
}

class Emblem extends StatelessWidget {
  const Emblem({super.key, required this.name, this.size = 36, this.color = cream});

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _EmblemPainter(name, color)),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  _EmblemPainter(this.name, this.color);

  final String name;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final goldPaint = Paint()..color = goldLeaf;
    final w = size.width;
    final h = size.height;
    switch (name) {
      case 'plates':
        for (var i = 0; i < 3; i++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(w * 0.12, h * (0.18 + i * 0.24), w * 0.76, h * 0.16),
              Radius.circular(w * 0.08),
            ),
            i == 0 ? goldPaint : paint,
          );
        }
      case 'section':
        final text = TextPainter(
          text: TextSpan(text: '§', style: fraunces(w * 0.9, color, weight: 800)),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, Offset((w - text.width) / 2, (h - text.height) / 2));
      case 'ridge':
        final path = Path()
          ..moveTo(0, h * 0.75)
          ..lineTo(w * 0.38, h * 0.28)
          ..lineTo(w * 0.55, h * 0.48)
          ..lineTo(w, h * 0.12)
          ..lineTo(w, h * 0.28)
          ..lineTo(w * 0.55, h * 0.64)
          ..lineTo(w * 0.38, h * 0.44)
          ..lineTo(0, h * 0.9)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawCircle(Offset(w * 0.78, h * 0.22), w * 0.08, goldPaint);
      case 'waves':
        final wave = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = h * 0.08
          ..strokeCap = StrokeCap.round
          ..color = color;
        for (var i = 0; i < 3; i++) {
          wave.color = i == 2 ? goldLeaf : color;
          final y = h * (0.28 + i * 0.22);
          final path = Path()
            ..moveTo(0, y)
            ..quadraticBezierTo(w * 0.25, y - h * 0.12, w * 0.5, y)
            ..quadraticBezierTo(w * 0.75, y + h * 0.12, w, y);
          canvas.drawPath(path, wave);
        }
      case 'person':
        canvas.drawCircle(Offset(w / 2, h * 0.32), w * 0.18, paint);
        canvas.drawArc(
          Rect.fromCenter(center: Offset(w / 2, h * 0.95), width: w * 0.8, height: h * 0.7),
          pi,
          pi,
          true,
          goldPaint,
        );
      case 'compass':
        final path = Path()
          ..moveTo(w / 2, 0)
          ..lineTo(w * 0.62, h * 0.38)
          ..lineTo(w, h / 2)
          ..lineTo(w * 0.62, h * 0.62)
          ..lineTo(w / 2, h)
          ..lineTo(w * 0.38, h * 0.62)
          ..lineTo(0, h / 2)
          ..lineTo(w * 0.38, h * 0.38)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.08, goldPaint);
      case 'scene':
        canvas.drawCircle(Offset(w / 2, h * 0.22), w * 0.1, goldPaint);
        canvas.drawCircle(Offset(w * 0.28, h * 0.62), w * 0.1, paint);
        canvas.drawCircle(Offset(w * 0.72, h * 0.62), w * 0.1, paint);
      case 'shield':
        final path = Path()
          ..moveTo(w / 2, h)
          ..lineTo(0, h * 0.28)
          ..lineTo(w * 0.18, 0)
          ..lineTo(w * 0.82, 0)
          ..lineTo(w, h * 0.28)
          ..close();
        canvas.drawPath(path, paint);
      case 'seed':
        canvas.drawOval(Rect.fromLTWH(w * 0.28, h * 0.08, w * 0.44, h * 0.84), paint);
        canvas.drawLine(
          Offset(w / 2, h * 0.16),
          Offset(w / 2, h * 0.84),
          Paint()
            ..color = goldLeaf
            ..strokeWidth = w * 0.06,
        );
      case 'ball':
        canvas.drawCircle(
          Offset(w / 2, h / 2),
          w * 0.42,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.08
            ..color = color,
        );
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.16, goldPaint);
      case 'star':
        final path = Path();
        for (var i = 0; i < 5; i++) {
          final angle = -pi / 2 + i * 4 * pi / 5;
          final point = Offset(w / 2 + cos(angle) * w * 0.48, h / 2 + sin(angle) * h * 0.48);
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
        canvas.drawPath(path, goldPaint);
      case 'colon':
        canvas.drawCircle(
          Offset(w / 2, h / 2),
          w * 0.42,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.06
            ..color = gold,
        );
        canvas.drawCircle(Offset(w / 2, h * 0.34), w * 0.07, goldPaint);
        canvas.drawCircle(Offset(w / 2, h * 0.66), w * 0.07, goldPaint);
      default:
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.2, goldPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter oldDelegate) =>
      oldDelegate.name != name || oldDelegate.color != color;
}

class Hatch extends StatelessWidget {
  const Hatch({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _HatchPainter(),
      child: child,
    );
  }
}

class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = 2;
    for (var x = -size.height; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Flakes extends StatelessWidget {
  const Flakes({
    super.key,
    required this.progress,
    this.count = 16,
    this.reach = 200,
    this.colors = const [goldLeaf, cream],
  });

  final double progress;
  final int count;
  final double reach;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FlakePainter(progress, count, reach, colors),
      child: const SizedBox.expand(),
    );
  }
}

class _FlakePainter extends CustomPainter {
  _FlakePainter(this.progress, this.count, this.reach, this.colors);

  final double progress;
  final int count;
  final double reach;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }
    final center = Offset(size.width / 2, size.height / 2);
    final random = Random(7);
    final flight = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    for (var i = 0; i < count; i++) {
      final angle = random.nextDouble() * pi * 2;
      final travel = reach * (0.25 + random.nextDouble() * 0.75);
      final spot = center + Offset(cos(angle), sin(angle)) * travel * flight;
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: (1 - progress).clamp(0, 1));
      canvas.save();
      canvas.translate(spot.dx, spot.dy);
      canvas.rotate(angle + progress * 2);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 8 + random.nextDouble() * 10, height: 5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FlakePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.count != count ||
      oldDelegate.reach != reach ||
      oldDelegate.colors != colors;
}

class Sunburst extends StatelessWidget {
  const Sunburst({super.key, this.degrees = 0});

  final double degrees;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BurstPainter(degrees), child: const SizedBox.expand());
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.degrees);

  static const _rays = 16;

  final double degrees;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final reach = size.longestSide;
    final halfWidth = pi / _rays / 2;
    final paint = Paint()..color = deepGold.withValues(alpha: 0.28);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(degrees * pi / 180);
    for (var i = 0; i < _rays; i++) {
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(-sin(halfWidth) * reach, -cos(halfWidth) * reach)
          ..lineTo(sin(halfWidth) * reach, -cos(halfWidth) * reach)
          ..close(),
        paint,
      );
      canvas.rotate(2 * pi / _rays);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) => oldDelegate.degrees != degrees;
}

class EdgeGlow extends StatelessWidget {
  const EdgeGlow({super.key, required this.intensity});

  final double intensity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _GlowPainter(intensity), child: const SizedBox.expand()),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.intensity);

  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) {
      return;
    }
    final depth = size.shortestSide * 0.2;
    final strong = ember.withValues(alpha: 0.75 * intensity.clamp(0.0, 1.0));
    final clear = ember.withValues(alpha: 0);
    void band(Rect rect, Alignment from, Alignment to) {
      canvas.drawRect(
        rect,
        Paint()..shader = LinearGradient(begin: from, end: to, colors: [strong, clear]).createShader(rect),
      );
    }

    band(Rect.fromLTWH(0, 0, depth, size.height), Alignment.centerLeft, Alignment.centerRight);
    band(Rect.fromLTWH(size.width - depth, 0, depth, size.height), Alignment.centerRight, Alignment.centerLeft);
    band(Rect.fromLTWH(0, 0, size.width, depth), Alignment.topCenter, Alignment.bottomCenter);
    band(Rect.fromLTWH(0, size.height - depth, size.width, depth), Alignment.bottomCenter, Alignment.topCenter);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) => oldDelegate.intensity != intensity;
}

class CheckDisc extends StatelessWidget {
  const CheckDisc({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: navy, shape: BoxShape.circle),
      child: CustomPaint(painter: _CheckPainter()),
    );
  }
}

class _CheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = goldLeaf
      ..strokeWidth = size.width * 0.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.26, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.7)
      ..lineTo(size.width * 0.74, size.height * 0.34);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
