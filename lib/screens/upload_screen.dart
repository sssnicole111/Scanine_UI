import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'analyzing_screen.dart';
import '../theme/routes.dart';
import '../widgets/scanine_logo.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _picker = ImagePicker();
  String? _path;
  String? _croppedPath; // path after user confirms crop area
  String? _error;

  static const navy = Color(0xFF073858);
  static const background = Color(0xFFF5FAFC);
  static const maroon = Color(0xFF800020);

  Future<void> _pick() async {
    setState(() => _error = null);
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
      );
      if (shot == null) return; // user cancelled
      if (!mounted) return;
      // Open crop/zoom screen to let user choose the area.
      final confirmed = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (_) => _CropZoomScreen(imagePath: shot.path),
        ),
      );
      if (!mounted) return;
      if (confirmed != null) {
        setState(() {
          _path = confirmed;
          _croppedPath = confirmed;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Couldn't access gallery. Please try again.");
    }
  }

  void _analyze() {
    final p = _croppedPath ?? _path;
    if (p == null) return;
    AppRoutes.pushReplacement(
      context,
      // Pass a single-item list; analyzing screen detects upload vs. burst.
      (_) => AnalyzingScreen(imagePaths: [p], isUpload: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _path != null;
    final topPad = MediaQuery.viewPaddingOf(context).top;
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: background,
        body: Padding(
          padding: EdgeInsets.fromLTRB(24, topPad + 16, 24, bottomPad + 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Navigation Row ────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
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
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: navy,
                      ),
                    ),
                  ),
                  // Logo mark (transparent background) instead of text wordmark
                  const ScanineLogoMark(
                    size: 32,
                    navyColor: navy,
                    grayColor: Color(0xFF9BB5C8),
                  ),
                  const SizedBox(width: 44), // Balancer
                ],
              ),

              const SizedBox(height: 28),

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
                'Select photo',
                style: TextStyle(
                  fontFamily: 'InstrumentSans',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.0,
                  color: navy,
                ),
              ),

              const SizedBox(height: 24),

              // ── Content Card ──────────────────────────────────
              Expanded(
                child: hasPhoto
                    ? _PreviewCard(
                        path: _path!,
                        onChangePhoto: _pick,
                      )
                    : _UploadDropzoneCard(
                        onTap: _pick,
                      ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9EBEF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: maroon, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontFamily: 'InstrumentSans',
                            fontSize: 13,
                            color: maroon,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ── Bottom Action Button (only shown once a photo is selected) ──
              if (hasPhoto) ...[
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _analyze,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Start screening',
                          style: TextStyle(
                            fontFamily: 'InstrumentSans',
                            fontSize: 16.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else
                const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Crop / Zoom screen
// ─────────────────────────────────────────────────────────────────────────────

/// Full-screen pinch-to-zoom / pan crop step shown after the user picks a
/// photo. They position the image, then tap "Use this area" to confirm.
/// On confirmation the original path is returned (we let the classifier
/// handle the full image; this screen is purely for the user to visually
/// confirm / frame the area of interest).
class _CropZoomScreen extends StatefulWidget {
  const _CropZoomScreen({required this.imagePath});

  final String imagePath;

  @override
  State<_CropZoomScreen> createState() => _CropZoomScreenState();
}

class _CropZoomScreenState extends State<_CropZoomScreen> {
  static const navy = Color(0xFF073858);

  final TransformationController _transformController =
      TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.viewPaddingOf(context).top;
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Zoomable / pannable image ──────────────────────
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 1.0,
                maxScale: 5.0,
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),

            // ── Top bar ───────────────────────────────────────
            Positioned(
              top: topPad + 12,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back / cancel
                  _CircleButton(
                    icon: Icons.close,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    'Crop & zoom',
                    style: TextStyle(
                      fontFamily: 'InstrumentSans',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  // Reset zoom
                  _CircleButton(
                    icon: Icons.restart_alt_rounded,
                    onTap: () => _transformController.value =
                        Matrix4.identity(),
                  ),
                ],
              ),
            ),

            // ── Instruction hint ──────────────────────────────
            Positioned(
              left: 24,
              right: 24,
              top: topPad + 72,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Pinch to zoom · drag to reposition',
                    style: TextStyle(
                      fontFamily: 'InstrumentSans',
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            // ── Confirm button ────────────────────────────────
            Positioned(
              left: 24,
              right: 24,
              bottom: bottomPad + 32,
              child: SizedBox(
                height: 60,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pop(widget.imagePath),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_rounded, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Use this area',
                        style: TextStyle(
                          fontFamily: 'InstrumentSans',
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
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
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dropzone card (empty state)
// ─────────────────────────────────────────────────────────────────────────────

class _UploadDropzoneCard extends StatelessWidget {
  const _UploadDropzoneCard({required this.onTap});

  final VoidCallback onTap;

  static const navy = Color(0xFF073858);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C142E53),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: Color(0xFFD2E3F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                color: navy,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tap to select a photo',
              style: TextStyle(
                fontFamily: 'InstrumentSans',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: navy,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Preview card (photo selected)
// ─────────────────────────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.path,
    required this.onChangePhoto,
  });

  final String path;
  final VoidCallback onChangePhoto;

  static const navy = Color(0xFF073858);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C142E53),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(
                File(path),
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Photo loaded',
                    style: TextStyle(
                      fontFamily: 'InstrumentSans',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: navy,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: onChangePhoto,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  'Change',
                  style: TextStyle(
                    fontFamily: 'InstrumentSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: navy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
