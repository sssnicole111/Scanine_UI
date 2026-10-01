import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'camera_screen.dart';

/// Home. Mirrors the PWA layout you settled on: the header, card and
/// footer travel together as one vertically centred group.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: T.homeGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Header(),
                  const SizedBox(height: T.s6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: T.s6),
                    child: _ScreeningCard(
                      onStart: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CameraScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: T.s8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: T.s6),
                    child: Text(
                      'Runs entirely on this device. '
                      'No internet connection required.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: T.tXs, color: T.ink3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: T.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Scanine',
                style: TextStyle(
                  fontSize: T.tLg,
                  fontWeight: FontWeight.w700,
                  color: T.ink,
                  letterSpacing: -0.22,
                ),
              ),
              _OfflinePill(),
            ],
          ),
          const SizedBox(height: T.s2),
          const Text(
            'TACLOBAN CITY',
            style: TextStyle(
              fontSize: T.tXs,
              fontWeight: FontWeight.w600,
              color: T.ink3,
              letterSpacing: 0.88,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflinePill extends StatelessWidget {
  const _OfflinePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
      decoration: BoxDecoration(
        color: T.successBg,
        borderRadius: BorderRadius.circular(T.rFull),
        border: Border.all(color: const Color(0x2E10B981)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _Dot(),
          SizedBox(width: 6),
          Text(
            'Offline ready',
            style: TextStyle(
              fontSize: T.tXs,
              fontWeight: FontWeight.w600,
              color: T.successInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: T.success,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ScreeningCard extends StatelessWidget {
  const _ScreeningCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(T.rLg),
      child: Container(
        decoration: const BoxDecoration(
          gradient: T.cardGradient,
          boxShadow: [T.shadowMd],
        ),
        child: Stack(
          children: [
            // Decorative amber glow, top-right.
            Positioned(
              top: -70,
              right: -70,
              child: Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: T.amberGlow,
                  boxShadow: [
                    BoxShadow(
                      color: T.amberGlow,
                      blurRadius: 90,
                      spreadRadius: 40,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(T.s6, T.s8, T.s6, T.s6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'NEW SCREENING',
                    style: TextStyle(
                      fontSize: T.tXs,
                      fontWeight: FontWeight.w700,
                      color: T.onDark2,
                      letterSpacing: 1.32,
                    ),
                  ),
                  const SizedBox(height: T.s3),
                  const Text(
                    'Capture five frames to begin',
                    style: TextStyle(
                      fontSize: T.tLg,
                      fontWeight: FontWeight.w700,
                      color: T.onDark,
                      height: 1.22,
                      letterSpacing: -0.22,
                    ),
                  ),
                  const SizedBox(height: T.s2),
                  const Text(
                    'Point the camera at the affected area. '
                    'No connection needed.',
                    style: TextStyle(
                      fontSize: T.tSm,
                      color: T.onDark2,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: T.s6),
                  _StartButton(onPressed: onStart),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.photo_camera_outlined, size: 18),
        label: const Text('Start screening'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: T.navy,
          padding: const EdgeInsets.symmetric(vertical: T.s4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(T.rFull),
          ),
          textStyle: const TextStyle(
            fontSize: T.tBase,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
