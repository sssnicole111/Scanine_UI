import 'package:flutter/material.dart';

import '../models/clinic.dart';
import '../theme/tokens.dart';

/// Intrinsic size of assets/map/tacloban.png — pin positions in
/// clinics.json are normalised against this, so replacing the image with a
/// different crop means re-reading the marker positions.
const double _mapW = 786;
const double _mapH = 755;
const double _pinR = 13;

/// Bundled map of Tacloban with the clinics marked.
///
/// The image ships inside the app rather than streaming tiles: Scanine
/// claims to work with no connection, and a live map would need network
/// and an API key. Real navigation is handed off to the phone's map app.
class TaclobanMap extends StatelessWidget {
  const TaclobanMap({
    super.key,
    required this.clinics,
    required this.selected,
    required this.onPinTap,
  });

  final List<Clinic> clinics;
  final int selected;
  final ValueChanged<int> onPinTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _mapW / _mapH,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/map/tacloban.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
              for (var i = 0; i < clinics.length; i++)
                if (clinics[i].hasPin)
                  Positioned(
                    left: clinics[i].x! * w - _pinR,
                    top: clinics[i].y! * h - _pinR,
                    child: _Pin(
                      number: i + 1,
                      active: i == selected,
                      onTap: () => onPinTap(i),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.number, required this.active, required this.onTap});

  final int number;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Use the system palette: navySoft for inactive, navyDark for active
    const inactiveColor = T.navySoft;
    const activeColor = T.navyDark;

    final size = active ? 28.0 : 22.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? activeColor : inactiveColor,
            border: Border.all(
              color: Colors.white,
              width: active ? 2.2 : 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: active
                    ? const Color(0x55142E53) // navyDark @ 33%
                    : const Color(0x381F4273), // navySoft @ 22%
                blurRadius: active ? 8 : 4,
                spreadRadius: active ? 1 : 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: active ? 11.5 : 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
