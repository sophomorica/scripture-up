import 'package:scripture_up/feedback/screen_wake.dart';

class FakeScreenWake implements ScreenWake {
  final events = <String>[];

  @override
  Future<void> hold() async => events.add('hold');

  @override
  Future<void> release() async => events.add('release');
}
