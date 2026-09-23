import 'package:sensors_plus/sensors_plus.dart';

import 'tilt.dart';

Stream<TiltReading> deviceTilt() {
  return accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
      .map((event) => TiltReading(y: event.y, z: event.z));
}
