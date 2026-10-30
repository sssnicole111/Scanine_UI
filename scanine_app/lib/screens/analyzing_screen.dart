// lib/screens/analyzing_screen.dart
//
// Analyzing screen — sits between Capture / Upload and Result.
//
// Design: the user's photo fills a rounded card on the cloud background.
// A dark-brown dim fades in over the photo, a scan line sweeps top→bottom,
// and where Grad-CAM found heat the dim has a soft hole with an amber tint.
//
// What's real on this screen (vs. cosmetic):
//   • Each thumbnail lights up when ITS frame has actually been classified,
//     and shows that frame's label + confidence as a chip.
//   • The header counter and hint text follow the real pipeline stage.
//   • When all frames are in, the hint reads "N of M frames agree".
//
// Timeline (seconds, kAnalyzePaceMs = 5200) — animation is a FLOOR, not a gate:
//   0.00–0.60  dim fades in
//   0.80       waits (max kOverlayWait) until the heat overlay is built, so the
//              sweep reveals real data instead of popping it in afterwards
//   0.80–3.40  scan line sweeps
//   3.40–4.50  hold (waits here until inference is ready)
//   4.50–5.20  handoff into Result
//
// Safety rules:
//   • Navigation only happens once inference is ready (all paths, including
//     reduced motion) or after the failure path fires.
//   • Inference has a hard timeout (kInferenceTimeout) that routes to the
//     same failure path as a thrown error.
//   • All UI copy derives from imagePaths.length (1 photo = TTA mode).
//
// Data flow:
//   CameraScreen → AnalyzingScreen(imagePaths: [...])
//   → ResultScreen(result: ..., trace: ...)

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../ml/analyzing/amber_overlay_image.dart';
import '../ml/analyzing/amber_scan_painter.dart';
import '../ml/analyzing/scan_trace.dart';
import '../ml/classifier.dart';
import '../ml/heatmap.dart';
import '../models/screening_result.dart';
import 'camera_screen.dart' show CaptureProgressBar;
import 'result_screen.dart';

// ── Public constants ──────────────────────────────────────────────────────────
const int kAnalyzePaceMs = 5200;

@Deprecated('Pacing is stage-driven now; use kAnalyzePaceMs.')
const int kMinAnalyzeMs = 3000;

/// Max time the sweep waits at its start for the heat overlay to be built.
const Duration kOverlayWait = Duration(milliseconds: 2500);

// Low-end detection: measured on the raster thread (what lowEndMode actually
// reduces), after a warm-up so start-up work doesn't cause false positives.
const Duration _kLowEndWarmup = Duration(milliseconds: 800);
const int _kLowEndSamples = 15;
const int _kLowEndRasterUs = 12000;

/// Hard ceiling for model load + classification + heatmap. A hang past this
/// is treated exactly like a thrown error.
const Duration kInferenceTimeout = Duration(seconds: 30);

const double _kDimEnd = 0.6 / 5.2;
const double _kScanStart = 0.8 / 5.2;
const double _kScanEnd = 3.4 / 5.2;
const double _kHoldEnd = 4.5 / 5.2;

// Reduced-motion pacing: short hold floor, short handoff.
const int _kReducedHoldMs = 1200;
const int _kReducedHandoffMs = 400;

// ── Private colours ───────────────────────────────────────────────────────────
const _cloudBg = Color(0xFFEEF1F6);
const _navy = Color(0xFF203661);
const _amber = Color(0xFFC77D1A);
const _navyTint = Color(0x1A203661);
const _amberTint = Color(0x29C77D1A);
const _slate = Color(0xFF6B7090);

const _thumbDecodeWidth = 120;

enum _Stage { starting, classifying, heatmap, done }

