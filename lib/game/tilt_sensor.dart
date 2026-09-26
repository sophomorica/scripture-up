import 'package:sensors_plus/sensors_plus.dart';

class AccelSample {
  const AccelSample(this.x, this.y, this.z, this.at);

  final double x;
  final double y;
  final double z;
  final Duration at;
}

abstract interface class TiltSensor {
  Stream<AccelSample> get samples;
}

class ScriptedTiltSensor implements TiltSensor {
  ScriptedTiltSensor(this.samples);

  @override
  final Stream<AccelSample> samples;
}

class DeviceTiltSensor implements TiltSensor {
  DeviceTiltSensor({Stopwatch? clock}) : _clock = clock ?? (Stopwatch()..start());

  final Stopwatch _clock;

  @override
  Stream<AccelSample> get samples {
    return accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
        .map(
          (event) => AccelSample(event.x, event.y, event.z, _clock.elapsed),
        );
  }
}
