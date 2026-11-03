// lib/screens/crop_screen.dart
//
// Crop step for gallery uploads: the user picks a shape (the photo's own,
// square, 4:3 or 3:4), pinches and drags the photo under that window, then
// "Use this area" writes it to a new JPEG.
//
// The classifier always resizes its input to 224x224, as it did for uncropped
// uploads; the shape only decides which part of the photo is used.
//
// Returns a [CropResult], or null if the user backs out.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

/// The cropped photo and its shape (width / height).
class CropResult {
  const CropResult(this.path, this.aspect);

  final String path;
  final double aspect;
}

/// Crop shapes on offer. [original] uses the photo's own proportions.
enum _CropShape {
  original('Original', null),
  square('Square', 1.0),
  landscape('4:3', 4 / 3),
  portrait('3:4', 3 / 4);

  const _CropShape(this.label, this.ratio);

  final String label;
  final double? ratio;
}

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
  static const chipFill = Color(0xFFEEF2F7);

  final _ctrl = TransformationController();

  Size? _imageSize; // decoded size, orientation applied
  Size _window = Size.zero; // crop window, logical px
  _CropShape _shape = _CropShape.original;
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

  /// Width / height of the crop window for the chosen shape.
  double get _ratio {
    final s = _imageSize;
    return _shape.ratio ?? (s == null ? 1.0 : s.width / s.height);
  }

  /// Largest window of [_ratio] that fits the available space.
  Size _fit(Size box) {
    var w = box.width;
    var h = w / _ratio;
    if (h > box.height) {
      h = box.height;
      w = h * _ratio;
    }
    return Size(w, h);
  }

  /// Scale that makes the image just cover the window.
  double get _coverScale {
    final s = _imageSize!;
    return math.max(_window.width / s.width, _window.height / s.height);
  }

  /// Starts centred, with the photo just covering the window.
  void _resetView() {
    final s = _imageSize;
    if (s == null || _window.isEmpty) return;
    final c = _coverScale;
    _ctrl.value = Matrix4.identity()
      ..translateByDouble(
        -(s.width * c - _window.width) / 2,
        -(s.height * c - _window.height) / 2,
        0,
        1,
      );
  }

  void _setShape(_CropShape shape) {
    if (shape == _shape) return;
    setState(() => _shape = shape);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetView());
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
    final w = _window.width / zoom / c;
    final h = _window.height / zoom / c;
    final x = (-t.x / zoom) / c;
    final y = (-t.y / zoom) / c;

    try {
      final bytes = await compute(_cropToJpeg, (
        path: widget.path,
        x: x.round(),
        y: y.round(),
        w: w.round(),
        h: h.round(),
      ));
      final dir = await Directory.systemTemp.createTemp('scanine_crop');
      final out = File('${dir.path}/crop.jpg');
      await out.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      Navigator.of(context).pop(CropResult(out.path, w / h));
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
                  'Pinch to zoom and drag so the affected area fills the frame.',
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
                      final window = _fit(box.biggest);
                      if (window != _window) {
                        _window = window;
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) => _resetView());
                      }
                      return Center(
                        child: SizedBox.fromSize(
                          size: window,
                          child: _cropWindow(window),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // ── Shape choices ────────────────────────────────
                Center(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final shape in _CropShape.values) _shapeChip(shape),
                    ],
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

                const SizedBox(height: 20),

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

  Widget _shapeChip(_CropShape shape) {
    final selected = shape == _shape;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () => _setShape(shape),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? navy : chipFill,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            shape.label,
            style: TextStyle(
              fontFamily: 'InstrumentSans',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : navy,
            ),
          ),
        ),
      ),
    );
  }

  Widget _cropWindow(Size window) {
    final s = _imageSize;
    final c = s == null || window.isEmpty
        ? 0.0
        : math.max(window.width / s.width, window.height / s.height);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF1A2434)),
          if (s != null && c > 0)
            InteractiveViewer(
              key: ValueKey(_shape),
              transformationController: _ctrl,
              constrained: false,
              minScale: 1.0,
              maxScale: 6.0,
              child: Image.file(
                File(widget.path),
                width: s.width * c,
                height: s.height * c,
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

/// Isolate entry: decode, apply EXIF orientation, crop the area, re-encode.
Uint8List _cropToJpeg(({String path, int x, int y, int w, int h}) a) {
  final decoded = img.decodeImage(File(a.path).readAsBytesSync());
  if (decoded == null) throw const FormatException('Unreadable image');
  final src = img.bakeOrientation(decoded);
  final w = a.w.clamp(1, src.width).toInt();
  final h = a.h.clamp(1, src.height).toInt();
  final x = a.x.clamp(0, src.width - w).toInt();
  final y = a.y.clamp(0, src.height - h).toInt();
  final cropped = img.copyCrop(src, x: x, y: y, width: w, height: h);
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
