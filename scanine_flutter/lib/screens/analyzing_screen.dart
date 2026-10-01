import 'package:flutter/material.dart';

import '../models/screening_result.dart';
import '../theme/tokens.dart';
import 'result_screen.dart';

/// DEMO BUILD: this is a timed animation, not real inference. When the
/// TFLite model is wired in, drive `_controller` from the frame counter
/// instead of a fixed duration.
class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key, this.imagePath});

  final String? imagePath;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ResultScreen(
                result: ScreeningResult.demo(imagePath: widget.imagePath),
              ),
            ),
          );
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: T.cardGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: T.s6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROCESSING ON-DEVICE',
                  style: TextStyle(
                    fontSize: T.tXs,
                    fontWeight: FontWeight.w700,
                    color: T.onDark2,
                    letterSpacing: 1.32,
                  ),
                ),
                const SizedBox(height: T.s3),
                const Text(
                  'Reading five frames',
                  style: TextStyle(
                    fontSize: T.tXl,
                    fontWeight: FontWeight.w700,
                    color: T.onDark,
                    height: 1.15,
                    letterSpacing: -0.32,
                  ),
                ),
                const SizedBox(height: T.s8),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(T.rFull),
                          child: LinearProgressIndicator(
                            value: _controller.value,
                            minHeight: 4,
                            backgroundColor: T.onDarkLine,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(T.amber),
                          ),
                        ),
                        const SizedBox(height: T.s3),
                        Text(
                          'Frame ${(_controller.value * 5).ceil().clamp(1, 5)} of 5',
                          style: const TextStyle(
                            fontSize: T.tSm,
                            color: T.onDark2,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
