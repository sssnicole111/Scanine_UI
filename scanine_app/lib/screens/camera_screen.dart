import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ml/image_quality.dart';
import '../ml/subject_check.dart';
import '../theme/routes.dart';
import '../theme/tokens.dart';
import '../widgets/scanine_mark.dart';
import 'analyzing_screen.dart';
import 'upload_screen.dart';

const int kTotalFrames = 5;

/// Live capture screen matching the unified Scanine camera design.
/// Features a light cloud backdrop, rounded viewfinder card with warm amber
/// framing reticles, functional Focus (Laplacian variance) & Light (mean pixel
/// intensity) quality assessments, and concentric navy shutter button.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _ready = false;
  bool _capturing = false; // true while the burst is running
  bool _isStreaming = false;
  bool _isProcessingFrame = false;

  /// True while the app is in the background and the camera is released.
  bool _suspended = false;
  int _lastSampleTimestamp = 0;

  // Live dog check while aiming: about once a second, one preview frame goes
  // to ML Kit. The hint shows after two "no dog" results in a row (so it
  // doesn't flicker) and clears on the first result that isn't.
  static const int _dogCheckEveryMs = 1000;
  static const String _noDogHint =
      "No dog in view. Point the camera at your dog's skin.";
  static const String _burstNoDogHint =
      "No dog found. Point the camera at your dog's skin.";
  static const String _releasedEarlyHint =
      'Keep holding the shutter until all five frames are in.';
  static const String _holdHint =
      'Press and hold the shutter over the affected area.';
  bool _dogCheckBusy = false;
  int _lastDogCheck = 0;

  // The burst runs only while the shutter is held. Letting go early cancels
  // it and discards the frames, so the five frames stay one continuous burst.
  bool _holding = false;
  int _noDogStreak = 0;
  bool _liveNoDog = false;

  // Tap to focus: where the ring is drawn (viewfinder coordinates), a counter
  // that restarts its animation, and the timer back to normal auto-focus.
  static const Duration _tapFocusHold = Duration(seconds: 5);
  Offset? _focusRing;

  // Front/back camera. The switch is hidden when the phone has only one.
  CameraLensDirection _lens = CameraLensDirection.back;
  bool _hasOtherCamera = false;
  bool _switching = false;
  int _focusTaps = 0;
  Timer? _focusResetTimer;
  FlashMode _flashMode = FlashMode.off;

  // Pinch to zoom. Capped at [_zoomCap]: past that, phone zoom is mostly
  // digital and only makes frames blurrier for the quality gate. The readout
  // shows while pinching and fades shortly after.
  static const double _zoomCap = 4.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _zoom = 1.0;
  double _zoomAtPinchStart = 1.0;
  bool _zoomBusy = false;
  bool _showZoom = false;
  Timer? _zoomHideTimer;

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final FlashMode nextMode;
      switch (_flashMode) {
        case FlashMode.off:
          nextMode = FlashMode.torch;
          break;
        case FlashMode.torch:
          nextMode = FlashMode.auto;
          break;
        case FlashMode.auto:
        default:
          nextMode = FlashMode.off;
          break;
      }
      await _controller!.setFlashMode(nextMode);
      if (mounted) {
        setState(() {
          _flashMode = nextMode;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _flashMode = (_flashMode == FlashMode.off) ? FlashMode.torch : FlashMode.off;
        });
      }
    }
  }

  int _frameIndex = 0; // how many frames have been accepted so far
  String? _errorTitle;
  String? _errorBody;
  String? _rejectWarning;
  final List<String> _shots = [];

  // Burst interval (ms): frames start at least this far apart. Per the paper,
  // ~350 ms captures successive moments of a moving animal. Taking a photo
  // usually takes longer than this on its own, so in practice there is no
  // extra wait; on faster phones this keeps the frames from bunching up.
  static const int _interFrameMs = 350;

  // Live quality state (Focus & Light)
  QualityAssessment _liveQuality = const QualityAssessment(
    blurScore: 120,
    lightScore: 110,
    focus: FocusStatus.sharp,
    light: LightStatus.adequate,
    isAcceptable: true,
    feedbackMessage: 'Hold steady over the affected area.',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      final anim = route?.animation;
      if (anim != null && !anim.isCompleted) {
        void listener(AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            anim.removeStatusListener(listener);
            if (mounted) _start();
          }
        }
        anim.addStatusListener(listener);
      } else {
        _start();
      }
    });
  }

  @override
  void dispose() {
    _focusResetTimer?.cancel();
    _zoomHideTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _stopLiveQualityStream();
    _controller?.dispose();
    super.dispose();
  }

  /// Releases the camera when the app leaves the foreground and reopens it on
  /// return (camera plugin guidance), so the preview never comes back frozen.
  /// An interrupted burst starts again from 0/5.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive) {
      // Not yet initialised (e.g. the permission prompt is showing): leave it.
      if (controller == null || !controller.value.isInitialized) return;
      _suspended = true;
      _focusResetTimer?.cancel();
      _isStreaming = false;
      _controller = null;
      controller.dispose();
      for (final p in _shots) {
        try {
          File(p).deleteSync();
        } catch (_) {}
      }
      _shots.clear();
      setState(() {
        _ready = false;
        _frameIndex = 0;
        _rejectWarning = null;
        _clearLiveDogHint();
        _focusRing = null;
        _flashMode = FlashMode.off; // a reopened camera starts with flash off
      });
    } else if (state == AppLifecycleState.resumed && _suspended) {
      _suspended = false;
      _start();
    }
  }

  Future<void> _start() async {
    setState(() {
      _errorTitle = null;
      _errorBody = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _fail(
          'No camera found',
          "This device doesn't have a camera the app can reach.",
        );
        return;
      }

      final chosen = cameras.firstWhere(
        (c) => c.lensDirection == _lens,
        orElse: () => cameras.first,
      );
      _hasOtherCamera =
          cameras.any((c) => c.lensDirection != chosen.lensDirection);

      final controller = CameraController(
        chosen,
        ResolutionPreset.high,
        enableAudio: false,
        // ML Kit reads NV21 preview frames directly; NV21 keeps the
        // luminance plane first, so the live focus/light check is unchanged.
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();

      // A freshly opened camera starts at its widest zoom.
      var minZoom = 1.0, maxZoom = 1.0;
      try {
        minZoom = await controller.getMinZoomLevel();
        maxZoom = math.min(await controller.getMaxZoomLevel(), _zoomCap);
      } catch (_) {}

      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _lens = chosen.lensDirection;
        _ready = true;
        _minZoom = minZoom;
        _maxZoom = math.max(minZoom, maxZoom);
        _zoom = minZoom;
        _showZoom = false;
      });

      _startLiveQualityStream();
    } on CameraException catch (e) {
      switch (e.code) {
        case 'CameraAccessDenied':
        case 'CameraAccessDeniedWithoutPrompt':
          _fail(
            'Camera access denied',
            'Allow camera access for Scanine in your device settings, then retry.',
          );
          break;
        case 'CameraAccessRestricted':
          _fail(
            'Camera restricted',
            'A device policy is blocking the camera on this phone.',
          );
          break;
        default:
          _fail("Couldn't open the camera", e.description ?? e.code);
      }
    } catch (e) {
      _fail("Couldn't open the camera", e.toString());
    }
  }

  /// Starts the live image stream to evaluate Focus (Laplacian variance)
  /// and Light (mean pixel intensity) in real time.
  void _startLiveQualityStream() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isStreaming) {
      return;
    }

    try {
      controller.startImageStream((CameraImage image) {
        final now = DateTime.now().millisecondsSinceEpoch;
        _maybeCheckDog(image, controller.description.sensorOrientation, now);
        // Sample every ~260ms to maintain smooth 60fps UI while providing reactive telemetry
        if (now - _lastSampleTimestamp < 260 ||
            _isProcessingFrame ||
            _capturing) {
          return;
        }
        _isProcessingFrame = true;
        _lastSampleTimestamp = now;

        final assessment = QualityGate.assessCameraImage(image);
        if (mounted) {
          setState(() {
            _liveQuality = assessment;
          });
        }
        _isProcessingFrame = false;
      });
      _isStreaming = true;
    } catch (_) {
      // Gracefully handle devices where startImageStream is unavailable
      _isStreaming = false;
    }
  }

  /// Sends one preview frame to the dog check if it's time and none is
  /// running. ML Kit works on its own thread, so the preview stays smooth.
  void _maybeCheckDog(CameraImage image, int sensorOrientation, int now) {
    if (_capturing || _dogCheckBusy || now - _lastDogCheck < _dogCheckEveryMs) {
      return;
    }
    _dogCheckBusy = true;
    _lastDogCheck = now;
    SubjectCheck.assessCameraFrame(image, sensorOrientation: sensorOrientation)
        .then((a) {
      _dogCheckBusy = false;
      if (!mounted || _capturing) return;
      _noDogStreak = a.isNotDog ? _noDogStreak + 1 : 0;
      final show = _noDogStreak >= 2;
      // A burst's "No dog found" is stale once a dog is back in view.
      final clearBurstWarning =
          !a.isNotDog && _rejectWarning == _burstNoDogHint;
      if (show != _liveNoDog || clearBurstWarning) {
        setState(() {
          _liveNoDog = show;
          if (clearBurstWarning) _rejectWarning = null;
        });
      }
    });
  }

  /// Focuses and meters on the tapped point. The preview is drawn with
  /// BoxFit.cover, so the tap is mapped through that crop to the camera's own
  /// 0..1 coordinates. After [_tapFocusHold] it returns to normal auto-focus.
  void _onPinchStart(ScaleStartDetails d) {
    _zoomAtPinchStart = _zoom;
  }

  /// Two-finger pinch zooms; one finger does nothing (taps still focus).
  /// Zoom is fixed during a burst so all five frames match.
  void _onPinchUpdate(ScaleUpdateDetails d) {
    final controller = _controller;
    if (d.pointerCount < 2 || controller == null || !_ready || _capturing) {
      return;
    }
    if (_maxZoom <= _minZoom) return;
    final next = (_zoomAtPinchStart * d.scale).clamp(_minZoom, _maxZoom);
    if ((next - _zoom).abs() < 0.01) return;
    _zoomHideTimer?.cancel();
    setState(() {
      _zoom = next;
      _showZoom = true;
    });
    _applyZoom();
  }

  void _onPinchEnd(ScaleEndDetails d) {
    if (!_showZoom) return;
    _zoomHideTimer?.cancel();
    _zoomHideTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showZoom = false);
    });
  }

  /// Sends the latest zoom to the camera, one call at a time; any pinch
  /// updates that arrive meanwhile are folded into the next call.
  Future<void> _applyZoom() async {
    if (_zoomBusy) return;
    _zoomBusy = true;
    try {
      double sent;
      do {
        sent = _zoom;
        await _controller?.setZoomLevel(sent);
      } while (mounted && (sent - _zoom).abs() >= 0.01);
    } catch (_) {
    } finally {
      _zoomBusy = false;
    }
  }

  Future<void> _onViewfinderTap(Offset local, Size box) async {
    final controller = _controller;
    if (controller == null || !_ready || _capturing) return;
    final v = controller.value;
    if (!v.isInitialized || !(v.focusPointSupported || v.exposurePointSupported)) {
      return;
    }
    // Portrait preview size, as laid out in the viewfinder.
    final pw = v.previewSize?.height ?? box.width;
    final ph = v.previewSize?.width ?? box.height;
    final scale = math.max(box.width / pw, box.height / ph);
    final ox = (box.width - pw * scale) / 2;
    final oy = (box.height - ph * scale) / 2;
    final point = Offset(
      ((local.dx - ox) / (pw * scale)).clamp(0.0, 1.0),
      ((local.dy - oy) / (ph * scale)).clamp(0.0, 1.0),
    );

    setState(() {
      _focusRing = local;
      _focusTaps++;
    });
    try {
      if (v.focusPointSupported) await controller.setFocusPoint(point);
      if (v.exposurePointSupported) await controller.setExposurePoint(point);
    } catch (_) {
      // Unsupported on this device or camera closing: ignore the tap.
    }

    _focusResetTimer?.cancel();
    _focusResetTimer = Timer(_tapFocusHold, _resetTapFocus);
  }

  /// Switches between the back and front camera. Ignored during a burst;
  /// frames already taken in an unfinished burst are dropped, since they came
  /// from the other camera.
  Future<void> _switchCamera() async {
    final old = _controller;
    if (old == null || !_ready || _capturing || _switching || !_hasOtherCamera) {
      return;
    }
    _switching = true;
    _focusResetTimer?.cancel();
    await _stopLiveQualityStream();
    for (final p in _shots) {
      try {
        File(p).deleteSync();
      } catch (_) {}
    }
    _shots.clear();
    setState(() {
      _ready = false;
      _controller = null;
      _frameIndex = 0;
      _rejectWarning = null;
      _focusRing = null;
      _flashMode = FlashMode.off;
      _clearLiveDogHint();
      _lens = _lens == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;
    });
    await old.dispose();
    await _start();
    _switching = false;
  }

  /// Back to normal continuous auto-focus and exposure.
  Future<void> _resetTapFocus() async {
    final controller = _controller;
    if (mounted) setState(() => _focusRing = null);
    if (controller == null || !controller.value.isInitialized) return;
    try {
      if (controller.value.focusPointSupported) {
        await controller.setFocusPoint(null);
      }
      if (controller.value.exposurePointSupported) {
        await controller.setExposurePoint(null);
      }
    } catch (_) {}
  }

  void _clearLiveDogHint() {
    _noDogStreak = 0;
    _liveNoDog = false;
  }

  /// Safely pauses the live image stream before taking a picture.
  Future<void> _stopLiveQualityStream() async {
    final controller = _controller;
    if (controller != null &&
        _isStreaming &&
        controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }
    _isStreaming = false;
  }

  Future<void> _goToUpload() async {
    await _stopLiveQualityStream();
    if (!mounted) return;
    await AppRoutes.push(context, (_) => const UploadScreen());
    if (mounted && !_capturing) {
      _startLiveQualityStream();
    }
  }

  /// Hint under the viewfinder: a burst's warning first, then the live
  /// "no dog in view", then the live focus/light guidance.
  String get _hintText =>
      _rejectWarning ??
      (_liveNoDog
          ? _noDogHint
          : (!_capturing && _liveQuality.isAcceptable
              ? _holdHint
              : _liveQuality.feedbackMessage));

  bool get _hintIsWarning => _rejectWarning != null || _liveNoDog;

  void _fail(String title, String body) {
    if (!mounted) return;
    setState(() {
      _errorTitle = title;
      _errorBody = body;
      _ready = false;
    });
  }

  void _onShutterDown() {
    _holding = true;
    if (!_capturing) _capture();
  }

  void _onShutterUp() => _holding = false;

  Future<void> _capture() async {
    final controller = _controller;
    if (_capturing) return;

    setState(() {
      _capturing = true;
      _rejectWarning = null;
      _clearLiveDogHint();
    });

    // Stop live quality stream so camera hardware is free for capture
    await _stopLiveQualityStream();

    int accepted = _frameIndex;
    int attempted = 0;

    // The dog check runs on the first good frame, alongside the rest of the
    // burst instead of holding it up. A "no dog" answer stops the burst.
    Future<SubjectAssessment>? dogCheck;
    SubjectAssessment? dogResult;

    Future<void> discardBurst(String hint) async {
      for (final p in _shots) {
        try {
          await File(p).delete();
        } catch (_) {}
      }
      _shots.clear();
      if (mounted) {
        setState(() {
          _frameIndex = 0;
          _rejectWarning = hint;
        });
      }
    }

    Future<void> stopForNoDog() => discardBurst(_burstNoDogHint);

    // When the previous photo started, to keep frames _interFrameMs apart.
    Stopwatch? sinceLastShot;

    try {
      // ── Burst: capture up to kTotalFrames good frames automatically ──
      // Each iteration tries to capture one frame. Frames that fail the
      // Image Quality Gate are silently retried rather than blocking on
      // user confirmation, because animals move and waiting for manual
      // retaps costs good frames.
      while (accepted < kTotalFrames) {
        if (!mounted || _suspended) return;
        if (dogResult?.isNotDog ?? false) {
          await stopForNoDog();
          return;
        }
        if (!_holding) {
          await discardBurst(_releasedEarlyHint);
          return;
        }

        final left = _interFrameMs - (sinceLastShot?.elapsedMilliseconds ?? _interFrameMs);
        if (left > 0) await Future<void>.delayed(Duration(milliseconds: left));
        if (!mounted || _suspended) return;
        if (!_holding) {
          await discardBurst(_releasedEarlyHint);
          return;
        }
        sinceLastShot = Stopwatch()..start();

        String shotPath;
        if (controller != null && _ready) {
          final shot = await controller.takePicture();
          shotPath = shot.path;
        } else {
          shotPath = 'sim_frame_${attempted + 1}.jpg';
        }
        attempted++;

        final assessment = await QualityGate.assessFile(shotPath);

        if (!assessment.isAcceptable) {
          // Reject this frame silently — delete the file, update hint
          try {
            final f = File(shotPath);
            if (await f.exists()) await f.delete();
          } catch (_) {}

          if (mounted) {
            setState(() {
              _liveQuality = assessment;
              _rejectWarning = assessment.feedbackMessage;
            });
          }

          continue;
        }

        if (_shots.isEmpty && dogCheck == null && controller != null && _ready) {
          final firstPath = shotPath;
          dogCheck = SubjectCheck.assessFile(firstPath)
            ..then((a) => dogResult = a);
        }

        // Frame passed the quality gate
        _shots.add(shotPath);
        accepted++;

        if (mounted) {
          setState(() {
            _frameIndex = accepted;
            _rejectWarning = null;
          });
        }

        if (accepted >= kTotalFrames) break;
      }

      // Every frame is in; screen only if the dog check agrees.
      final dog = dogResult ?? await dogCheck;
      if (!mounted || _suspended) return;
      if (dog?.isNotDog ?? false) {
        await stopForNoDog();
        return;
      }

      // ── All frames collected — proceed to analysis ──────────────
      await _stopLiveQualityStream();
      if (!mounted) return;
      AppRoutes.pushReplacement(
        context,
        (_) => AnalyzingScreen(imagePaths: List.of(_shots)),
      );
    } on CameraException catch (e) {
      // Backgrounding mid-burst disposes the camera; that's not an error.
      if (!_suspended) _fail("Couldn't capture a frame", e.description ?? e.code);
    } catch (e) {
      if (!_suspended) _fail('Capture error', e.toString());
    } finally {
      if (mounted) setState(() => _capturing = false);
      if (!_suspended) _startLiveQualityStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    const cloudBg = Color(0xFFEEF1F6);

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
        backgroundColor: cloudBg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              bottom: false, // bg bleeds behind nav bar
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // ── Header: 5 Progress Segments + Frame Label ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: 5-segment progress bar
                        _FrameProgressBar(
                          currentIndex: _frameIndex,
                          totalFrames: kTotalFrames,
                        ),

                        // Right: the frame count, then flash
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'FRAME $_frameIndex/$kTotalFrames',
                              style: const TextStyle(
                                fontFamily: 'InstrumentSans',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                color: Color(0xFF073858),
                              ),
                            ),
                            const SizedBox(width: 2),
                            _FlashButton(
                              flashMode: _flashMode,
                              onToggle: _toggleFlash,
                              // Front cameras usually have no flash.
                              enabled: !_capturing &&
                                  _ready &&
                                  _lens == CameraLensDirection.back,
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Viewfinder Card ───────────────────────────
                    Expanded(
                      child: Container(
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
                              // Deep navy camera background
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF16253B),
                                      Color(0xFF0F1A2A),
                                    ],
                                  ),
                                ),
                              ),

                              // Live camera preview feed
                              if (_ready && _controller != null)
                                FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width:
                                        _controller!
                                            .value
                                            .previewSize
                                            ?.height ??
                                        1080,
                                    height:
                                        _controller!.value.previewSize?.width ??
                                        1920,
                                    child: CameraPreview(_controller!),
                                  ),
                                ),

                              // Amber viewfinder framing corner reticles
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _CornerBracketsPainter(
                                    color: const Color(0xFFDCA052),
                                    strokeWidth: 2.8,
                                    cornerLength: 30.0,
                                    cornerRadius: 10.0,
                                    padding: 24.0,
                                  ),
                                ),
                              ),

                              // Tap to focus, with a ring where you tapped
                              Positioned.fill(
                                child: LayoutBuilder(
                                  builder: (context, box) => GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapUp: (d) => _onViewfinderTap(
                                      d.localPosition,
                                      box.biggest,
                                    ),
                                    onScaleStart: _onPinchStart,
                                    onScaleUpdate: _onPinchUpdate,
                                    onScaleEnd: _onPinchEnd,
                                    child: Stack(
                                      children: [
                                        // Zoom level while pinching: plain
                                        // white text, no background.
                                        Positioned(
                                          top: 30,
                                          left: 0,
                                          right: 0,
                                          child: IgnorePointer(
                                            child: AnimatedOpacity(
                                              opacity: _showZoom ? 1 : 0,
                                              duration: const Duration(
                                                milliseconds: 250,
                                              ),
                                              child: Text(
                                                '${_zoom.toStringAsFixed(1)}×',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontFamily: 'InstrumentSans',
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                  shadows: [
                                                    Shadow(
                                                      color: Color(0x80000000),
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (_focusRing != null)
                                          Positioned(
                                            left: _focusRing!.dx - 32,
                                            top: _focusRing!.dy - 32,
                                            child: _FocusRing(
                                              key: ValueKey(_focusTaps),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── Readouts: Focus & Light (Functional Telemetry) ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ReadoutItem(
                          label: 'FOCUS',
                          value: _liveQuality.focusLabel,
                          isGood: _liveQuality.isFocusGood,
                        ),
                        const SizedBox(width: 52),
                        _ReadoutItem(
                          label: 'LIGHT',
                          value: _liveQuality.lightLabel,
                          isGood: _liveQuality.isLightGood,
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Guidance Hint / Quality-Gate Feedback ─────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        _hintText,
                        key: ValueKey(_hintText),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'InstrumentSans',
                          fontSize: 13.5,
                          fontWeight: _hintIsWarning
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _hintIsWarning
                              ? const Color(0xFFD49339)
                              : const Color(0xFF5F708A),
                          letterSpacing: -0.15,
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ── Bottom Controls: Upload, Shutter & Flash ──────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _UploadButton(onTap: _goToUpload, enabled: !_capturing),
                        const SizedBox(width: 32),
                        _Shutter(
                          onHoldStart: _onShutterDown,
                          onHoldEnd: _onShutterUp,
                          busy: _capturing,
                          isReady: _liveQuality.isAcceptable,
                          acceptedFrames: _frameIndex,
                        ),
                        const SizedBox(width: 32),
                        // Kept in place (just invisible) on one-camera phones,
                        // so the shutter stays centred.
                        Visibility(
                          visible: _hasOtherCamera,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: _SwitchCameraButton(
                            onTap: _switchCamera,
                            enabled: _ready && !_capturing,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    // Sit above the nav bar
                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 8,
                    ),
                  ],
                ),
              ),
            ),

            // ── Error sheet overlay ─────────────────────────
            if (_errorTitle != null)
              _ErrorSheet(
                title: _errorTitle!,
                body: _errorBody ?? '',
                onRetry: _start,
                onUsePhoto: _goToUpload,
                onClose: () => Navigator.of(context).maybePop(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Public alias for [_FrameProgressBar] so external screens (e.g. Analyzing)
/// can show the same header widget without duplicating code.
///
/// Pass [currentIndex] = [totalFrames] to fill all segments navy (the
/// "FRAME 5 / 5 — all done" state shown on the Analyzing screen).
class CaptureProgressBar extends StatelessWidget {
  const CaptureProgressBar({
    super.key,
    required this.currentIndex,
    required this.totalFrames,
  });

  final int currentIndex;
  final int totalFrames;

  @override
  Widget build(BuildContext context) =>
      _FrameProgressBar(currentIndex: currentIndex, totalFrames: totalFrames);
}

/// 5-segment pill progress indicator stuck tightly together.
/// Captured = Warm Amber, Current = Deep Navy, Pending = Pale Gray-Blue.
class _FrameProgressBar extends StatelessWidget {
  const _FrameProgressBar({
    required this.currentIndex,
    required this.totalFrames,
  });

  final int currentIndex;
  final int totalFrames;

  @override
  Widget build(BuildContext context) {
    const amberCaptured = Color(0xFFD49339);
    const navyCurrent = Color(0xFF073858);
    const palePending = Color(0xFFDCE2ED);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalFrames, (i) {
        final Color color;
        if (i < currentIndex) {
          color = amberCaptured;
        } else if (i == currentIndex) {
          color = navyCurrent;
        } else {
          color = palePending;
        }

        return Container(
          width: 18,
          height: 4.5,
          margin: EdgeInsets.only(right: i == totalFrames - 1 ? 0 : 2.5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

/// Gallery upload icon button placed beside the shutter button.
class _UploadButton extends StatelessWidget {
  const _UploadButton({required this.onTap, this.enabled = true});

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF073858);

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: IconButton(
        onPressed: enabled ? onTap : null,
        icon: const Icon(Icons.photo_library_outlined, color: navy, size: 28),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        tooltip: 'Upload from gallery',
      ),
    );
  }
}

/// Flash toggle beside the frame count: just a small navy icon (amber when
/// the torch is on), no background. The tap area stays 36 px.
class _FlashButton extends StatelessWidget {
  const _FlashButton({
    required this.flashMode,
    required this.onToggle,
    this.enabled = true,
  });

  final FlashMode flashMode;
  final VoidCallback onToggle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String label) = switch (flashMode) {
      FlashMode.torch => (
          Icons.flash_on_rounded,
          const Color(0xFFDCA052),
          'Flash: On',
        ),
      FlashMode.auto => (
          Icons.flash_auto_rounded,
          const Color(0xFF073858),
          'Flash: Auto',
        ),
      _ => (Icons.flash_off_rounded, const Color(0xFF073858), 'Flash: Off'),
    };

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onToggle : null,
        child: SizedBox.square(
          dimension: 36,
          child: Center(
            child: AnimatedOpacity(
              opacity: enabled ? 1.0 : 0.35,
              duration: const Duration(milliseconds: 200),
              child: Icon(icon, size: 18, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// Telemetry metric column: small muted uppercase label + reactive value.
class _ReadoutItem extends StatelessWidget {
  const _ReadoutItem({
    required this.label,
    required this.value,
    required this.isGood,
  });

  final String label;
  final String value;
  final bool isGood;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'InstrumentSans',
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: Color(0xFF8E9CB2),
          ),
        ),
        const SizedBox(height: 3),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontFamily: 'InstrumentSans',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: isGood ? const Color(0xFF073858) : const Color(0xFFD49339),
          ),
          child: Text(value),
        ),
      ],
    );
  }
}


/// Custom painter for the 4 amber rounded corner reticles in the viewfinder.
class _CornerBracketsPainter extends CustomPainter {
  const _CornerBracketsPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLength,
    required this.cornerRadius,
    required this.padding,
  });

  final Color color;
  final double strokeWidth;
  final double cornerLength;
  final double cornerRadius;
  final double padding;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final left = padding;
    final top = padding;
    final right = size.width - padding;
    final bottom = size.height - padding;
    final r = cornerRadius;

    // Top-Left ┌
    final pathTL = Path()
      ..moveTo(left, top + cornerLength)
      ..lineTo(left, top + r)
      ..arcTo(
        Rect.fromCircle(center: Offset(left + r, top + r), radius: r),
        math.pi,
        math.pi / 2,
        false,
      )
      ..lineTo(left + cornerLength, top);
    canvas.drawPath(pathTL, paint);

    // Top-Right ┐
    final pathTR = Path()
      ..moveTo(right - cornerLength, top)
      ..lineTo(right - r, top)
      ..arcTo(
        Rect.fromCircle(center: Offset(right - r, top + r), radius: r),
        -math.pi / 2,
        math.pi / 2,
        false,
      )
      ..lineTo(right, top + cornerLength);
    canvas.drawPath(pathTR, paint);

    // Bottom-Right ┘
    final pathBR = Path()
      ..moveTo(right, bottom - cornerLength)
      ..lineTo(right, bottom - r)
      ..arcTo(
        Rect.fromCircle(center: Offset(right - r, bottom - r), radius: r),
        0,
        math.pi / 2,
        false,
      )
      ..lineTo(right - cornerLength, bottom);
    canvas.drawPath(pathBR, paint);

    // Bottom-Left └
    final pathBL = Path()
      ..moveTo(left + cornerLength, bottom)
      ..lineTo(left + r, bottom)
      ..arcTo(
        Rect.fromCircle(center: Offset(left + r, bottom - r), radius: r),
        math.pi / 2,
        math.pi / 2,
        false,
      )
      ..lineTo(left, bottom - cornerLength);
    canvas.drawPath(pathBL, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.padding != padding;
  }
}

/// Dual concentric circle shutter button matching the reference design:
/// Navy outer border ring + solid navy inner circle. Press and hold: the
/// burst runs while a finger is down. Raw pointer events, so a long hold is
/// never turned into a cancelled tap by the gesture arena.
class _Shutter extends StatefulWidget {
  const _Shutter({
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.busy,
    required this.isReady,
    this.acceptedFrames = 0,
  });

  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final bool busy;
  final bool isReady;
  final int acceptedFrames;

  @override
  State<_Shutter> createState() => _ShutterState();
}

class _ShutterState extends State<_Shutter> {
  bool _pressed = false;

  bool get _isTakingFrames => widget.busy || widget.acceptedFrames > 0;
  bool get _canTap => !widget.busy && widget.acceptedFrames < kTotalFrames;

  void _release() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    widget.onHoldEnd();
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF193863);
    const amberActive = Color(0xFFD49339);
    final clampedFrames = widget.acceptedFrames.clamp(0, 5);

    return Semantics(
      button: true,
      enabled: _canTap,
      label: 'Shutter button, press and hold',
      value: _isTakingFrames ? '$clampedFrames of 5 frames accepted' : null,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          if (!_canTap || _pressed) return;
          setState(() => _pressed = true);
          widget.onHoldStart();
        },
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: AnimatedScale(
          scale: _pressed || widget.busy ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: 78,
            height: 78,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: _isTakingFrames
                  ? SizedBox(
                      key: const ValueKey('segmented_shutter'),
                      width: 78,
                      height: 78,
                      child: Center(
                        child: ScanineMark(
                          size: 72,
                          acceptedFrames: clampedFrames,
                        ),
                      ),
                    )
                  : Container(
                      key: const ValueKey('classic_shutter'),
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.isReady ? navy : const Color(0xFF8E9CB2),
                          width: 3.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.busy
                                ? amberActive
                                : (widget.isReady
                                    ? navy
                                    : const Color(0xFF8E9CB2)),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Front/back camera switch in the bottom row, styled like the upload button.
class _SwitchCameraButton extends StatelessWidget {
  const _SwitchCameraButton({required this.onTap, required this.enabled});

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF073858);

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: IconButton(
        onPressed: enabled ? onTap : null,
        icon: const Icon(Icons.switch_camera_outlined, color: navy, size: 28),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        tooltip: 'Switch camera',
      ),
    );
  }
}

/// Tap-to-focus ring in the viewfinder's amber: shrinks into place, holds,
/// then fades.
class _FocusRing extends StatelessWidget {
  const _FocusRing({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1400),
        builder: (context, t, _) {
          final settle = Curves.easeOutCubic.transform((t / 0.25).clamp(0.0, 1.0));
          final fade = t < 0.7 ? 1.0 : 1.0 - (t - 0.7) / 0.3;
          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 1.25 - 0.25 * settle,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFDCA052), width: 2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The bottom sheet shown on camera permission or hardware error:
/// white surface, navy primary, amber icon chip.
class _ErrorSheet extends StatelessWidget {
  const _ErrorSheet({
    required this.title,
    required this.body,
    required this.onRetry,
    required this.onUsePhoto,
    required this.onClose,
  });

  final String title;
  final String body;
  final VoidCallback onRetry;
  final VoidCallback onUsePhoto;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0x94080D1A),
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(T.rLg)),
        ),
        padding: const EdgeInsets.fromLTRB(T.s6, T.s3, T.s6, T.s6),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x24101B34),
                    borderRadius: BorderRadius.circular(T.rFull),
                  ),
                ),
              ),
              const SizedBox(height: T.s5),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: T.amberBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.no_photography_outlined,
                      size: 18,
                      color: T.amber,
                    ),
                  ),
                  const SizedBox(width: T.s3),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'InstrumentSans',
                        fontSize: T.tMd,
                        fontWeight: FontWeight.w700,
                        color: T.ink,
                        height: 1.25,
                      ),
                    ),
                  ),
                  _GhostClose(onTap: onClose),
                ],
              ),
              const SizedBox(height: T.s3),
              Text(
                body,
                style: const TextStyle(
                  fontFamily: 'InstrumentSans',
                  fontSize: T.tSm,
                  color: T.ink2,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: T.s5),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: T.navy,
                    padding: const EdgeInsets.symmetric(vertical: T.s4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(T.rFull),
                    ),
                  ),
                  child: const Text(
                    'Try again',
                    style: TextStyle(
                      fontFamily: 'InstrumentSans',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: T.s2),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onUsePhoto,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: T.ink,
                    side: const BorderSide(color: T.line, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: T.s4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(T.rFull),
                    ),
                  ),
                  child: const Text(
                    'Use a photo instead',
                    style: TextStyle(
                      fontFamily: 'InstrumentSans',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostClose extends StatelessWidget {
  const _GhostClose({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(color: T.bg, shape: BoxShape.circle),
        child: const Icon(Icons.close, size: 15, color: T.ink3),
      ),
    );
  }
}
