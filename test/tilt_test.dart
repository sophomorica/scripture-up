import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/game/tilt_detector.dart';
import 'package:scripture_up/game/tilt_sensor.dart';

TiltConfig get exact => const TiltConfig(alpha: 1);

AccelSample pose(double degrees, Duration at, {double gravity = 9.8}) {
  final radians = degrees * pi / 180;
  final plane = gravity * cos(radians);
  final z = gravity * sin(radians);
  return AccelSample(plane, 0, z, at);
}

TiltTick hold(
  TiltDetector detector,
  double degrees,
  Duration from,
  Duration span,
) {
  detector.ingest(pose(degrees, from));
  return detector.ingest(pose(degrees, from + span));
}

void main() {
  test('tilt down scores and tilt up passes only after a return to level', () {
    final detector = TiltDetector(config: exact);
    final down = hold(detector, -55, Duration.zero, const Duration(milliseconds: 60));
    expect(down.fired, TiltBand.correct);
    expect(down.phase, DetectorPhase.fired);

    final still = detector.ingest(pose(-55, const Duration(milliseconds: 200)));
    expect(still.fired, isNull);
    expect(still.phase, DetectorPhase.rearming);

    final early = detector.ingest(pose(0, const Duration(milliseconds: 900)));
    expect(early.fired, isNull);
    expect(early.phase, DetectorPhase.rearming);

    final rearmed = detector.ingest(pose(0, const Duration(milliseconds: 1100)));
    expect(rearmed.phase, DetectorPhase.neutral);

    final up = hold(
      detector,
      55,
      const Duration(milliseconds: 1100),
      const Duration(milliseconds: 60),
    );
    expect(up.fired, TiltBand.pass);
  });

  test('the hold must last 60 ms and a wobble under the threshold does not score', () {
    final detector = TiltDetector(config: exact);
    final short = hold(detector, -55, Duration.zero, const Duration(milliseconds: 59));
    expect(short.fired, isNull);
    expect(short.phase, DetectorPhase.neutral);

    final wobble = hold(detector, -40, const Duration(milliseconds: 100), const Duration(milliseconds: 200));
    expect(wobble.fired, isNull);

    final flat = hold(detector, -90, const Duration(milliseconds: 400), const Duration(milliseconds: 80));
    expect(flat.fired, TiltBand.correct);
    expect(flat.flat, isTrue);
  });

  test('a spike is smoothed and invertPitch flips the call', () {
    final smooth = TiltDetector();
    smooth.ingest(pose(0, Duration.zero));
    final spiked = smooth.ingest(pose(-90, const Duration(milliseconds: 20)));
    expect(spiked.theta, greaterThan(-30));
    expect(spiked.fired, isNull);

    final flipped = TiltDetector(config: const TiltConfig(alpha: 1, invertPitch: true));
    final call = hold(flipped, -55, Duration.zero, const Duration(milliseconds: 60));
    expect(call.fired, TiltBand.pass);
  });

  test('fifty scripted traces do not double-count or miss a tilt past 55 degrees', () {
    final detector = TiltDetector(config: exact);
    var fires = 0;
    var clock = Duration.zero;
    for (var i = 0; i < 20; i++) {
      final first = detector.ingest(pose(-58, clock));
      final second = detector.ingest(pose(-58, clock + const Duration(milliseconds: 80)));
      expect(first.fired, isNull);
      expect(second.fired, TiltBand.correct);
      fires += 1;
      final stuck = detector.ingest(pose(-58, clock + const Duration(milliseconds: 160)));
      expect(stuck.fired, isNull);
      clock += const Duration(milliseconds: 900);
      detector.ingest(pose(0, clock));
      clock += const Duration(milliseconds: 200);
      final back = detector.ingest(pose(0, clock));
      expect(back.fired, isNull);
      expect(back.phase, DetectorPhase.neutral);
      clock += const Duration(milliseconds: 40);
    }
    for (var i = 0; i < 15; i++) {
      detector.ingest(pose(60, clock));
      final fired = detector.ingest(pose(60, clock + const Duration(milliseconds: 70)));
      expect(fired.fired, TiltBand.pass);
      fires += 1;
      clock += const Duration(milliseconds: 900);
      detector.ingest(pose(0, clock));
      clock += const Duration(milliseconds: 200);
      expect(detector.ingest(pose(0, clock)).phase, DetectorPhase.neutral);
      clock += const Duration(milliseconds: 40);
    }
    for (var i = 0; i < 15; i++) {
      final dip = detector.ingest(pose(-52, clock));
      final leave = detector.ingest(pose(-10, clock + const Duration(milliseconds: 30)));
      expect(dip.fired, isNull);
      expect(leave.fired, isNull);
      clock += const Duration(milliseconds: 80);
    }
    expect(fires, 35);
  });

  test('a scripted sensor is the tilt interface the detector reads', () async {
    final script = Stream<AccelSample>.fromIterable([
      pose(0, Duration.zero),
      pose(-55, const Duration(milliseconds: 20)),
      pose(-55, const Duration(milliseconds: 80)),
    ]);
    final sensor = ScriptedTiltSensor(script);
    final detector = TiltDetector(config: exact);
    final fires = <TiltBand>[];
    await for (final sample in sensor.samples) {
      final tick = detector.ingest(sample);
      if (tick.fired != null) {
        fires.add(tick.fired!);
      }
    }
    expect(fires, [TiltBand.correct]);
  });
}
