import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripture_up/recording/moments.dart';
import 'package:scripture_up/ui/review_screen.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FakeVideoPlatform extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>();
  final calls = <String>[];
  var position = Duration.zero;

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int playerId) async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> play(int playerId) async => calls.add('play');

  @override
  Future<void> pause(int playerId) async => calls.add('pause');

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    this.position = position;
    calls.add('seek ${position.inMilliseconds}');
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox.expand();
}

const marks = [
  RoundMark(cardId: 'a', prompt: 'Alma 32:21', clue: 'c', correct: true, tMs: 10000),
];

void main() {
  late FakeVideoPlatform platform;

  setUp(() {
    platform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  tearDown(() => platform.events.close());

  Future<void> openReview(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ReviewScreen(file: File('clip.mp4'), marks: marks)),
    );
    platform.events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 20),
        size: const Size(320, 240),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a marker tap after the clip has ended seeks and plays from there', (tester) async {
    await openReview(tester);
    expect(platform.calls, contains('play'));

    platform.events.add(VideoEvent(eventType: VideoEventType.completed));
    await tester.pump();
    await tester.pump();
    platform.calls.clear();

    await tester.tap(find.byKey(const Key('marker-a')));
    await tester.pump();
    await tester.pump();
    expect(platform.calls, ['seek 9000', 'play']);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping the video toggles play and pause', (tester) async {
    await openReview(tester);
    platform.calls.clear();

    await tester.tap(find.byKey(const Key('review-video')));
    await tester.pump();
    expect(platform.calls, ['pause']);

    await tester.tap(find.byKey(const Key('review-video')));
    await tester.pump();
    expect(platform.calls, ['pause', 'play']);

    await tester.pumpWidget(const SizedBox());
  });
}
