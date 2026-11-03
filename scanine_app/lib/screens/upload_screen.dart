import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../ml/image_quality.dart';
import '../ml/subject_check.dart';
import '../models/screening_result.dart';
import 'analyzing_screen.dart';
import 'crop_screen.dart';
import 'result_screen.dart';
import '../theme/routes.dart';
import '../theme/tokens.dart';
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
  double _aspect = 1; // width / height of the crop
  String? _error;
  _UploadIssue? _issue; // quality or dog-check problem with the selected photo
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
    final cropped = await AppRoutes.push<CropResult>(
      context,
      (_) => CropScreen(path: original),
    );
    if (cropped == null || !mounted) return;
    setState(() {
      _originalPath = original;
      _path = cropped.path;
      _aspect = cropped.aspect;
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
      _issue = s.isNotDog ? _UploadIssue.noDog : _UploadIssue.fromQuality(q);
    });
    if (_issue == null) _proceed();
  }

  void _proceed() {
    // No dog found: say so instead of running the classifier, which would
    // always name one of its four conditions.
    if (_issue == _UploadIssue.noDog) {
      AppRoutes.pushReplacement(
        context,
        (_) => ResultScreen(result: ScreeningResult.noDog(imagePath: _path!)),
      );
      return;
    }
    AppRoutes.pushReplacement(
      context,
      (_) => AnalyzingScreen(imagePaths: [_path!]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _path != null;
    final noDog = _issue == _UploadIssue.noDog;

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
                          issue: _issue,
                          aspect: _aspect,
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

                const SizedBox(height: 16),

                // ── Bottom Action Button (only shown once a photo is selected) ──
                if (hasPhoto) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      // No dog: nothing to scan, so the button only reports it
                      // (greyed, not tappable). Another issue: rechecking gives
                      // the same answer, so the action becomes picking again.
                      onPressed: noDog
                          ? null
                          : (_issue != null ? _pick : _analyze),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: navy,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE3E8EF),
                        disabledForegroundColor: T.ink3,
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
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (noDog) ...[
                                  const Icon(Icons.error_outline_rounded,
                                      size: 20),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  noDog
                                      ? 'No dog found'
                                      : _issue != null
                                          ? 'Choose another photo'
                                          : 'Ready to scan',
                                  style: const TextStyle(
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
                  if (_issue != null)
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: _proceed,
                        style: TextButton.styleFrom(foregroundColor: T.ink2),
                        child: const Text(
                          'Use this photo anyway',
                          style: TextStyle(
                            fontFamily: 'InstrumentSans',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  // Pad below button so it sits above the system nav bar
                  SizedBox(height: bottomInset + (_issue != null ? 4 : 16)),
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

/// A problem found with an uploaded photo, worded for uploads (the camera's
/// "hold steady" hints don't apply to a photo that's already taken). Shown in
/// the photo card's status line, the way the camera shows quality readouts.
class _UploadIssue {
  const _UploadIssue(this.status, this.hint);

  final String status; // short, replaces "Ready"
  final String hint; // one line under the status

  static const noDog = _UploadIssue(
      'No dog found', "Choose a close-up of your dog's skin.");

  static _UploadIssue? fromQuality(QualityAssessment q) {
    if (q.focus == FocusStatus.checking) return null; // couldn't assess
    if (q.focus == FocusStatus.blurry) {
      return const _UploadIssue(
          'Looks blurry', 'A sharper photo gives a more reliable result.');
    }
    switch (q.light) {
      case LightStatus.tooDark:
      case LightStatus.lowLight:
        return const _UploadIssue(
            'Too dark', 'Try a photo taken in brighter light.');
      case LightStatus.tooBright:
        return const _UploadIssue(
            'Too bright', 'Try a photo without strong glare.');
      case LightStatus.adequate:
      case LightStatus.checking:
        return null;
    }
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
    this.issue,
    this.aspect = 1,
  });

  final String path;
  final VoidCallback onChangePhoto;
  final VoidCallback onAdjust;
  final _UploadIssue? issue;

  /// Width / height of the cropped photo, shown in its own shape.
  final double aspect;

  static const navy = Color(0xFF073858);

  // Same pair the app already uses for "not quite right": the camera's warm
  // amber readouts and the result screen's "Low confidence" text.
  static const amber = Color(0xFFD49339);
  static const amberInk = Color(0xFF8A5A00);

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
          // Shown in the crop's own shape, never re-cropped.
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: aspect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(File(path), fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          // "Ready" now lives on the main button. Only a problem is shown
          // here: for "No dog found" the button already names it, so just the
          // hint; for quality issues, the status and its hint.
          if (issue != null) ...[
            const SizedBox(height: 16),
            if (issue != _UploadIssue.noDog)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_rounded, color: amber, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    issue!.status,
                    style: const TextStyle(
                      fontFamily: 'InstrumentSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: amberInk,
                    ),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                issue!.hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'InstrumentSans',
                  fontSize: 13,
                  height: 1.35,
                  color: T.ink2,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _action(Icons.crop_rounded, 'Adjust', onAdjust)),
              const SizedBox(width: 10),
              Expanded(
                child: _action(Icons.refresh_rounded, 'Change', onChangePhoto),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A soft, equal-width pill on the app's light surface colour.
  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return SizedBox(
      height: 44,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'InstrumentSans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: navy,
          backgroundColor: T.bgGradientEnd,
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}
