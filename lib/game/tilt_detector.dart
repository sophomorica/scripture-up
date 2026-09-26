import 'dart:math';

import 'tilt_sensor.dart';

class TiltConfig {
  const TiltConfig({
    this.fireDegrees = 50,
    this.levelDegrees = 20,
    this.flatDegrees = 60,
    this.hold = const Duration(milliseconds: 60),
    this.lockout = const Duration(milliseconds: 700),
    this.rearmDwell = const Duration(milliseconds: 200),
    this.armDwell = const Duration(milliseconds: 600),
    this.alpha = 0.25,
    this.invertPitch = false,
    this.minPlaneGravity = 8.0,
  });

  final double fireDegrees;
  final double levelDegrees;
  final double flatDegrees;
  final Duration hold;
  final Duration lockout;
  final Duration rearmDwell;
  final Duration armDwell;
  final double alpha;
  final bool invertPitch;
  final double minPlaneGravity;
}

enum TiltBand { correct, pass }

enum DetectorPhase { neutral, fired, rearming }

class TiltTick {
  const TiltTick({
    required this.theta,
    required this.plane,
    required this.phase,
    required this.flat,
    required this.level,
    this.fired,
  });

  final double theta;
  final double plane;
  final DetectorPhase phase;
  final bool flat;
  final bool level;
  final TiltBand? fired;
}

class TiltDetector {
  TiltDetector({this.config = const TiltConfig()});

  final TiltConfig config;

  double? _sx;
  double? _sy;
  double? _sz;
  DetectorPhase phase = DetectorPhase.neutral;
  TiltBand? _holding;
  Duration? _holdStart;
  Duration? _firedAt;
  Duration? _levelSince;

  void reset() {
    phase = DetectorPhase.neutral;
    _holding = null;
    _holdStart = null;
    _firedAt = null;
    _levelSince = null;
  }

  TiltTick ingest(AccelSample sample, {bool detect = true}) {
    final alpha = config.alpha;
    _sx = _sx == null ? sample.x : alpha * sample.x + (1 - alpha) * _sx!;
    _sy = _sy == null ? sample.y : alpha * sample.y + (1 - alpha) * _sy!;
    _sz = _sz == null ? sample.z : alpha * sample.z + (1 - alpha) * _sz!;
    final plane = sqrt(_sx! * _sx! + _sy! * _sy!);
    var theta = atan2(_sz!, plane) * 180 / pi;
    if (config.invertPitch) {
      theta = -theta;
    }
    final flat = theta.abs() > config.flatDegrees;
    final level =
        theta.abs() <= config.levelDegrees &&
        plane >= config.minPlaneGravity;
    TiltBand? fired;

    if (detect) {
      if (phase == DetectorPhase.fired) {
        phase = DetectorPhase.rearming;
      }
      if (phase == DetectorPhase.neutral) {
        final TiltBand? band = theta <= -config.fireDegrees
            ? TiltBand.correct
            : theta >= config.fireDegrees
            ? TiltBand.pass
            : null;
        if (band == null || band != _holding) {
          _holding = band;
          _holdStart = band == null ? null : sample.at;
        } else if (_holdStart != null &&
            sample.at - _holdStart! >= config.hold) {
          fired = band;
          phase = DetectorPhase.fired;
          _firedAt = sample.at;
          _holding = null;
          _holdStart = null;
          _levelSince = null;
        }
      } else if (phase == DetectorPhase.rearming) {
        final inLevel = theta.abs() <= config.levelDegrees;
        if (!inLevel) {
          _levelSince = null;
        } else {
          _levelSince ??= sample.at;
          final lockoutDone =
              _firedAt != null && sample.at - _firedAt! >= config.lockout;
          final dwellDone = sample.at - _levelSince! >= config.rearmDwell;
          if (lockoutDone && dwellDone) {
            phase = DetectorPhase.neutral;
            _firedAt = null;
            _levelSince = null;
            _holding = null;
            _holdStart = null;
          }
        }
      }
    }

    return TiltTick(
      theta: theta,
      plane: plane,
      phase: phase,
      flat: flat,
      level: level,
      fired: fired,
    );
  }
}
