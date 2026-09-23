import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../recording/recording_store.dart';
import 'theme.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.store});

  final RecordingStore store;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late List<File> _clips = widget.store.savedClips();

  void _reload() {
    setState(() {
      _clips = widget.store.savedClips();
    });
  }

  Future<void> _delete(File file) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete this recording?'),
          content: const Text('The clip is removed from this phone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            ),
            TextButton(
              key: const Key('confirm-delete-saved'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (discard == true) {
      await widget.store.deleteSaved(file);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        title: const Text('Saved recordings'),
      ),
      body: Builder(
        builder: (context) {
          final files = _clips;
          if (files.isEmpty) {
            return const Center(
              key: Key('library-empty'),
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Saved clips show up here after you keep a round.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, height: 1.35),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: files.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final file = files[index];
              final name = file.uri.pathSegments.last;
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ClipPlayerScreen(file: file),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: line),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.play_circle_outline, color: pine),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            clipLabel(name),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          key: Key('delete-saved-$index'),
                          onPressed: () => _delete(file),
                          icon: const Icon(Icons.delete_outline, color: clay),
                          tooltip: 'Delete recording',
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ClipPlayerScreen extends StatefulWidget {
  const ClipPlayerScreen({super.key, required this.file});

  final File file;

  @override
  State<ClipPlayerScreen> createState() => _ClipPlayerScreenState();
}

class _ClipPlayerScreenState extends State<ClipPlayerScreen> {
  VideoPlayerController? _controller;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final controller = VideoPlayerController.file(widget.file);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.play();
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: night,
      appBar: AppBar(
        backgroundColor: night,
        foregroundColor: ivory,
        title: Text(clipLabel(widget.file.uri.pathSegments.last)),
      ),
      body: Center(
        child: _failed
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This clip could not be played.',
                  key: Key('clip-play-error'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ivory, fontSize: 18),
                ),
              )
            : controller == null
            ? const CircularProgressIndicator(color: ivory)
            : AspectRatio(
                aspectRatio: controller.value.aspectRatio == 0
                    ? 9 / 16
                    : controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
      ),
    );
  }
}
