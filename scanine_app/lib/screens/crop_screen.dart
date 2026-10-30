// lib/screens/crop_screen.dart
//
// Crop step for gallery uploads: the user pinches and drags the photo under a
// fixed square window, then "Use this area" writes that square to a new JPEG.
//
// Square on purpose: the classifier resizes its input straight to 224×224, so
// a square crop reaches the model without being stretched.
//
// Returns the cropped file's path, or null if the user backs out.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class CropScreen extends StatefulWidget {
  const CropScreen({super.key, required this.path});

  final String path;

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  static const navy = Color(0xFF073858);
  static const background = Color(0xFFF5FAFC);
  static const slate = Color(0xFF526B85);

  final _ctrl = TransformationController();

  Size? _imageSize; // decoded size, orientation applied
  double _viewport = 0; // side of the square window, logical px
  bool _saving = false;
  String? _error;

  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    final stream = FileImage(File(widget.path)).resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(() => _imageSize = Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            ));
        WidgetsBinding.instance.addPostFrameCallback((_) => _resetView());
      },
      onError: (_, _) {
        if (mounted) setState(() => _error = "Couldn't open this photo.");
      },
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  @override
  void dispose() {
    final s = _stream, l = _listener;
    if (s != null && l != null) s.removeListener(l);
    _ctrl.dispose();
    super.dispose();
  }

  /// Scale that makes the image just cover the square window.
  double get _coverScale {
    final s = _imageSize!;
    return _viewport / math.min(s.width, s.height);
  }

  /// Starts centred, with the shorter side filling the window.
  void _resetView() {
    final s = _imageSize;
    if (s == null || _viewport == 0) return;
    final c = _coverScale;
    _ctrl.value = Matrix4.identity()
      ..translateByDouble(
        -(s.width * c - _viewport) / 2,
        -(s.height * c - _viewport) / 2,
        0,
        1,
      );
  }

  Future<void> _confirm() async {
    final s = _imageSize;
    if (s == null || _saving) return;
    setState(() => _saving = true);

    // Window → child coordinates → original image pixels.
    final m = _ctrl.value;
    final zoom = m.getMaxScaleOnAxis();
    final t = m.getTranslation();
    final c = _coverScale;
    final side = _viewport / zoom / c;
    final x = (-t.x / zoom) / c;
    final y = (-t.y / zoom) / c;

    try {
      final bytes = await compute(_cropToJpeg, (
        path: widget.path,
        x: x.round(),
        y: y.round(),
        side: side.round(),
      ));
      final dir = await Directory.systemTemp.createTemp('scanine_crop');
      final out = File('${dir.path}/crop.jpg');
      await out.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      Navigator.of(context).pop(out.path);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Couldn't crop this photo. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: background,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // ── Top Navigation Row ────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CircleButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      tooltip: 'Back',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    _CircleButton(
                      icon: Icons.restart_alt_rounded,
                      tooltip: 'Reset',
                      onTap: _resetView,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Header ────────────────────────────────────────
                const Text(
                  'UPLOAD PHOTO',
                  style: TextStyle(
                    fontFamily: 'InstrumentSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Frame the skin',
                  style: TextStyle(
                    fontFamily: 'InstrumentSans',
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.0,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pinch to zoom and drag so the affected area fills the square.',
                  style: TextStyle(
                    fontFamily: 'InstrumentSans',
                    fontSize: 13.5,
                    color: slate,
                  ),
                ),

                const SizedBox(height: 20),

                // ── Crop window ──────────────────────────────────
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final side = math.min(box.maxWidth, box.maxHeight);
                      if (side != _viewport) {
                        _viewport = side;
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) => _resetView());
                      }
                      return Center(
                        child: SizedBox.square(
                          dimension: side,
                          child: _cropWindow(side),
                        ),
                      );
                    },
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontFamily: 'InstrumentSans',
                      fontSize: 13,
                      color: Color(0xFF800020),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _imageSize == null || _saving ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navy,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: navy.withValues(alpha: 0.5),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Use this area',
                            style: TextStyle(
                              fontFamily: 'InstrumentSans',
                              fontSize: 16.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: bottomInset + 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cropWindow(double side) {
    final s = _imageSize;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF1A2434)),
          if (s != null && side > 0)
            InteractiveViewer(
              transformationController: _ctrl,
              constrained: false,
              minScale: 1.0,
              maxScale: 6.0,
              child: Image.file(
                File(widget.path),
                width: s.width * (side / math.min(s.width, s.height)),
                height: s.height * (side / math.min(s.width, s.height)),
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          const IgnorePointer(child: CustomPaint(painter: _ThirdsPainter())),
        ],
      ),
    );
  }
}

/// Isolate entry: decode, apply EXIF orientation, crop the square, re-encode.
Uint8List _cropToJpeg(({String path, int x, int y, int side}) a) {
  final decoded = img.decodeImage(File(a.path).readAsBytesSync());
  if (decoded == null) throw const FormatException('Unreadable image');
  final src = img.bakeOrientation(decoded);
  final side = a.side.clamp(1, math.min(src.width, src.height)).toInt();
  final x = a.x.clamp(0, src.width - side).toInt();
  final y = a.y.clamp(0, src.height - side).toInt();
  final cropped = img.copyCrop(src, x: x, y: y, width: side, height: side);
  return img.encodeJpg(cropped, quality: 92);
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x0C142E53),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: _CropScreenState.navy),
        ),
      ),
    );
  }
}

/// Rule-of-thirds guide over the crop window.
class _ThirdsPainter extends CustomPainter {
  const _ThirdsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final dx = size.width * i / 3;
      final dy = size.height * i / 3;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), p);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), p);
    }
  }

  @override
  bool shouldRepaint(_ThirdsPainter old) => false;
}
