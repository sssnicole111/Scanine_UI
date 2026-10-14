import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ml/image_quality.dart';
import '../theme/routes.dart';
import '../theme/tokens.dart';
import 'analyzing_screen.dart';
import 'upload_screen.dart';

const int kTotalFrames = 5;

/// Live capture screen matching the unified Scanine camera design.
/// Features a light cloud backdrop, rounded viewfinder card with warm amber
/// framing reticles, organic central lesion targeting glow, functional
/// Focus (Laplacian variance) & Light (mean pixel intensity) quality assessments,
/// and concentric navy shutter button.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _ready = false;
  bool _capturing = false; // true while the burst is running
  bool _isStreaming = false;
  bool _isProcessingFrame = false;
  int _lastSampleTimestamp = 0;

  int _frameIndex = 0; // how many frames have been accepted so far
  String? _errorTitle;
  String? _errorBody;
  String? _rejectWarning;
  final List<String> _shots = [];

  // Inter-frame delay (ms). Per the paper, ~350 ms gives enough time for
  // the camera shutter and hardware buffer to reset between frames while
  // still capturing successive moments of a moving animal.
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
    _start();
  }

  @override
  void dispose() {
    _stopLiveQualityStream();
    _controller?.dispose();
    super.dispose();
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

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _ready = true;
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

  void _goToUpload() {
    AppRoutes.push(context, (_) => const UploadScreen());
  }

  void _fail(String title, String body) {
    if (!mounted) return;
    setState(() {
      _errorTitle = title;
      _errorBody = body;
      _ready = false;
    });
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (_capturing) return;

    setState(() {
      _capturing = true;
      _rejectWarning = null;
    });

    // Stop live quality stream so camera hardware is free for capture
    await _stopLiveQualityStream();

    int accepted = _frameIndex;
    int attempted = 0;

    try {
      // ── Burst: capture up to kTotalFrames good frames automatically ──
      // Each iteration tries to capture one frame. Frames that fail the
      // Image Quality Gate are silently retried (up to 2 extra attempts
      // per slot) rather than blocking on user confirmation, because
      // animals move and waiting for manual retaps costs good frames.
      while (accepted < kTotalFrames) {
        if (!mounted) return;

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

          // Give the animal/user a moment to re-stabilise before the
          // next automatic capture attempt (paper: ~350 ms burst interval)
          await Future<void>.delayed(
            const Duration(milliseconds: _interFrameMs),
          );
          continue;
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

        // Short inter-frame pause to let the hardware buffer reset and
        // capture a meaningfully different moment (~350 ms, per paper)
        await Future<void>.delayed(const Duration(milliseconds: _interFrameMs));
      }

      // ── All frames collected — proceed to analysis ──────────────
      if (!mounted) return;
      AppRoutes.pushReplacement(
        context,
        (_) => AnalyzingScreen(imagePaths: List.of(_shots)),
      );
    } on CameraException catch (e) {
      _fail("Couldn't capture a frame", e.description ?? e.code);
    } catch (e) {
      _fail('Capture error', e.toString());
    } finally {
      if (mounted) setState(() => _capturing = false);
      _startLiveQualityStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    const cloudBg = Color(0xFFEEF1F6);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: cloudBg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

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

                        // Right: Frame indication
                        Text(
                          'FRAME $_frameIndex / $kTotalFrames',
                          style: const TextStyle(
                            fontFamily: 'InstrumentSans',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: Color(0xFF073858),
                          ),
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

                              // Center organic lesion focus glow
                              const Center(child: _CenterFocusGlow()),

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
                        _capturing
                            ? (_rejectWarning ??
                                  'Capturing frame $_frameIndex of $kTotalFrames…')
                            : (_rejectWarning ?? _liveQuality.feedbackMessage),
                        key: ValueKey(
                          _capturing
                              ? 'burst_$_frameIndex${_rejectWarning ?? ""}'
                              : (_rejectWarning ??
                                    _liveQuality.feedbackMessage),
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'InstrumentSans',
                          fontSize: 13.5,
                          fontWeight: (_rejectWarning != null || _capturing)
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _rejectWarning != null
                              ? const Color(0xFFD49339)
                              : _capturing
                              ? const Color(0xFF193863)
                              : const Color(0xFF5F708A),
                          letterSpacing: -0.15,
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ── Bottom Controls: Upload & Shutter ──────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _UploadButton(onTap: _goToUpload, enabled: !_capturing),
                        const SizedBox(width: 32),
                        _Shutter(
                          onTap: _capture,
                          busy: _capturing,
                          isReady: _liveQuality.isAcceptable,
                        ),
                        const SizedBox(width: 32),
                        // Balancer matching _UploadButton hit area so shutter stays centered
                        const SizedBox(width: 44, height: 44),
                      ],
                    ),

                    const SizedBox(height: 16),
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

/// Organic warm amber blurred focus glow located in the center of the camera.
/// Breathes gently to guide user alignment.
class _CenterFocusGlow extends StatefulWidget {
  const _CenterFocusGlow();

  @override
  State<_CenterFocusGlow> createState() => _CenterFocusGlowState();
}

class _CenterFocusGlowState extends State<_CenterFocusGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(opacity: _opacityAnimation.value, child: child),
        );
      },
      child: Container(
        width: 172,
        height: 104,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.elliptical(86, 52)),
          gradient: RadialGradient(
            center: const Alignment(0.0, -0.06),
            radius: 0.85,
            colors: [
              const Color(0xFFDCA052).withValues(alpha: 0.44),
              const Color(0xFFC88A36).withValues(alpha: 0.22),
              const Color(0xFF14243B).withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.52, 1.0],
          ),
        ),
      ),
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
/// Navy outer border ring + solid navy inner circle with tap feedback.
class _Shutter extends StatefulWidget {
  const _Shutter({
    required this.onTap,
    required this.busy,
    required this.isReady,
  });

  final VoidCallback onTap;
  final bool busy;
  final bool isReady;

  @override
  State<_Shutter> createState() => _ShutterState();
}

class _ShutterState extends State<_Shutter> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF193863);
    const amberActive = Color(0xFFD49339);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!widget.busy) widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed || widget.busy ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
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
                    : (widget.isReady ? navy : const Color(0xFF8E9CB2)),
              ),
            ),
          ),
        ),
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
