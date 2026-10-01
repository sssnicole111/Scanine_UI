import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'analyzing_screen.dart';
import 'upload_screen.dart';

const int kTotalFrames = 5;

/// Live capture. Takes five frames, then hands the last one to the
/// analysing screen.
///
/// DEMO BUILD: frames are captured for real but nothing is classified.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _ready = false;
  bool _busy = false;
  int _frameIndex = 0;
  String? _errorTitle;
  String? _errorBody;
  final List<String> _shots = [];

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
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
        _fail('No camera found',
            "This device doesn't have a camera the app can reach.");
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
    } on CameraException catch (e) {
      switch (e.code) {
        case 'CameraAccessDenied':
        case 'CameraAccessDeniedWithoutPrompt':
          _fail('Camera access denied',
              'Allow camera access for Scanine in your device settings, then retry.');
          break;
        case 'CameraAccessRestricted':
          _fail('Camera restricted',
              'A device policy is blocking the camera on this phone.');
          break;
        default:
          _fail("Couldn't open the camera", e.description ?? e.code);
      }
    } catch (e) {
      _fail("Couldn't open the camera", e.toString());
    }
  }

  void _goToUpload() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UploadScreen()),
    );
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
    if (controller == null || !_ready || _busy) return;

    setState(() => _busy = true);
    try {
      final shot = await controller.takePicture();
      _shots.add(shot.path);

      final next = _frameIndex + 1;
      if (next >= kTotalFrames) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AnalyzingScreen(imagePaths: List.of(_shots)),
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _frameIndex = next);
    } on CameraException catch (e) {
      _fail("Couldn't capture that frame", e.description ?? e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Viewfinder ──────────────────────────────────
          if (_ready && _controller != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.previewSize?.height ?? 1080,
                height: _controller!.value.previewSize?.width ?? 1920,
                child: CameraPreview(_controller!),
              ),
            )
          else
            Container(decoration: const BoxDecoration(gradient: T.cardGradient)),

          // ── Overlay UI ──────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _ProgressBar(current: _frameIndex),
                _TopBar(
                  frameIndex: _frameIndex,
                  onUpload: _goToUpload,
                  onClose: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Center(
                    child: _errorTitle == null ? const _TargetBox() : null,
                  ),
                ),
                if (_errorTitle == null) _Shutter(onTap: _capture, busy: _busy),
                const SizedBox(height: T.s8),
              ],
            ),
          ),

          // ── Error sheet ─────────────────────────────────
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
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(T.s6, T.s5, T.s6, 0),
      child: Row(
        children: List.generate(kTotalFrames, (i) {
          final done = i < current;
          final active = i == current;
          return Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: i == kTotalFrames - 1 ? 0 : 6),
              decoration: BoxDecoration(
                color: done
                    ? T.success
                    : active
                        ? Colors.white
                        : T.onDarkLine,
                borderRadius: BorderRadius.circular(T.rFull),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.frameIndex,
    required this.onUpload,
    required this.onClose,
  });

  final int frameIndex;
  final VoidCallback onUpload;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(T.s6, T.s4, T.s6, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'FRAME ${frameIndex + 1}/$kTotalFrames',
            style: const TextStyle(
              fontSize: T.tXs,
              fontWeight: FontWeight.w700,
              color: T.onDark2,
              letterSpacing: 1.32,
            ),
          ),
          Row(
            children: [
              _GhostIconButton(
                  icon: Icons.photo_library_outlined, onTap: onUpload),
              const SizedBox(width: T.s2),
              _GhostIconButton(icon: Icons.close, onTap: onClose),
            ],
          ),
        ],
      ),
    );
  }
}

class _GhostIconButton extends StatelessWidget {
  const _GhostIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0x29FFFFFF),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _TargetBox extends StatelessWidget {
  const _TargetBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 340,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x59FFFFFF), width: 1.5),
        borderRadius: BorderRadius.circular(T.rSm + 4),
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.onTap, required this.busy});

  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: busy ? T.amber : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// The bottom sheet from the redesign: white surface, navy primary,
/// amber icon chip. Layered above everything, so the shutter behind it
/// cannot be tapped.
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
                    child: const Icon(Icons.no_photography_outlined,
                        size: 18, color: T.amber),
                  ),
                  const SizedBox(width: T.s3),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
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
                  child: const Text('Try again'),
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
                  child: const Text('Use a photo instead'),
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
