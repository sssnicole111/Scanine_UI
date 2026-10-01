import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../ml/classifier.dart';
import '../ml/heatmap.dart';
import '../models/screening_result.dart';
import '../theme/tokens.dart';
import 'result_screen.dart';

/// One interpreter for the whole app — loading the model costs about a
/// second, so it is kept alive between screenings.
final Classifier scanine = Classifier();

class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key, required this.imagePaths});

  final List<String> imagePaths;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  int _done = 0;
  String _stage = 'Loading model';
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      if (!scanine.isReady) {
        await scanine.load();
      }
      if (!mounted) return;
      setState(() => _stage = 'Reading frames');

      // One photo cannot give five real frames, so it gets five augmented
      // views instead. Five captured frames vote directly.
      final bool useTta = widget.imagePaths.length == 1;
      final results = <FrameResult>[];

      if (useTta) {
        if (!mounted) return;
        setState(() => _stage = 'Reading augmented views');
        final views = await scanine.classifyFileTta(widget.imagePaths.first);
        results.addAll(views);
        if (!mounted) return;
        setState(() => _done = results.length);
      } else {
        for (final path in widget.imagePaths) {
          final r = await scanine.classifyFile(path);
          results.add(r);
          if (!mounted) return;
          setState(() => _done = results.length);
          // let the progress bar paint between frames
          await Future<void>.delayed(const Duration(milliseconds: 16));
        }
      }

      if (!mounted) return;
      setState(() => _stage = 'Building heatmap');

      // Show the frame the model was most sure about, among those that
      // agreed with the majority vote.
      final counts = <String, int>{};
      for (final r in results) {
        counts[r.label] = (counts[r.label] ?? 0) + 1;
      }
      final winner =
          counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

      // Under TTA every view is the same photo, and only view 0 is
      // untransformed — its Grad-CAM is the only one that lines up with
      // the image on screen. For real frames, show the most confident one
      // that agreed with the vote.
      var bestIdx = 0;
      if (!useTta) {
        var bestConf = -1.0;
        for (var i = 0; i < results.length; i++) {
          if (results[i].label == winner && results[i].confidence > bestConf) {
            bestConf = results[i].confidence;
            bestIdx = i;
          }
        }
      }

      final best = results[bestIdx];
      final Uint8List? overlay = await renderHeatmap(
        photoPath: useTta
            ? widget.imagePaths.first
            : widget.imagePaths[bestIdx],
        cam: best.cam,
        camH: best.camH,
        camW: best.camW,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            result: ScreeningResult.fromFrames(
              frames: results,
              imagePath: useTta
                  ? widget.imagePaths.first
                  : widget.imagePaths[bestIdx],
              heatmap: overlay,
              tta: useTta,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    // A single upload is expanded into five augmented views.
    final total =
        widget.imagePaths.length == 1 ? 5 : widget.imagePaths.length;
    final progress = total == 0 ? 0.0 : _done / total;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: T.cardGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: T.s6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROCESSING ON-DEVICE',
                  style: TextStyle(
                    fontSize: T.tXs,
                    fontWeight: FontWeight.w700,
                    color: T.onDark2,
                    letterSpacing: 1.32,
                  ),
                ),
                const SizedBox(height: T.s3),
                Text(
                  _error == null ? _stage : 'Analysis failed',
                  style: const TextStyle(
                    fontSize: T.tXl,
                    fontWeight: FontWeight.w700,
                    color: T.onDark,
                    height: 1.15,
                    letterSpacing: -0.32,
                  ),
                ),
                const SizedBox(height: T.s8),
                if (_error == null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(T.rFull),
                    child: LinearProgressIndicator(
                      value: _done == 0 ? null : progress,
                      minHeight: 4,
                      backgroundColor: T.onDarkLine,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(T.amber),
                    ),
                  ),
                  const SizedBox(height: T.s3),
                  Text(
                    _done == 0
                        ? 'Preparing the interpreter'
                        : widget.imagePaths.length == 1
                            ? 'Augmented view $_done of $total'
                            : 'Frame $_done of $total',
                    style: const TextStyle(
                      fontSize: T.tSm,
                      color: T.onDark2,
                    ),
                  ),
                ] else ...[
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: T.tSm,
                      color: Color(0xFFFCA5A5),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: T.s6),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: T.navy,
                      padding: const EdgeInsets.symmetric(
                          horizontal: T.s6, vertical: T.s3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(T.rFull),
                      ),
                    ),
                    child: const Text('Back to home'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
