// lib/debug/mlkit_eval_screen.dart
//
// Evaluation-only screen: runs ML Kit image labeling over a folder of photos
// and writes every label + confidence to results.jsonl, for offline threshold
// tuning on the PC. Never shown in the normal app; main.dart opens it only when
// started with --dart-define=MLKIT_EVAL=true. Does not touch the Scanine model.
//
// Photos:  <files>/mlkit_eval/<set>/<group>/*.jpg   (set = dog | not_dog)
// Output:  <files>/mlkit_eval/results.jsonl
// where <files> is the app's private files dir. Load photos with
//   adb push x.tar /data/local/tmp/ && adb shell run-as com.scanine.scanine_app \
//     tar -xf /data/local/tmp/x.tar -C files/mlkit_eval
// (debug builds only; some phones block writes to Android/data from adb).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

const _evalDir = '/data/user/0/com.scanine.scanine_app/files/mlkit_eval';

class MlkitEvalScreen extends StatefulWidget {
  const MlkitEvalScreen({super.key});

  @override
  State<MlkitEvalScreen> createState() => _MlkitEvalScreenState();
}

class _MlkitEvalScreenState extends State<MlkitEvalScreen> {
  String _status = 'Starting…';
  int _done = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final root = Directory(_evalDir);
    if (!root.existsSync()) {
      setState(() => _status = 'No photos found at $_evalDir');
      return;
    }
    final photos = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => RegExp(r'\.(jpe?g|png)$', caseSensitive: false)
            .hasMatch(f.path))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    setState(() {
      _total = photos.length;
      _status = 'Labeling…';
    });

    // Low threshold so the PC-side sweep sees weak labels too.
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.05),
    );
    final out = File('$_evalDir/results.jsonl').openWrite();
    final watch = Stopwatch();
    try {
      for (final f in photos) {
        final rel = f.path.substring(_evalDir.length + 1).split('/');
        watch
          ..reset()
          ..start();
        final labels = await labeler.processImage(InputImage.fromFilePath(f.path));
        watch.stop();
        out.writeln(jsonEncode({
          'set': rel[0],
          'group': rel.length > 2 ? rel[1] : '',
          'file': rel.last,
          'ms': watch.elapsedMilliseconds,
          'labels': [
            for (final l in labels) [l.label, double.parse(l.confidence.toStringAsFixed(4))]
          ],
        }));
        if (!mounted) return;
        setState(() => _done++);
      }
      await out.flush();
      if (mounted) setState(() => _status = 'DONE: $_done photos -> results.jsonl');
    } catch (e) {
      if (mounted) setState(() => _status = 'ERROR: $e');
    } finally {
      await out.close();
      await labeler.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ML Kit evaluation',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Text(_status, key: const Key('mlkit_eval_status')),
              const SizedBox(height: 8),
              Text('$_done / $_total'),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
            ],
          ),
        ),
      ),
    );
  }
}
