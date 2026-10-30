import 'package:flutter/material.dart';

import 'camera_screen.dart';

/// Minimal typographic HomeScreen matching the PWA design:
/// - Light gradient backdrop
/// - Top row: "scanine" brandmark & "works offline" status pill
/// - Flexible spacer pushing content down
/// - Large editorial headline: "screen in five frames."
/// - Subtitle description
/// - 5-bar frame indicator
/// - Pill button with trailing white camera icon circle
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _topOpacity;
  late final Animation<Offset> _topSlide;

  late final Animation<double> _headOpacity;
  late final Animation<Offset> _headSlide;

  late final Animation<double> _subOpacity;
  late final Animation<Offset> _subSlide;

  late final Animation<double> _framesOpacity;
  late final Animation<Offset> _framesSlide;

  late final Animation<double> _ctaOpacity;
  late final Animation<Offset> _ctaSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    const curve = Cubic(0.2, 0.8, 0.2, 1.0);

    _topOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.05, 0.65, curve: curve),
      ),
    );
    _topSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.05, 0.65, curve: curve),
          ),
        );

    _headOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: curve),
      ),
    );
    _headSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.8, curve: curve),
          ),
        );

    _subOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 0.88, curve: curve),
      ),
    );
    _subSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.32, 0.88, curve: curve),
          ),
        );

    _framesOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.42, 0.95, curve: curve),
      ),
    );
    _framesSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.42, 0.95, curve: curve),
          ),
        );

    _ctaOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: curve),
      ),
    );
    _ctaSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.5, 1.0, curve: curve),
          ),
        );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onStart() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CameraScreen()));
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF1F3A6B);
    const navy2 = Color(0xFF2B4C86);
    const mist = Color(0xFFB9C3D4);
    const ink2 = Color(0xFF55627C);
    const ok = Color(0xFF0E8A66);
    const okDot = Color(0xFF10B981);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F6FA), Color(0xFFE9EEF5)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SlideTransition(
                  position: _topSlide,
                  child: FadeTransition(
                    opacity: _topOpacity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'scanine',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.52,
                            color: navy,
                            height: 1.0,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: okDot,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: okDot.withOpacity(0.16),
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 7),
                            const Text(
                              'works offline',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: ok,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                SlideTransition(
                  position: _headSlide,
                  child: FadeTransition(
                    opacity: _headOpacity,
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 50,
                          fontWeight: FontWeight.w600,
                          height: 1.02,
                          letterSpacing: -1.5,
                          color: navy,
                        ),
                        children: [
                          TextSpan(text: 'screen in\nfive frames'),
                          TextSpan(
                            text: '.',
                            style: TextStyle(color: mist),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                SlideTransition(
                  position: _subSlide,
                  child: FadeTransition(
                    opacity: _subOpacity,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 250),
                      child: const Text(
                        'Point the camera at the affected area to begin.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          height: 1.5,
                          color: ink2,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                SlideTransition(
                  position: _framesSlide,
                  child: FadeTransition(
                    opacity: _framesOpacity,
                    child: Row(
                      children: List.generate(
                        5,
                        (index) => Expanded(
                          child: Container(
                            margin: EdgeInsets.only(
                              right: index < 4 ? 6.0 : 0.0,
                            ),
                            height: 4,
                            decoration: BoxDecoration(
                              color: mist.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                SlideTransition(
                  position: _ctaSlide,
                  child: FadeTransition(
                    opacity: _ctaOpacity,
                    child: Container(
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment(-0.8, -0.6),
                          end: Alignment(0.8, 0.6),
                          colors: [navy2, navy],
                        ),
                        borderRadius: BorderRadius.circular(34),
                        boxShadow: [
                          BoxShadow(
                            color: navy.withOpacity(0.28),
                            blurRadius: 32,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(34),
                          onTap: _onStart,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 28, right: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'start screening',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                    color: Colors.white,
                                  ),
                                ),
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.photo_camera_outlined,
                                      color: navy,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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
