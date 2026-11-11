import 'package:flutter/services.dart';

abstract class ScreenWake {
  Future<void> hold();
  Future<void> release();
}

class DeviceScreenWake implements ScreenWake {
  static const _channel = MethodChannel('com.narrowroad.scriptureup/screen');

  @override
  Future<void> hold() => _keepAwake(true);

  @override
  Future<void> release() => _keepAwake(false);

  Future<void> _keepAwake(bool on) async {
    try {
      await _channel.invokeMethod<void>('keepAwake', on);
    } catch (_) {}
  }
}

class NoScreenWake implements ScreenWake {
  @override
  Future<void> hold() async {}

  @override
  Future<void> release() async {}
}
