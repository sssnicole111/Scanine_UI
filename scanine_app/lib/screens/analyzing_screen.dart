// lib/screens/analyzing_screen.dart
//
// Analyzing screen — sits between Capture / Upload and Result.
//
// Design: the user's photo fills a rounded card on the cloud background.
// A dark-brown dim (52 %, #2a1d12) fades in over the photo. A scan line sweeps
// top→bottom (0.5–1.7 s). Where Grad-CAM found heat, the dim has a soft hole
// and the cleared areas receive a warm amber tint. This is the only visual
// treatment; the Result screen's own jet-colour heatmap overlay is untouched.
//
// Timeline (seconds, kMinAnalyzeMs = 3000):
//   0.00–0.45  dim fades in
//   0.45–0.50  scan line appears
//   0.50–1.70  scan line sweeps, dim clears above the line
//   1.70–2.40  hold — cleared areas stay
//   2.40–3.00  handoff — dim/tint/line fade out while Result overlay fades in
//
// Data flow:
//   CameraScreen → AnalyzingScreen(imagePaths: [...])
//   AnalyzingScreen runs inference once, builds ScanTrace + renderHeatmap PNG.
//   → ResultScreen(result: ..., trace: ...)

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ml/analyzing/amber_overlay_image.dart';
import '../ml/analyzing/amber_scan_painter.dart';
import '../ml/analyzing/analyze_timeline.dart';
import '../ml/analyzing/scan_trace.dart';
import '../ml/classifier.dart';
import '../ml/heatmap.dart';
import '../models/screening_result.dart';
import '../theme/tokens.dart';
import 'camera_screen.dart' show CaptureProgressBar, kTotalFrames;
import 'result_screen.dart';

// ── Public constant ────────────────────────────────────────────────────────────
// Already defined in analyze_timeline.dart; re-exported here for callers.
// kMinAnalyzeMs = 3000 (ms)

// ── Private colours ───────────────────────────────────────────────────────────
const _cloudBg = Color(0xFFEEF1F6);
const _navy = Color(0xFF203661);
const _slate = Color(0xFF6B7090);

/// Minimum thumbnail decode width. Decoding at 120 px keeps memory tiny.
const _thumbDecodeWidth = 120;

// ══════════════════════════════════════════════════════════════════════════════

