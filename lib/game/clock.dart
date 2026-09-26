String formatClock(Duration duration) {
  final capped = duration.inSeconds.clamp(0, 3599);
  final minutes = capped ~/ 60;
  final seconds = capped % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String formatMark(int milliseconds) {
  final total = milliseconds < 0 ? 0 : milliseconds ~/ 1000;
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