/// Outcome of the vote across frames (burst) or augmented views (TTA).
class _Vote {
  const _Vote(this.label, this.agree, this.total, this.bestIdx);
  final String label;
  final int agree;
  final int total;
  final int bestIdx;
}

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
    duration: const Duration(milliseconds: kAnalyzePaceMs),
  );

  late final Animation<double> _dimAnim;
  late final Animation<double> _scanAnim;
  late final Animation<double> _handoffAnim;

  // ── Inference state ────────────────────────────────────────────────────────
  bool _inferenceReady = false;
  bool _finished = false;
  bool _failed = false;
  bool _animStarted = false;

  /// Completes when the overlay is built (or known to be unavailable).
  final Completer<void> _overlaySettled = Completer<void>();
  void _settleOverlay() {
    if (!_overlaySettled.isCompleted) _overlaySettled.complete();
  }

  _Stage _stage = _Stage.starting;
  int _framesDone = 0;

  ScanTrace? _trace;
  List<FrameResult>? _frames;
  String? _bestPath;
  Uint8List? _heatmapPng;
  ui.Image? _overlayImage;
  _Vote? _vote;

  /// Live per-thumbnail results. null = not classified yet.
  late final List<FrameResult?> _thumbResults =
      List<FrameResult?>.filled(widget.imagePaths.length, null);

  /// One photo → test-time augmentation; several → live burst.
  bool get _useTta => widget.imagePaths.length == 1;

  /// Safe to touch state / navigate.
  bool get _alive => mounted && !_failed && !_finished;

  // ── Low-end detection (raster-thread timings, after warm-up) ──────────────
  final Stopwatch _sw = Stopwatch();
  int _samples = 0;
  int _sumRasterUs = 0;
  bool _lowEnd = false;
  bool _timingsAttached = false;

  // ── Thumbnails ─────────────────────────────────────────────────────────────
  final List<ui.Image?> _thumbs = [];

  // ── Photo sizing ───────────────────────────────────────────────────────────
  Size _photoSize = const Size(3, 4);
  ImageStream? _photoStream;
  ImageStreamListener? _photoListener;

  bool _reducedMotion = false;

  static const _heroTag = 'scanine.analyzing.photo';

  @override
  void initState() {
    super.initState();

    _dimAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, _kDimEnd, curve: Curves.easeOut),
    );
    _scanAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(_kScanStart, _kScanEnd, curve: _ScanEaseCurve()),
    );
    _handoffAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(_kHoldEnd, 1.0, curve: Curves.easeInOut),
    );

    _resolvePhotoSize();
    _thumbs.addAll(List<ui.Image?>.filled(widget.imagePaths.length, null));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animStarted) return;
    _animStarted = true;
    _reducedMotion = MediaQuery.of(context).disableAnimations;
    _scheduleScanning();
  }

  Future<void> _scheduleScanning() async {
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
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    _decodeAllThumbs();
    _begin();
  }

  // ── Initialisation ─────────────────────────────────────────────────────────

  void _resolvePhotoSize() {
    if (widget.imagePaths.isEmpty) return;
    final file = File(widget.imagePaths.first);
    if (!file.existsSync()) return;

    final stream = FileImage(file).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, sync) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      stream.removeListener(listener);
      _photoStream = null;
      _photoListener = null;
      if (w <= 0 || h <= 0) return;
      if (sync) {
        _photoSize = Size(w, h);
      } else if (mounted) {
        setState(() => _photoSize = Size(w, h));
      }
    });
    _photoStream = stream;
    _photoListener = listener;
    stream.addListener(listener);
  }

  void _decodeAllThumbs() {
    for (var i = 0; i < widget.imagePaths.length; i++) {
      _decodeThumb(i);
    }
  }

  Future<void> _decodeThumb(int index) async {
    try {
      final path = widget.imagePaths[index];
      if (!File(path).existsSync()) return;
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
      // Non-fatal — grey placeholder stays.
    }
  }

  // ── Animation start ────────────────────────────────────────────────────────

  void _begin() {
    _attachTimings();

    unawaited(
      _runInference()
          .timeout(kInferenceTimeout)
          .catchError((Object e, StackTrace s) => _failInference(e, s)),
    );

    unawaited(_runAnimation());
  }

  Future<void> _runAnimation() async {
    if (_reducedMotion) {
      await _ctrl.animateTo(
        _kHoldEnd,
        duration: const Duration(milliseconds: _kReducedHoldMs),
        curve: Curves.easeInOut,
      );
      _tryHandoff();
      return;
    }

    // 1. Dim fades in.
    await _ctrl.animateTo(
      _kScanStart,
      duration: Duration(milliseconds: (kAnalyzePaceMs * _kScanStart).round()),
      curve: Curves.linear,
    );
    if (!_alive) return;

    // 2. Wait (bounded) for the heat overlay so the sweep reveals real data.
    await _overlaySettled.future.timeout(kOverlayWait, onTimeout: () {});
    if (!_alive) return;

    // 3. Sweep + hold, then hand off once inference is ready.
    await _ctrl.animateTo(
      _kHoldEnd,
      duration: Duration(
        milliseconds: (kAnalyzePaceMs * (_kHoldEnd - _kScanStart)).round(),
      ),
      curve: Curves.linear,
    );
    _tryHandoff();
  }

  /// Called when the hold animation ends AND when inference finishes —
  /// whichever comes last triggers the handoff.
  void _tryHandoff() {
    if (!_alive || !_inferenceReady) return;
    if (_ctrl.isAnimating || _ctrl.value < _kHoldEnd) return;
    _runToEnd();
  }

  void _runToEnd() {
    if (_finished || _ctrl.isAnimating) return;
    final remaining = 1.0 - _ctrl.value;
    if (remaining <= 0) {
      _complete();
      return;
    }
    final ms = _reducedMotion
        ? _kReducedHandoffMs
        : (remaining * kAnalyzePaceMs).round();
    unawaited(
      _ctrl
          .animateTo(1.0,
              duration: Duration(milliseconds: ms), curve: Curves.linear)
          .whenComplete(_complete),
    );
  }

  // ── Inference pipeline ────────────────────────────────────────────────────

  void _set(VoidCallback fn) {
    if (_alive) setState(fn);
  }

  _Vote _tally(List<FrameResult> frames, {required bool tta}) {
    final counts = <String, int>{};
    for (final r in frames) {
      counts[r.label] = (counts[r.label] ?? 0) + 1;
    }
    final winner =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    var bestIdx = 0;
    if (!tta) {
      var bestConf = -1.0;
      for (var i = 0; i < frames.length; i++) {
        if (frames[i].label == winner && frames[i].confidence > bestConf) {
          bestConf = frames[i].confidence;
          bestIdx = i;
        }
      }
    }
    return _Vote(winner, counts[winner]!, frames.length, bestIdx);
  }

  Future<void> _runInference() async {
    final classifier = Classifier();
    if (!classifier.isReady) await classifier.load();
    if (!_alive) return;

    _set(() => _stage = _Stage.classifying);

    final tta = _useTta;
    final frames = <FrameResult>[];

    if (tta) {
      frames.addAll(await classifier.classifyFileTta(widget.imagePaths.first));
      if (!_alive) return;
      if (frames.isNotEmpty) {
        _set(() => _thumbResults[0] = frames.first);
      }
    } else {
      for (var i = 0; i < widget.imagePaths.length; i++) {
        final r = await classifier.classifyFile(widget.imagePaths[i]);
        if (!_alive) return;
        frames.add(r);
        _set(() {
          _thumbResults[i] = r;
          _framesDone = i + 1;
        });
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
    }

    final vote = _tally(frames, tta: tta);
    final best = frames[vote.bestIdx];
    final bestPath =
        tta ? widget.imagePaths.first : widget.imagePaths[vote.bestIdx];

    _set(() {
      _vote = vote;
      _stage = _Stage.heatmap;
    });

    final trace = ScanTrace.fromCam(
      cam: best.cam,
      camWidth: best.camW,
      camHeight: best.camH,
    );

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

    if (!_alive) {
      overlayImg?.dispose();
      _settleOverlay();
      return;
    }

    setState(() {
      _trace = trace;
      _overlayImage = overlayImg;
    });
    _settleOverlay();

    final Uint8List? heatmapPng = await renderHeatmap(
      photoPath: bestPath,
      cam: best.cam,
      camH: best.camH,
      camW: best.camW,
    );
    if (!_alive) return;

    setState(() {
      _frames = frames;
      _bestPath = bestPath;
      _heatmapPng = heatmapPng;
      _inferenceReady = true;
      _stage = _Stage.done;
    });

    _tryHandoff();
  }

  // ── Low-end detection ─────────────────────────────────────────────────────

  void _attachTimings() {
    if (kDebugMode || _timingsAttached) return;
    _timingsAttached = true;
    _sw
      ..reset()
      ..start();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _detachTimings() {
    if (!_timingsAttached) return;
    _timingsAttached = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void _onTimings(List<ui.FrameTiming> timings) {
    if (_sw.elapsed < _kLowEndWarmup) return;
    for (final t in timings) {
      _sumRasterUs += t.rasterDuration.inMicroseconds;
      if (++_samples >= _kLowEndSamples) break;
    }
    if (_samples >= _kLowEndSamples) {
      _lowEnd = _sumRasterUs / _samples > _kLowEndRasterUs;
      _detachTimings();
    }
  }

  // ── Error handling ─────────────────────────────────────────────────────────

  void _failInference(Object e, StackTrace s) {
    developer.log(
      e is TimeoutException
          ? 'Analyzing inference timed out.'
          : 'Analyzing inference failed.',
      name: 'scanine.analyzing',
      error: e,
      stackTrace: s,
    );
    if (!mounted || _failed || _finished) return;
    _ctrl.stop();
    _settleOverlay();
    setState(() => _failed = true);
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (!mounted || _finished) return;
        _finished = true;
        _navigateToResult(
          frames: [],
          bestPath:
              widget.imagePaths.isNotEmpty ? widget.imagePaths.first : '',
          heatmapPng: null,
          useTta: false,
          trace: null,
        );
      }),
    );
  }

  void _complete() {
    if (!mounted || _finished || _failed) return;
    _finished = true;
    _navigateToResult(
      frames: _frames ?? [],
      bestPath: _bestPath ??
          (widget.imagePaths.isNotEmpty ? widget.imagePaths.first : ''),
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
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _detachTimings();
    final ps = _photoStream, pl = _photoListener;
    if (ps != null && pl != null) ps.removeListener(pl);
    _ctrl.dispose();
    _overlayImage?.dispose();
    for (final t in _thumbs) {
      t?.dispose();
    }
    super.dispose();
  }

  // ── Copy derived from real state ───────────────────────────────────────────

  String _hintText() {
    final n = widget.imagePaths.length;
    switch (_stage) {
      case _Stage.starting:
        return 'Preparing screening model…';
      case _Stage.classifying:
        return _useTta
            ? 'Analyzing photo…'
            : 'Classifying frame ${math.min(_framesDone + 1, n)} of $n…';
      case _Stage.heatmap:
        return 'Building attention map…';
      case _Stage.done:
        return _agreementText();
    }
  }

  String _agreementText() {
    final v = _vote;
    if (v == null) return 'Finalizing screening summary…';
    final unit = _useTta ? 'views' : 'frames';
    final base = '${v.agree} of ${v.total} $unit agree';
    return v.agree == v.total ? base : '$base · mixed results';
  }

  String _headerText() {
    if (_useTta) return 'ANALYZED 1 / 1';
    return 'ANALYZED $_framesDone / ${widget.imagePaths.length}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _cloudBg,
        body: Semantics(
          liveRegion: true,
          label: 'Analyzing photo. ${_hintText()}',
          child: SafeArea(
            bottom: false, // bg bleeds behind nav bar
            child: _failed
                ? const Center(child: CircularProgressIndicator(color: _navy))
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
          // Sit above the system nav bar
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  // ── Header: progress bar + live counter ───────────────────────────────────

  Widget _header() {
    final n = widget.imagePaths.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CaptureProgressBar(currentIndex: _useTta ? 1 : _framesDone, totalFrames: _useTta ? 1 : n),
        Text(
          _headerText(),
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: cardSize.width,
            height: cardSize.height,
            child: _card(cardSize),
          ),
        );
      },
    );
  }

  Widget _card(Size size) {
    final imagePath =
        widget.imagePaths.isNotEmpty ? widget.imagePaths.first : null;

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
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  final scan = _scanAnim.value;
                  final inSweep =
                      _ctrl.value >= _kScanStart && _ctrl.value <= _kScanEnd;
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

  // ── Hint text (stage-driven) ──────────────────────────────────────────────

  Widget _hint() {
    final text = _hintText();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Text(
        text,
        key: ValueKey(text),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'InstrumentSans',
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: _slate,
          letterSpacing: -0.15,
        ),
      ),
    );
  }

  // ── Thumbnail row: each lights up with its real label + confidence ────────

  Widget _thumbRow() {
    const thumbW = 58.0;
    const thumbH = 74.0;
    const radius = 12.0;

    return Semantics(
      label: _thumbSemantics(),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: widget.imagePaths.length == 1
            ? MainAxisAlignment.center
            : MainAxisAlignment.spaceBetween,
        children: List.generate(widget.imagePaths.length, (i) {
          final img = i < _thumbs.length ? _thumbs[i] : null;
          final result = i < _thumbResults.length ? _thumbResults[i] : null;
          final lit = result != null;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                opacity: lit ? 1.0 : 0.40,
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
                    if (lit)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(radius),
                              border: Border.all(
                                color: _isDissent(result) ? _amber : _navy,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              _chip(result, thumbW),
            ],
          );
        }),
      ),
    );
  }

  bool _isDissent(FrameResult? r) {
    final v = _vote;
    return r != null && v != null && r.label != v.label;
  }

  Widget _chip(FrameResult? r, double width) {
    final dissent = _isDissent(r);
    final color = dissent ? _amber : _navy;
    final pct = r == null ? '' : '${(r.confidence * 100).round()}%';

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: r == null ? 0 : 1,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 3),
        decoration: BoxDecoration(
          color: dissent ? _amberTint : _navyTint,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              r?.label ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'InstrumentSans',
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
            Text(
              pct.isEmpty ? ' ' : pct,
              style: TextStyle(
                fontFamily: 'InstrumentSans',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _thumbSemantics() {
    final parts = <String>[];
    for (var i = 0; i < _thumbResults.length; i++) {
      final r = _thumbResults[i];
      if (r != null) {
        parts.add(
            'Photo ${i + 1}: ${r.label}, ${(r.confidence * 100).round()} percent');
      }
    }
    return parts.isEmpty
        ? '${widget.imagePaths.length} photo(s) taken'
        : parts.join('. ');
  }

  // ── Disclaimer ─────────────────────────────────────────────────────────────

  Widget _disclaimer() {
    return const Text(
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

// ── Scan ease curve: cubic-bezier(.45, 0, .25, 1) ────────────────────────────
class _ScanEaseCurve extends Curve {
  const _ScanEaseCurve();

  @override
  double transformInternal(double t) => _cubicBezier(0.45, 0.0, 0.25, 1.0, t);

  static double _cubicBezier(
      double x1, double y1, double x2, double y2, double x) {
    var lo = 0.0, hi = 1.0, p = x;
    for (var i = 0; i < 40; i++) {
      final cx = _sampleX(x1, x2, p);
      final diff = cx - x;
      if (diff.abs() < 1e-7) break;
      if (diff < 0) {
        lo = p;
      } else {
        hi = p;
      }
      p = (lo + hi) / 2;
    }
    return _sampleX(y1, y2, p);
  }

  static double _sampleX(double a, double b, double t) {
    final s = 1 - t;
    return 3 * s * s * t * a + 3 * s * t * t * b + t * t * t;
  }
}

// ── Raw ui.Image widget ───────────────────────────────────────────────────────
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
    final scale = math.max(s.width / iw, s.height / ih);
    final pw = iw * scale;
    final ph = ih * scale;
    return Rect.fromLTWH((s.width - pw) / 2, (s.height - ph) / 2, pw, ph);
  }

  @override
  bool shouldRepaint(_RawImagePainter old) => old.image != image;
}