class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key, required this.imagePaths});

  final List<String> imagePaths;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen>
    with TickerProviderStateMixin {
  // ── Animation ──────────────────────────────────────────────────────────────
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: kMinAnalyzeMs),
  );

  // Derived animations, all driven from _ctrl (no extra setState per frame).
  late final Animation<double> _dimAnim; // opacity of the brown dim
  late final Animation<double> _scanAnim; // scan line position 0→1
  late final Animation<double> _handoffAnim; // result overlay fade-in

  // ── Inference state ────────────────────────────────────────────────────────
  bool _inferenceReady = false;
  bool _finished = false;
  bool _failed = false;
  bool _animStarted = false;

  ScanTrace? _trace;
  List<FrameResult>? _frames;
  String? _bestPath;
  Uint8List? _heatmapPng;
  bool _useTta = false;
  ui.Image? _overlayImage; // 112×112 heat image for painter

  // ── Frame time sampling (low-end detection) ────────────────────────────────
  final Stopwatch _sw = Stopwatch()..start();
  int _lastUs = -1;
  int _samples = 0;
  int _sumUs = 0;
  bool _lowEnd = false;

  // ── Thumbnails ─────────────────────────────────────────────────────────────
  final List<ui.Image?> _thumbs = [];
  final List<double> _thumbOpacity = [];

  // ── Photo sizing ───────────────────────────────────────────────────────────
  Size _photoSize = const Size(3, 4);

  // ── Reduced motion ─────────────────────────────────────────────────────────
  bool _reducedMotion = false;

  // ── Hero tag ───────────────────────────────────────────────────────────────
  static const _heroTag = 'scanine.analyzing.photo';

  @override
  void initState() {
    super.initState();

    // Build derived animations (intervals match the spec timeline).
    _dimAnim = CurvedAnimation(
      parent: _ctrl,
      // 0.00→0.45 s  / 3.0 s  = 0.0→0.15
      curve: const Interval(0.0, 0.15, curve: Curves.easeOut),
    );
    _scanAnim = CurvedAnimation(
      parent: _ctrl,
      // 0.50→1.70 s  / 3.0 s  = 0.1667→0.5667
      curve: const Interval(
        0.5 / 3.0,
        1.7 / 3.0,
        curve: _ScanEaseCurve(),
      ),
    );
    _handoffAnim = CurvedAnimation(
      parent: _ctrl,
      // 2.40→3.00 s  / 3.0 s  = 0.80→1.00
      curve: const Interval(2.4 / 3.0, 1.0, curve: Curves.easeInOut),
    );

    _ctrl.addListener(_sampleFrameTime);

    _resolvePhotoSize();
    final n = widget.imagePaths.length;
    _thumbs.addAll(List<ui.Image?>.filled(n, null));
    _thumbOpacity.addAll(List<double>.filled(n, 0.40));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animStarted) return;
    _animStarted = true;
    _reducedMotion = MediaQuery.of(context).disableAnimations;
    _scheduleScanning();
  }

  /// Gives the screen switch time to complete cleanly first so the transition
  /// is completely smooth and unburdened by heavy inference or animation loops.
  Future<void> _scheduleScanning() async {
    // 1. Wait for the route transition (switch screens) to complete.
    final route = ModalRoute.of(context);
    final routeAnim = route?.animation;
    if (routeAnim != null && !routeAnim.isCompleted) {
      final completer = Completer<void>();
      void listener(AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          routeAnim.removeStatusListener(listener);
          if (!completer.isCompleted) completer.complete();
        }
      }
      routeAnim.addStatusListener(listener);
      await completer.future.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {},
      );
    }

    if (!mounted) return;

    // 2. Calm switch settle pause: gives visual breathing room before scanning starts.
    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;

    // 3. Now start thumbnail decoding, inference, and the scanning animation.
    _decodeAllThumbs();
    _begin();
  }

  // ── Initialisation ─────────────────────────────────────────────────────────

  void _resolvePhotoSize() {
    if (widget.imagePaths.isEmpty) return;
    final file = File(widget.imagePaths.first);
    if (!file.existsSync()) return;
    FileImage(file)
        .resolve(ImageConfiguration.empty)
        .addListener(ImageStreamListener((info, _) {
      if (!mounted) return;
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (w > 0 && h > 0) {
        setState(() => _photoSize = Size(w, h));
      }
    }));
  }

  void _decodeAllThumbs() {
    final n = widget.imagePaths.length;
    for (var i = 0; i < n; i++) {
      _decodeThumb(i);
    }
  }

  Future<void> _decodeThumb(int index) async {
    try {
      final path = widget.imagePaths[index];
      final file = File(path);
      if (!file.existsSync()) return;

      // Decode at reduced resolution to keep memory tiny.
      final codec = await ui.instantiateImageCodecFromBuffer(
        await ui.ImmutableBuffer.fromFilePath(path),
        targetWidth: _thumbDecodeWidth,
      );
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _thumbs[index] = frame.image);
    } catch (_) {
      // Non-fatal — leave thumb slot null; shows grey placeholder.
    }
  }

  // ── Animation start ────────────────────────────────────────────────────────

  void _begin() {
    // Kick off inference in the background.
    unawaited(_runInference().catchError((Object e, StackTrace s) {
      _failInference(e, s);
    }));

    if (_reducedMotion) {
      // Skip sweep — just cross-fade the final composition.
      _ctrl.duration = const Duration(milliseconds: kReducedMotionMs);
      unawaited(
        _ctrl.animateTo(1.0, curve: Curves.easeInOut).whenComplete(_complete),
      );
      return;
    }

    // Normal mode: animate from 0 → some midpoint, park, then continue once
    // inference is ready. We animate all the way to handoff start (2.4/3.0).
    // If inference isnishes before that we continue straight to 1.0.
    unawaited(
      _ctrl
          .animateTo(
            2.4 / 3.0,
            duration: Duration(
              milliseconds: (kMinAnalyzeMs * 2.4 / 3.0).round(),
            ),
            curve: Curves.linear,
          )
          .whenComplete(_onHoldReached),
    );

    // Schedule thumbnail light-ups.
    for (var i = 0; i < widget.imagePaths.length; i++) {
      final delay = Duration(milliseconds: 550 + (i * 250));
      Future<void>.delayed(delay, () {
        if (!mounted) return;
        setState(() => _thumbOpacity[i] = 1.0);
      });
    }
  }

  void _onHoldReached() {
    if (!mounted || _failed || _finished) return;
    if (_inferenceReady) {
      _runToEnd();
    } else {
      // Inference is still running; wait (hold the hold-phase).
      // We poll via the inference completion callback (_maybeResume).
    }
  }

  void _maybeResume() {
    if (!mounted || _failed || _finished || _reducedMotion) return;
    if (!_ctrl.isAnimating || _inferenceReady) {
      _runToEnd();
    }
  }

  void _runToEnd() {
    if (_finished || _ctrl.isAnimating) return;
    final remaining = 1.0 - _ctrl.value;
    if (remaining <= 0) {
      _complete();
      return;
    }
    final ms = (remaining * kMinAnalyzeMs).round();
    unawaited(
      _ctrl
          .animateTo(1.0, duration: Duration(milliseconds: ms), curve: Curves.linear)
          .whenComplete(_complete),
    );
  }

  // ── Inference pipeline ─────────────────────────────────────────────────────

  Future<void> _runInference() async {
    final classifier = Classifier();
    if (!classifier.isReady) await classifier.load();

    final bool useTta = widget.imagePaths.length == 1;
    final frames = <FrameResult>[];

    if (useTta) {
      frames.addAll(await classifier.classifyFileTta(widget.imagePaths.first));
    } else {
      for (final path in widget.imagePaths) {
        frames.add(await classifier.classifyFile(path));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
    }

    // Determine winner and representative frame (index 0 for TTA; best-vote
    // frame for live burst — same logic as before).
    var bestIdx = 0;
    if (!useTta) {
      final counts = <String, int>{};
      for (final r in frames) {
        counts[r.label] = (counts[r.label] ?? 0) + 1;
      }
      final winner =
          counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      var bestConf = -1.0;
      for (var i = 0; i < frames.length; i++) {
        if (frames[i].label == winner && frames[i].confidence > bestConf) {
          bestConf = frames[i].confidence;
          bestIdx = i;
        }
      }
    }
    final best = frames[bestIdx];
    final bestPath =
        useTta ? widget.imagePaths.first : widget.imagePaths[bestIdx];

    // Build ScanTrace once, from the representative frame's cam values.
    final trace = ScanTrace.fromCam(
      cam: best.cam,
      camWidth: best.camW,
      camHeight: best.camH,
    );

    // Render jet-colour PNG for ResultScreen's Photo/Heatmap toggle.
    final Uint8List? heatmapPng = await renderHeatmap(
      photoPath: bestPath,
      cam: best.cam,
      camH: best.camH,
      camW: best.camW,
    );

    // Build the 112×112 overlay image for the painter (amber tint + dim mask).
    ui.Image? overlayImg;
    if (!trace.diffuse) {
      try {
        overlayImg = await AmberOverlayImage.fromTrace(trace);
      } catch (e, s) {
        developer.log(
          'AmberOverlayImage.fromTrace failed — diffuse fallback.',
          name: 'scanine.analyzing',
          error: e,
          stackTrace: s,
        );
      }
    }

    if (!mounted) {
      overlayImg?.dispose();
      return;
    }

    _frames = frames;
    _bestPath = bestPath;
    _heatmapPng = heatmapPng;
    _useTta = useTta;
    _trace = trace;
    _overlayImage = overlayImg;
    _inferenceReady = true;

    // If the animation has already reached the hold, resume immediately.
    _maybeResume();
  }

  // ── Frame time sampling (low-end mode) ────────────────────────────────────

  void _sampleFrameTime() {
    if (_lowEnd || _samples >= 10 || kDebugMode) return;
    final now = _sw.elapsedMicroseconds;
    if (_lastUs >= 0) {
      _sumUs += now - _lastUs;
      _samples++;
      if (_samples == 10 && _sumUs / 10 > 20000) {
        // > 20 ms/frame average → low-end device.
        _lowEnd = true;
      }
    }
    _lastUs = now;
  }

  // ── Error handling ─────────────────────────────────────────────────────────

  void _failInference(Object e, StackTrace s) {
    developer.log(
      'Analyzing inference failed — showing spinner then navigating.',
      name: 'scanine.analyzing',
      error: e,
      stackTrace: s,
    );
    if (!mounted || _failed) return;
    setState(() => _failed = true);
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (!mounted || _finished) return;
        _finished = true;
        _navigateToResult(
          frames: [],
          bestPath: widget.imagePaths.isNotEmpty ? widget.imagePaths.first : '',
          heatmapPng: null,
          useTta: false,
          trace: null,
        );
      }),
    );
  }

  void _complete() {
    if (!mounted || _finished) return;
    _finished = true;
    _navigateToResult(
      frames: _frames ?? [],
      bestPath: _bestPath ?? (widget.imagePaths.isNotEmpty ? widget.imagePaths.first : ''),
      heatmapPng: _heatmapPng,
      useTta: _useTta,
      trace: _trace,
    );
  }

  void _navigateToResult({
    required List<FrameResult> frames,
    required String bestPath,
    required Uint8List? heatmapPng,
    required bool useTta,
    required ScanTrace? trace,
  }) {
    if (!mounted) return;

    final result = ScreeningResult.fromFrames(
      frames: frames,
      imagePath: bestPath,
      heatmap: heatmapPng,
      tta: useTta,
    );

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ResultScreen(result: result, trace: trace),
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

  @override
  void dispose() {
    _ctrl.removeListener(_sampleFrameTime);
    _ctrl.dispose();
    _overlayImage?.dispose();
    for (final t in _thumbs) {
      t?.dispose();
    }
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _cloudBg,
        body: Semantics(
          liveRegion: true,
          label: 'Analyzing photo.',
          child: SafeArea(
            child: _failed
                ? Center(
                    child: CircularProgressIndicator(color: _navy),
                  )
                : _body(),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _header(),
          const SizedBox(height: 14),
          Expanded(child: _photoCard()),
          const SizedBox(height: 14),
          _hint(),
          const SizedBox(height: 14),
          _thumbRow(),
          const SizedBox(height: 14),
          _disclaimer(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Header: 5 segments (all filled navy) + "FRAME 5 / 5" ──────────────────

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // All 5 segments filled: pass currentIndex == totalFrames so every
        // segment gets the "captured" amber colour (matches camera screen at 5/5).
        CaptureProgressBar(
          currentIndex: kTotalFrames,
          totalFrames: kTotalFrames,
        ),
        Text(
          'FRAME $kTotalFrames / $kTotalFrames',
          style: const TextStyle(
            fontFamily: 'InstrumentSans',
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: Color(0xFF073858),
          ),
        ),
      ],
    );
  }

  // ── Photo card with scan effect ────────────────────────────────────────────

  Widget _photoCard() {
    return LayoutBuilder(
      builder: (context, box) {
        final cardSize = _fitPhoto(box.biggest);
        return Center(
          child: SizedBox(
            width: cardSize.width,
            height: cardSize.height,
            child: _card(cardSize),
          ),
        );
      },
    );
  }

  Widget _card(Size size) {
    final imagePath = widget.imagePaths.isNotEmpty ? widget.imagePaths.first : null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A14243B),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Photo — unaltered, never filtered or recoloured.
            if (imagePath != null && File(imagePath).existsSync())
              Hero(
                tag: _heroTag,
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
              )
            else
              Container(color: const Color(0xFF1A2434)),

            // 2 + 3 + 4. Dim, tint, scan line — one RepaintBoundary + one painter.
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  final scan = _scanAnim.value;
                  // scan line is null before and after the sweep interval.
                  final inSweep = _ctrl.value >= 0.5 / 3.0 &&
                      _ctrl.value <= 1.7 / 3.0;
                  return CustomPaint(
                    painter: AmberScanPainter(
                      scan: inSweep ? scan : null,
                      dimAlpha: _dimAnim.value,
                      handoff: _handoffAnim.value,
                      overlayImage: _overlayImage,
                      config: AmberPainterConfig(
                        lowEndMode: _lowEnd,
                        reducedMotion: _reducedMotion,
                      ),
                      repaint: _ctrl,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hint text ──────────────────────────────────────────────────────────────

  Widget _hint() {
    return Text(
      'Analyzing your dog\'s photo.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'InstrumentSans',
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: _slate,
        letterSpacing: -0.15,
      ),
    );
  }

  // ── 5-frame thumbnail row ──────────────────────────────────────────────────

  Widget _thumbRow() {
    const thumbW = 58.0;
    const thumbH = 74.0;
    const radius = 12.0;

    return Semantics(
      label: 'Five photos taken',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          widget.imagePaths.length,
          (i) {
            final img = i < _thumbs.length ? _thumbs[i] : null;
            final opacity = i < _thumbOpacity.length ? _thumbOpacity[i] : 0.40;

            return AnimatedOpacity(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              opacity: opacity,
              child: Stack(
                children: [
                  Container(
                    width: thumbW,
                    height: thumbH,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2434),
                      borderRadius: BorderRadius.circular(radius),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: img != null
                        ? _RawImageWidget(image: img)
                        : (File(widget.imagePaths[i]).existsSync()
                            ? Image.file(
                                File(widget.imagePaths[i]),
                                width: thumbW,
                                height: thumbH,
                                fit: BoxFit.cover,
                                cacheWidth: _thumbDecodeWidth,
                              )
                            : null),
                  ),
                  // Navy 2dp outline when lit (opacity >= 0.99).
                  if (opacity >= 0.99)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(radius),
                            border: Border.all(color: _navy, width: 2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────────────────────

  Widget _disclaimer() {
    return Text(
      'Preliminary screening only. Not a veterinary diagnosis.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'InstrumentSans',
        fontSize: 12,
        height: 1.3,
        color: _slate,
      ),
    );
  }

  // ── Layout helper: fit photo at natural aspect, no crop ───────────────────

  Size _fitPhoto(Size max) {
    final aspect = _photoSize.width / _photoSize.height;
    var w = max.width;
    var h = w / aspect;
    if (h > max.height) {
      h = max.height;
      w = h * aspect;
    }
    return Size(w, h);
  }
}

// ── Scan ease curve matching the spec: cubic-bezier(.45, 0, .25, 1) ──────────
class _ScanEaseCurve extends Curve {
  const _ScanEaseCurve();

  @override
  double transformInternal(double t) => _cubicBezier(0.45, 0.0, 0.25, 1.0, t);

  static double _cubicBezier(double x1, double y1, double x2, double y2, double x) {
    var lo = 0.0, hi = 1.0, p = x;
    for (var i = 0; i < 40; i++) {
      final cx = _sampleX(x1, x2, p);
      final diff = cx - x;
      if (diff.abs() < 1e-7) break;
      if (diff < 0) lo = p;
      else hi = p;
      p = (lo + hi) / 2;
    }
    return _sampleX(y1, y2, p);
  }

  static double _sampleX(double a, double b, double t) {
    final s = 1 - t;
    return 3 * s * s * t * a + 3 * s * t * t * b + t * t * t;
  }
}

// ── Raw ui.Image widget (avoids decode overhead of Image.memory) ──────────────
class _RawImageWidget extends StatelessWidget {
  const _RawImageWidget({required this.image});

  final ui.Image image;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RawImagePainter(image),
      child: const SizedBox.expand(),
    );
  }
}

class _RawImagePainter extends CustomPainter {
  const _RawImagePainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      _centreRect(image.width, image.height, size),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  static Rect _centreRect(int iw, int ih, Size s) {
    final scale = _max(s.width / iw, s.height / ih);
    final pw = iw * scale;
    final ph = ih * scale;
    return Rect.fromLTWH((s.width - pw) / 2, (s.height - ph) / 2, pw, ph);
  }

  static double _max(double a, double b) => a > b ? a : b;

  @override
  bool shouldRepaint(_RawImagePainter old) => old.image != image;
}