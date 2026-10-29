import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/routes.dart';
import 'camera_screen.dart';

/// Primary HomeScreen wrapper that provides default navigation callbacks
/// to [ScanineHomeScreen].
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.onStartScreening,
    this.onHowItWorks,
  });

  final VoidCallback? onStartScreening;
  final VoidCallback? onHowItWorks;

  void _defaultStart(BuildContext context) {
    AppRoutes.push(context, (_) => const CameraScreen());
  }

  void _defaultHowItWorks(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'How Scanine Works',
                  style: TextStyle(
                    fontFamily: 'InstrumentSans',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    color: ScanineHomeScreen.navy,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A fast veterinary pre-screening tool designed to help evaluate canine skin conditions gently and accurately.',
                  style: TextStyle(
                    fontFamily: 'InstrumentSans',
                    fontSize: 14.5,
                    height: 1.4,
                    color: ScanineHomeScreen.slate,
                  ),
                ),
                const SizedBox(height: 22),
                _HowStepItem(
                  icon: Icons.burst_mode_rounded,
                  title: '5-Frame Rapid Burst',
                  description:
                      'Tap once to automatically capture 5 sequential frames, capturing clean angles even with moving pets.',
                ),
                const SizedBox(height: 16),
                _HowStepItem(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Real-Time Quality Gating',
                  description:
                      'Every frame is checked on-device for blur and optimal illumination before acceptance.',
                ),
                const SizedBox(height: 16),
                _HowStepItem(
                  icon: Icons.auto_awesome_rounded,
                  title: 'On-Device AI Ensemble',
                  description:
                      'Multiple neural network predictions are averaged with confidence scoring and Grad-CAM attention maps.',
                ),
                const SizedBox(height: 16),
                _HowStepItem(
                  icon: Icons.local_hospital_outlined,
                  title: 'Direct Veterinary Referral',
                  description:
                      'Instantly view nearby licensed veterinary clinics, call with one tap, or get driving directions.',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ScanineHomeScreen.navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                        fontFamily: 'InstrumentSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScanineHomeScreen(
      onStartScreening: onStartScreening ?? () => _defaultStart(context),
      onHowItWorks: onHowItWorks ?? () => _defaultHowItWorks(context),
    );
  }
}

class _HowStepItem extends StatelessWidget {
  const _HowStepItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFD2E3F1).withAlpha(120),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: ScanineHomeScreen.navy,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'InstrumentSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: ScanineHomeScreen.navy,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  fontFamily: 'InstrumentSans',
                  fontSize: 13,
                  height: 1.35,
                  color: ScanineHomeScreen.slate,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ScanineHomeScreen extends StatelessWidget {
  const ScanineHomeScreen({
    super.key,
    required this.onStartScreening,
    required this.onHowItWorks,
  });

  final VoidCallback onStartScreening;
  final VoidCallback onHowItWorks;

  static const navy = Color(0xFF073858);
  static const slate = Color(0xFF526B85);
  static const background = Color(0xFFF5FAFC);

  @override
  Widget build(BuildContext context) {
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
        body: Stack(
          children: [
            // Decorative silhouette extends edge-to-edge behind the notch and status bar.
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _DogSilhouettePainter(),
                  ),
                ),
              ),
            ),

            SafeArea(
              bottom: false, // Let bg bleed behind system nav bar
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final height = constraints.maxHeight;
                  final compact = height < 680;
                  final topSpace = compact ? 8.0 : 12.0;
                  final heroSpace = (height * 0.08).clamp(16.0, 48.0);
                  final bottomSpace = compact ? 16.0 : 24.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        SizedBox(height: topSpace),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Image.asset(
                              'assets/icon/icon.png',
                              height: 32,
                              width: 32,
                              fit: BoxFit.contain,
                            ),
                            TextButton(
                              onPressed: onHowItWorks,
                              style: TextButton.styleFrom(
                                foregroundColor: slate,
                                minimumSize: const Size(48, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.help_outline_rounded,
                                    size: 19,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'How it works',
                                    style: TextStyle(
                                      fontFamily: 'InstrumentSans',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: heroSpace),

                        Text(
                          'Screen in\nfive frames.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'InstrumentSans',
                            fontSize: compact ? 38 : 44,
                            fontWeight: FontWeight.w700,
                            height: 1.04,
                            letterSpacing: -1.7,
                            color: navy,
                          ),
                        ),

                        SizedBox(height: compact ? 16 : 22),

                        const Text(
                          'Point the camera at the\n'
                          'affected area to begin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'InstrumentSans',
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                            letterSpacing: -0.3,
                            color: slate,
                          ),
                        ),

                        const Spacer(),

                        _ScreeningButton(
                          onPressed: onStartScreening,
                        ),

                        // Sit above the nav bar — add the bottom inset
                        SizedBox(
                          height: bottomSpace +
                              MediaQuery.of(context).padding.bottom,
                        ),
                      ],
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
}

class _ScreeningButton extends StatelessWidget {
  const _ScreeningButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ScanineHomeScreen.navy,
      borderRadius: BorderRadius.circular(40),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 24,
              right: 8,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'start screening',
                    style: TextStyle(
                      fontFamily: 'InstrumentSans',
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: ScanineHomeScreen.navy,
                    size: 25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vector silhouette: no image asset required.
/// Coordinates use a 390 × 844 design canvas.
class _DogSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 390, size.height / 844);

    final body = Path()
      // Forehead and crown.
      ..moveTo(152, 403)
      ..cubicTo(155, 378, 197, 345, 236, 341)
      ..cubicTo(277, 335, 314, 357, 332, 380)
      // Back of the head.
      ..cubicTo(350, 396, 361, 418, 363, 443)
      ..lineTo(370, 456)
      ..lineTo(365, 452)
      ..cubicTo(371, 479, 383, 499, 399, 513)
      // Shoulder continues beyond the right edge.
      ..lineTo(410, 747)
      ..lineTo(241, 747)
      ..cubicTo(238, 711, 217, 688, 212, 656)
      ..cubicTo(207, 630, 210, 609, 210, 590)
      // Small fur breaks along the neck.
      ..lineTo(202, 602)
      ..lineTo(207, 575)
      ..lineTo(201, 582)
      ..cubicTo(211, 550, 211, 535, 204, 519)
      ..lineTo(198, 529)
      ..cubicTo(200, 514, 197, 504, 189, 500)
      // Chin and lower muzzle.
      ..cubicTo(179, 494, 163, 501, 146, 499)
      ..cubicTo(120, 499, 98, 486, 91, 466)
      ..cubicTo(88, 458, 88, 454, 85, 450)
      // Nose and upper muzzle.
      ..cubicTo(78, 441, 78, 432, 89, 427)
      ..cubicTo(113, 417, 140, 412, 152, 403)
      ..close();

    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFD2E3F1),
            Color(0xFFE0EDF6),
            Color(0xFFF5FAFC),
          ],
          stops: [0, 0.65, 1],
        ).createShader(
          const Rect.fromLTWH(75, 340, 335, 410),
        ),
    );

    // Lighter ear adds depth without facial details.
    final ear = Path()
      ..moveTo(231, 357)
      ..cubicTo(261, 347, 289, 363, 306, 390)
      ..cubicTo(326, 423, 321, 472, 309, 511)
      ..cubicTo(300, 544, 288, 553, 272, 544)
      ..cubicTo(246, 530, 229, 499, 223, 471)
      ..cubicTo(215, 439, 247, 401, 231, 357)
      ..close();

    canvas.drawPath(
      ear,
      Paint()..color = const Color(0xFFE0EDF6),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DogSilhouettePainter oldDelegate) => false;
}
