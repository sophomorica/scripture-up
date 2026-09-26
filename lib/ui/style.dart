import 'package:flutter/material.dart';

const ink = Color(0xFF0F1830);
const navy = Color(0xFF1B2A4A);
const cream = Color(0xFFF7F1E3);
const gold = Color(0xFFD4A84B);
const deepGold = Color(0xFFB8892E);
const goldLeaf = Color(0xFFE8B83E);
const amethyst = Color(0xFF8438C9);
const ember = Color(0xFFE2553B);

ThemeData scriptureTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ink,
    colorScheme: const ColorScheme.dark(
      primary: goldLeaf,
      onPrimary: navy,
      surface: ink,
      onSurface: cream,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: 'Barlow',
      bodyColor: cream,
      displayColor: cream,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: navy,
      contentTextStyle: TextStyle(
        fontFamily: 'Barlow',
        color: cream,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

TextStyle fraunces(
  double size,
  Color color, {
  bool italic = false,
  int weight = 900,
  double height = 0.95,
}) {
  return TextStyle(
    fontFamily: 'Fraunces',
    fontSize: size,
    height: height,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    fontWeight: weight >= 900 ? FontWeight.w900 : FontWeight.w800,
    color: color,
    fontVariations: [
      FontVariation.weight(weight.toDouble()),
      const FontVariation('opsz', 144),
      const FontVariation('SOFT', 100),
      const FontVariation('WONK', 0),
    ],
  );
}

TextStyle condensed(
  double size, {
  Color color = cream,
  FontWeight weight = FontWeight.w800,
  double tracking = 1.4,
  double height = 1,
}) {
  return TextStyle(
    fontFamily: 'BarlowCondensed',
    fontSize: size,
    fontWeight: weight,
    letterSpacing: tracking,
    color: color,
    height: height,
  );
}

TextStyle body(double size, {Color color = cream, FontWeight weight = FontWeight.w500}) {
  return TextStyle(
    fontFamily: 'Barlow',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.3,
  );
}

class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.chevron = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: deepGold,
              borderRadius: BorderRadius.circular(40),
            ),
            padding: const EdgeInsets.only(bottom: 4),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: goldLeaf,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: condensed(
                          26,
                          color: navy,
                          weight: FontWeight.w900,
                          tracking: 1.2,
                        ),
                      ),
                      if (chevron) ...[
                        const SizedBox(width: 8),
                        const UpChevron(color: navy, size: 18),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LineButton extends StatelessWidget {
  const LineButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: cream, width: 1.6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: condensed(22, color: cream, weight: FontWeight.w900, tracking: 1.2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UpChevron extends StatelessWidget {
  const UpChevron({super.key, required this.color, this.size = 16});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ChevronPainter(color),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  _ChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final head = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h * 0.48)
      ..lineTo(w * 0.72, h * 0.48)
      ..lineTo(w / 2, h * 0.22)
      ..lineTo(w * 0.28, h * 0.48)
      ..lineTo(0, h * 0.48)
      ..close();
    canvas.drawPath(head, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.38, h * 0.42, w * 0.24, h * 0.52),
        Radius.circular(w * 0.08),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ChevronPainter oldDelegate) =>
      oldDelegate.color != color;
}
