import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ml/classifier.dart';
import '../ml/heatmap.dart';
import '../models/screening_result.dart';
import 'result_screen.dart';

/// Single persistent Classifier instance for the application lifecycle.
final Classifier scanine = Classifier();

enum AnalysisStage {
  quality,
  inference,
  heatmap,
  guidance,
  complete,
}

class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key, required this.imagePaths});

  final List<String> imagePaths;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen>
    with SingleTickerProviderStateMixin {
  AnalysisStage _currentStage = AnalysisStage.quality;
  String? _error;

  late final AnimationController _scanController;
  late final Animation<double> _scanPositionAnimation;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _scanPositionAnimation = Tween<double>(begin: 0.08, end: 0.92).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOutCubic),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOutSine),
    );

    _run();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      // ── Step 1: Quality filtering
      setState(() => _currentStage = AnalysisStage.quality);
      await Future<void>.delayed(const Duration(milliseconds: 650));

      if (!mounted) return;

      // ── Step 2: Multi-class inference
      setState(() => _currentStage = AnalysisStage.inference);
      final inferenceStart = DateTime.now();

      if (!scanine.isReady) {
        await scanine.load();
      }

      final bool useTta = widget.imagePaths.length == 1;
      final results = <FrameResult>[];

      if (useTta) {
        final views = await scanine.classifyFileTta(widget.imagePaths.first);
        results.addAll(views);
      } else {
        for (final path in widget.imagePaths) {
          final r = await scanine.classifyFile(path);
          results.add(r);
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }
      }

      final inferenceElapsed =
          DateTime.now().difference(inferenceStart).inMilliseconds;
      if (inferenceElapsed < 750) {
        await Future<void>.delayed(
            Duration(milliseconds: 750 - inferenceElapsed));
      }

      if (!mounted) return;

      // ── Step 3: Generating Grad-CAM heatmap
      setState(() => _currentStage = AnalysisStage.heatmap);
      final heatmapStart = DateTime.now();

      final counts = <String, int>{};
      for (final r in results) {
        counts[r.label] = (counts[r.label] ?? 0) + 1;
      }
      final winner =
          counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

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
      final bestPath =
          useTta ? widget.imagePaths.first : widget.imagePaths[bestIdx];

      final Uint8List? overlay = await renderHeatmap(
        photoPath: bestPath,
        cam: best.cam,
        camH: best.camH,
        camW: best.camW,
      );

      final heatmapElapsed =
          DateTime.now().difference(heatmapStart).inMilliseconds;
      if (heatmapElapsed < 750) {
        await Future<void>.delayed(
            Duration(milliseconds: 750 - heatmapElapsed));
      }

      if (!mounted) return;

      // ── Step 4: Retrieving first-response guidance
      setState(() => _currentStage = AnalysisStage.guidance);

      final result = ScreeningResult.fromFrames(
        frames: results,
        imagePath: bestPath,
        heatmap: overlay,
        tta: useTta,
      );

      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;

      setState(() => _currentStage = AnalysisStage.complete);
      await Future<void>.delayed(const Duration(milliseconds: 350));

      if (!mounted) return;
      _navigateToResult(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _navigateToResult(ScreeningResult result) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ResultScreen(result: result),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildActualImage() {
    if (widget.imagePaths.isNotEmpty) {
      final file = File(widget.imagePaths.first);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      }
    }

    return Container(
      color: const Color(0xFF16253B),
      child: const Center(
        child: Icon(
          Icons.pets_rounded,
          size: 44,
          color: Color(0x33DCA052),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF073858);
    const background = Color(0xFFF5FAFC);
    const maroon = Color(0xFF800020);

    final isSinglePhoto = widget.imagePaths.length == 1;
    final totalFrames = isSinglePhoto ? 5 : widget.imagePaths.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 52),

                // ── Processing On-Device Header ───────────────────
                const Text(
                  'PROCESSING ON-DEVICE',
                  style: TextStyle(
                    fontFamily: 'InstrumentSans',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isSinglePhoto ? 'Reading image frames' : 'Reading five frames',
                  style: const TextStyle(
                    fontFamily: 'InstrumentSans',
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.1,
                    height: 1.1,
                    color: navy,
                  ),
                ),

                const SizedBox(height: 32),

                // ── Actual Image with Hovering Scan Beam Effect ───
                Container(
                  height: 340,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x18142E53),
                        blurRadius: 26,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 1. The actual captured or uploaded photo
                        _buildActualImage(),

                        // 2. Subtle dark contrast gradient overlay
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x2E071A2E),
                                Color(0x47071A2E),
                              ],
                            ),
                          ),
                        ),

                        // 3. Hovering scan laser & illumination curtain
                        AnimatedBuilder(
                          animation: _scanController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: _HoveringScanPainter(
                                position: _scanPositionAnimation.value,
                                pulse: _pulseAnimation.value,
                              ),
                            );
                          },
                        ),

                        // 4. Subtle corner reticles
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: CustomPaint(
                              painter: _CardCornerReticlesPainter(
                                color: const Color(0xFFDCA052)
                                    .withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // ── Centered Process Steps (no checks, bold active process) ──
                if (_error == null) ...[
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _CenteredProcessStep(
                          title:
                              'Quality filtering — $totalFrames/$totalFrames passed',
                          state: _stepState(AnalysisStage.quality),
                        ),
                        const SizedBox(height: 16),
                        _CenteredProcessStep(
                          title: 'Running multi-class inference',
                          state: _stepState(AnalysisStage.inference),
                        ),
                        const SizedBox(height: 16),
                        _CenteredProcessStep(
                          title: 'Generating Grad-CAM heatmap',
                          state: _stepState(AnalysisStage.heatmap),
                        ),
                        const SizedBox(height: 16),
                        _CenteredProcessStep(
                          title: 'Retrieving first-response guidance',
                          state: _stepState(AnalysisStage.guidance),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9EBEF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: maroon.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Analysis error: $_error',
                      style: const TextStyle(
                        fontFamily: 'InstrumentSans',
                        fontSize: 14,
                        color: maroon,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    style: FilledButton.styleFrom(
                      backgroundColor: navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Return Home'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  _StepDisplayState _stepState(AnalysisStage step) {
    if (_currentStage.index > step.index) {
      return _StepDisplayState.completed;
    } else if (_currentStage.index == step.index) {
      return _StepDisplayState.inProgress;
    } else {
      return _StepDisplayState.pending;
    }
  }
}

enum _StepDisplayState {
  completed,
  inProgress,
  pending,
}

class _CenteredProcessStep extends StatelessWidget {
  const _CenteredProcessStep({
    required this.title,
    required this.state,
  });

  final String title;
  final _StepDisplayState state;

  @override
  Widget build(BuildContext context) {
    const navyActive = Color(0xFF073858);
    const slateDone = Color(0xFF475B73);
    const mutedPending = Color(0xFFB0BDD0);

    final isCurrent = state == _StepDisplayState.inProgress;
    final isDone = state == _StepDisplayState.completed;

    return Center(
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        style: TextStyle(
          fontFamily: 'InstrumentSans',
          fontSize: 15.5,
          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
          color: isCurrent
              ? navyActive
              : isDone
                  ? slateDone
                  : mutedPending,
          letterSpacing: -0.2,
          height: 1.35,
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Custom painter that renders a luminous hovering scan laser and trailing
/// illumination glow across the lesion image.
class _HoveringScanPainter extends CustomPainter {
  const _HoveringScanPainter({
    required this.position,
    required this.pulse,
  });

  final double position;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * position;
    const amber = Color(0xFFDCA052);
    const brightAmber = Color(0xFFFFE8B8);

    // 1. Soft illumination curtain trailing vertically around the scan beam
    const glowHeight = 36.0;
    final glowRect =
        Rect.fromLTRB(0, y - glowHeight, size.width, y + glowHeight);
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          amber.withValues(alpha: 0.0),
          amber.withValues(alpha: 0.16 * pulse),
          amber.withValues(alpha: 0.42 * pulse),
          amber.withValues(alpha: 0.16 * pulse),
          amber.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.32, 0.5, 0.68, 1.0],
      ).createShader(glowRect);

    canvas.drawRect(glowRect, glowPaint);

    // 2. Wide diffused laser aura
    final auraPaint = Paint()
      ..color = amber.withValues(alpha: 0.7 * pulse)
      ..strokeWidth = 5.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0)
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), auraPaint);

    // 3. Core glowing laser line
    final linePaint = Paint()
      ..color = brightAmber
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

    // 4. Glowing edge node markers
    final nodePaint = Paint()
      ..color = brightAmber
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(8, y), 3.0, nodePaint);
    canvas.drawCircle(Offset(size.width - 8, y), 3.0, nodePaint);
  }

  @override
  bool shouldRepaint(covariant _HoveringScanPainter oldDelegate) {
    return oldDelegate.position != position || oldDelegate.pulse != pulse;
  }
}

/// Subtle viewfinder bracket corners for the image card
class _CardCornerReticlesPainter extends CustomPainter {
  const _CardCornerReticlesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 14.0;

    // Top-Left ┌
    canvas.drawLine(const Offset(0, len), Offset.zero, paint);
    canvas.drawLine(Offset.zero, const Offset(len, 0), paint);

    // Top-Right ┐
    canvas.drawLine(Offset(size.width - len, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);

    // Bottom-Left └
    canvas.drawLine(
        Offset(0, size.height - len), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);

    // Bottom-Right ┘
    canvas.drawLine(Offset(size.width - len, size.height),
        Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - len),
        Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _CardCornerReticlesPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}