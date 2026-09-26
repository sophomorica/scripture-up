import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../recording/moments.dart';
import 'style.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.file,
    required this.marks,
    this.initialSeek = Duration.zero,
  });

  final File file;
  final List<RoundMark> marks;
  final Duration initialSeek;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  VideoPlayerController? _controller;
  var _failed = false;
  var _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final controller = VideoPlayerController.file(widget.file);
    try {
      await _prepare(controller).timeout(const Duration(seconds: 5));
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
      }
      if (_controller == null) {
        try {
          await controller.dispose();
        } catch (_) {}
      }
    }
  }

  Future<void> _prepare(VideoPlayerController controller) async {
    await controller.initialize();
    await controller.seekTo(widget.initialSeek);
    controller.addListener(() {
      if (!mounted) {
        return;
      }
      setState(() => _position = controller.value.position);
    });
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _controller = controller);
    await controller.play();
  }

  Future<void> _seek(Duration position) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.seekTo(position);
    setState(() => _position = position);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final duration = controller?.value.duration ?? Duration.zero;
    return Scaffold(
      backgroundColor: ink,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _failed
                  ? const Center(
                      child: Text(
                        'This player can’t jump through the clip on this device.',
                        key: Key('seek-unavailable'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cream, fontSize: 18),
                      ),
                    )
                  : controller == null
                  ? const Center(child: CircularProgressIndicator(color: goldLeaf))
                  : AspectRatio(
                      aspectRatio: controller.value.aspectRatio == 0
                          ? 16 / 9
                          : controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
            ),
            ReviewScrubber(
              marks: widget.marks,
              position: _position,
              duration: duration,
              canSeek: controller != null,
              unavailable: _failed,
              onSeek: _seek,
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('DONE', style: condensed(18, tracking: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewScrubber extends StatelessWidget {
  const ReviewScrubber({
    super.key,
    required this.marks,
    required this.position,
    required this.duration,
    required this.canSeek,
    required this.unavailable,
    required this.onSeek,
  });

  final List<RoundMark> marks;
  final Duration position;
  final Duration duration;
  final bool canSeek;
  final bool unavailable;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds;
    final mark = _caption();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          if (mark != null)
            Text(
              '${mark.prompt} · ${mark.correct ? 'GOT IT' : 'PASS'}',
              style: condensed(16, tracking: 0.8),
            ),
          SizedBox(
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                LinearProgressIndicator(
                  value: position.inMilliseconds / total,
                  color: goldLeaf,
                  backgroundColor: navy,
                ),
                for (final entry in marks)
                  Align(
                    alignment: Alignment((entry.tMs / total).clamp(0, 1) * 2 - 1, 0),
                    child: GestureDetector(
                      key: Key('marker-${entry.cardId}'),
                      onTap: canSeek ? () => onSeek(jumpTarget(entry.tMs)) : null,
                      child: Container(
                        width: 8,
                        height: 18,
                        color: entry.correct ? goldLeaf : amethyst,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (unavailable)
            Text(
              'Seek isn’t available for this clip.',
              style: body(13, color: cream.withValues(alpha: 0.7)),
            ),
        ],
      ),
    );
  }

  RoundMark? _caption() {
    RoundMark? current;
    for (final mark in marks) {
      if (mark.tMs <= position.inMilliseconds) {
        current = mark;
      }
    }
    return current;
  }
}
