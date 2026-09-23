import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/game/tilt.dart';

const down = TiltReading(y: 6, z: -7.8);
const up = TiltReading(y: 6, z: 7.8);
const neutral = TiltReading(y: 9.8, z: 0);
const wobble = TiltReading(y: 9.8, z: -2);
const upsideDown = TiltReading(y: -9.8, z: 0.2);

TiltDecision hold(TiltArm arm, TiltReading reading) {
  var decision = TiltDecision(arm: arm);
  for (var i = 0; i < tiltConfirmSamples; i++) {
    decision = considerTilt(decision.arm, reading);
  }
  return decision;
}

void main() {
  test('tilt down scores and tilt up passes, after a return to upright', () {
    final armed = hold(const TiltArm(), down);
    expect(armed.call, TiltCall.correct);
    expect(armed.arm.latched, isTrue);

    final stillDown = considerTilt(armed.arm, down);
    expect(stillDown.call, isNull);
    expect(stillDown.arm.latched, isTrue);

    final released = considerTilt(stillDown.arm, neutral);
    expect(released.call, isNull);
    expect(released.arm.latched, isFalse);

    final passed = hold(released.arm, up);
    expect(passed.call, TiltCall.pass);
    expect(passed.arm.latched, isTrue);
  });

  test('a short wobble or an upside-down phone does not score', () {
    final wobbleDecision = hold(const TiltArm(), wobble);
    expect(wobbleDecision.call, isNull);
    expect(wobbleDecision.arm.latched, isFalse);

    final inverted = hold(const TiltArm(), upsideDown);
    expect(inverted.call, isNull);
    expect(inverted.arm.latched, isFalse);
  });

  test('two samples in the zone are not enough to score', () {
    var arm = const TiltArm();
    TiltCall? call;
    for (var i = 0; i < tiltConfirmSamples - 1; i++) {
      final decision = considerTilt(arm, down);
      arm = decision.arm;
      call = decision.call;
    }
    expect(call, isNull);
    expect(arm.latched, isFalse);
    expect(arm.downStreak, tiltConfirmSamples - 1);
  });
}
