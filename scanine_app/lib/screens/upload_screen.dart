import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../ml/image_quality.dart';
import '../ml/subject_check.dart';
import 'analyzing_screen.dart';
import 'crop_screen.dart';
import '../theme/routes.dart';
import '../widgets/scanine_mark.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _picker = ImagePicker();
  String? _path; // cropped photo that gets analyzed
  String? _originalPath; // as picked, so "Adjust" can re-crop from scratch
  String? _error;
  String? _issue; // quality or dog-check problem with the selected photo
  bool _checking = false;

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
      await _crop(shot.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Couldn't access gallery. Please try again.");
    }
  }

  /// Opens the crop step; backing out keeps the previous selection.
  Future<void> _crop(String original) async {
    final cropped = await AppRoutes.push<String>(
      context,
      (_) => CropScreen(path: original),
    );
    if (cropped == null || !mounted) return;
    setState(() {
      _originalPath = original;
      _path = cropped;
      _issue = null;
    });
  }

  /// Runs the same blur/light gate as the camera, plus the dog check. A
  /// problem is shown with "Analyze anyway", since either check can be wrong.
  Future<void> _analyze() async {
    final path = _path;
    if (path == null || _checking) return;
    setState(() {
      _checking = true;
      _issue = null;
    });
    final quality = QualityGate.assessFile(path);
    final subject = SubjectCheck.assessFile(path);
    final q = await quality;
    final s = await subject;
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (s.isNotDog) {
        _issue = "We couldn't find a dog in this photo. "
            "Choose a photo of your dog's skin.";
      } else if (!q.isAcceptable && q.focus != FocusStatus.checking) {
        _issue = q.feedbackMessage;
      }
    });
    if (_issue == null) _proceed();
  }

  void _proceed() {
    AppRoutes.pushReplacement(
      context,
      (_) => AnalyzingScreen(imagePaths: [_path!]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _path != null;

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
          bottom: false, // Let background bleed behind nav bar
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
                    const ScanineMark(size: 32),
                    const SizedBox(width: 44), // Balancer
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
                          onAdjust: () => _crop(_originalPath!),
                        )
                      : _UploadDropzoneCard(onTap: _pick),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
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

                if (_issue != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9EBEF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(Icons.info_outline,
                                  color: maroon, size: 18),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _issue!,
                                style: const TextStyle(
                                  fontFamily: 'InstrumentSans',
                                  fontSize: 13,
                                  color: maroon,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _proceed,
                            style: TextButton.styleFrom(foregroundColor: maroon),
                            child: const Text(
                              'Analyze anyway',
                              style: TextStyle(
                                fontFamily: 'InstrumentSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
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
                      child: _checking
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Start screening',
                              style: TextStyle(
                                fontFamily: 'InstrumentSans',
                                fontSize: 16.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                              ),
                            ),
                    ),
                  ),
                  // Pad below button so it sits above the system nav bar
                  SizedBox(height: bottomInset + 16),
                ] else
                  SizedBox(height: bottomInset + 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
            const SizedBox(height: 6),
            const Text(
              'Choose an image from your gallery',
              style: TextStyle(
                fontFamily: 'InstrumentSans',
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: Color(0xFF526B85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.path,
    required this.onChangePhoto,
    required this.onAdjust,
  });

  final String path;
  final VoidCallback onChangePhoto;
  final VoidCallback onAdjust;

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
          // The crop is square, so show it square rather than re-cropping it.
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(File(path), fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: navy, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Ready',
                  style: TextStyle(
                    fontFamily: 'InstrumentSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: navy,
                  ),
                ),
              ),
              _action(Icons.crop_rounded, 'Adjust', onAdjust),
              _action(Icons.refresh_rounded, 'Change', onChangePhoto),
            ],
          ),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(
          fontFamily: 'InstrumentSans',
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(foregroundColor: navy),
    );
  }
}
