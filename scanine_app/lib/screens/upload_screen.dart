import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'analyzing_screen.dart';
import '../theme/routes.dart';
import '../widgets/scanine_mark.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _picker = ImagePicker();
  String? _path;
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
      setState(() => _path = shot.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Couldn't access gallery. Please try again.");
    }
  }

  void _analyze() {
    if (_path == null) return;
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
                      ? _PreviewCard(path: _path!, onChangePhoto: _pick)
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
                      child: const Text(
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
  const _PreviewCard({required this.path, required this.onChangePhoto});

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
                  Icon(Icons.check_circle_rounded, color: navy, size: 18),
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
                style: TextButton.styleFrom(foregroundColor: navy),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
