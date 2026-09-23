import 'dart:math';

const tiltDownRadians = -0.50;
const tiltUpRadians = 0.50;
const tiltNeutralRadians = 0.28;
const tiltConfirmSamples = 3;
const tiltUprightY = 1.0;

class TiltReading {
  const TiltReading({required this.y, required this.z});

  final double y;
  final double z;
}

enum TiltCall { correct, pass }

class TiltArm {
  const TiltArm({this.latched = false, this.downStreak = 0, this.upStreak = 0});

  final bool latched;
  final int downStreak;
  final int upStreak;
}

class TiltDecision {
  const TiltDecision({required this.arm, this.call});

  final TiltArm arm;
  final TiltCall? call;
}

double tiltAngle(TiltReading reading) => atan2(reading.z, reading.y);

TiltDecision considerTilt(TiltArm arm, TiltReading reading) {
  final angle = tiltAngle(reading);
  final upright = reading.y > tiltUprightY;
  final neutral = upright && angle.abs() <= tiltNeutralRadians;
  final down = upright && angle <= tiltDownRadians;
  final up = upright && angle >= tiltUpRadians;

  if (arm.latched) {
    if (neutral) {
      return const TiltDecision(arm: TiltArm());
    }
    return TiltDecision(arm: arm);
  }

  if (down) {
    final streak = arm.downStreak + 1;
    if (streak >= tiltConfirmSamples) {
      return const TiltDecision(
        arm: TiltArm(latched: true),
        call: TiltCall.correct,
      );
    }
    return TiltDecision(arm: TiltArm(downStreak: streak));
  }

  if (up) {
    final streak = arm.upStreak + 1;
    if (streak >= tiltConfirmSamples) {
      return const TiltDecision(
        arm: TiltArm(latched: true),
        call: TiltCall.pass,
      );
    }
    return TiltDecision(arm: TiltArm(upStreak: streak));
  }

  return const TiltDecision(arm: TiltArm());
}
