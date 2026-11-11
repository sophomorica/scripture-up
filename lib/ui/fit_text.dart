import 'package:flutter/material.dart';

double fitFontSize({
  required String text,
  required TextStyle style,
  required double width,
  required double height,
  required double min,
  required double max,
}) {
  bool fits(int size) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(fontSize: size.toDouble())),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: width);
    final ok = painter.height <= height;
    painter.dispose();
    return ok;
  }

  var low = min.floor();
  var high = max.floor();
  if (fits(high)) {
    return high.toDouble();
  }
  while (low < high) {
    final mid = (low + high + 1) ~/ 2;
    if (fits(mid)) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return low.toDouble();
}

class FitText extends StatefulWidget {
  const FitText(
    this.text, {
    super.key,
    required this.textKey,
    required this.style,
    this.min = 16,
    this.max = 44,
  });

  final String text;
  final Key textKey;
  final TextStyle style;
  final double min;
  final double max;

  @override
  State<FitText> createState() => _FitTextState();
}

class _FitTextState extends State<FitText> {
  String? _text;
  TextStyle? _style;
  double? _width;
  double? _height;
  var _size = 0.0;

  double _resolve(TextStyle style, BoxConstraints box) {
    final stale =
        _text != widget.text ||
        _style != style ||
        _width != box.maxWidth ||
        _height != box.maxHeight;
    if (stale) {
      _text = widget.text;
      _style = style;
      _width = box.maxWidth;
      _height = box.maxHeight;
      _size = fitFontSize(
        text: widget.text,
        style: style,
        width: box.maxWidth,
        height: box.maxHeight,
        min: widget.min,
        max: widget.max,
      );
    }
    return _size;
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(widget.style);
    return LayoutBuilder(
      builder: (context, box) {
        final size = _resolve(base, box);
        return Center(
          child: Text(
            widget.text,
            key: widget.textKey,
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: base.copyWith(fontSize: size),
          ),
        );
      },
    );
  }
}
