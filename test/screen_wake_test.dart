import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/feedback/screen_wake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the device wake lock asks the iOS idle timer to stay off, then back on', () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('com.narrowroad.scriptureup/screen');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final wake = DeviceScreenWake();
    await wake.hold();
    await wake.release();
    expect(calls.map((call) => call.method), ['keepAwake', 'keepAwake']);
    expect(calls.map((call) => call.arguments), [true, false]);
  });

  test('a phone without the native handler still plays the round', () async {
    final wake = DeviceScreenWake();
    await wake.hold();
    await wake.release();
  });
}
