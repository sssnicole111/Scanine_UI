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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: _pinR * 2,
        height: _pinR * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? T.navy : T.amber,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '$number',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : T.navy,
          ),
        ),
      ),
    );
  }
}
