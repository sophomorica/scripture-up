import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../recording/moments.dart';
import '../recording/recording_store.dart';
import 'review_screen.dart';
import 'style.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.store});

  final RecordingStore store;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late List<File> _clips = widget.store.savedClips();

  void _reload() {
    setState(() => _clips = widget.store.savedClips());
  }

  Future<void> _delete(File file) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete this recording?'),
          content: const Text('The clip is removed from this phone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
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
      final sidecar = File(file.path.replaceAll('.mp4', '.json'));
      if (sidecar.existsSync()) {
        sidecar.deleteSync();
      }
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = _clips;
    return Scaffold(
      backgroundColor: ink,
      appBar: AppBar(
        backgroundColor: ink,
        foregroundColor: cream,
        title: Text('Saved videos', style: condensed(22, tracking: 1)),
      ),
      body: files.isEmpty
          ? const Center(
              key: Key('library-empty'),
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Saved clips show up here after you keep a round.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Barlow', fontSize: 18, height: 1.35, color: cream),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: files.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final file = files[index];
                final name = file.uri.pathSegments.last;
                return Material(
                  color: navy,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    leading: const Icon(Icons.play_circle_outline, color: goldLeaf),
                    title: Text(clipLabel(name), style: body(16, weight: FontWeight.w600)),
                    trailing: IconButton(
                      key: Key('delete-saved-$index'),
                      tooltip: 'Delete recording',
                      onPressed: () => _delete(file),
                      icon: const Icon(Icons.delete_outline, color: ember),
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _PlayerRoute(file: file),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _PlayerRoute extends StatefulWidget {
  const _PlayerRoute({required this.file});

  final File file;

  @override
  State<_PlayerRoute> createState() => _PlayerRouteState();
}

class _PlayerRouteState extends State<_PlayerRoute> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ReviewScreen(file: widget.file, marks: marksFor(widget.file));
  }
}

List<RoundMark> marksFor(File video) {
  final sidecar = File(video.path.replaceAll('.mp4', '.json'));
  if (!sidecar.existsSync()) {
    return const [];
  }
  try {
    final json = jsonDecode(sidecar.readAsStringSync()) as Map<String, Object?>;
    final marks = json['marks'] as List<Object?>? ?? const [];
    return [
      for (final entry in marks)
        if (entry is Map<String, Object?>) RoundMark.fromJson(entry),
    ];
  } catch (_) {
    return const [];
  }
}
