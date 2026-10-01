import 'package:flutter/material.dart';

/// Design tokens ported 1:1 from the PWA's App.css custom properties.
/// Nothing outside this file should contain a raw hex value.
class T {
  // ── Palette ──────────────────────────────────────────────
  static const ink = Color(0xFF0F172A);
  static const ink2 = Color(0xFF475569);
  static const ink3 = Color(0xFF94A3B8);
  static const surface = Color(0xFFFFFFFF);
  static const bg = Color(0xFFF8F6F4);
  static const line = Color(0x1F000000);

  static const success = Color(0xFF10B981);
  static const successBg = Color(0xFFECFDF5);
  static const successInk = Color(0xFF067A5C);

  static const navy = Color(0xFF101B34);
  static const navy2 = Color(0xFF16244A);
  static const amber = Color(0xFFF59E0B);
  static const amberBg = Color(0x1FF59E0B);
  static const amberGlow = Color(0x47F59E0B); // amber @ 28%

  static const onDark = Color(0xFFFFFFFF);
  static const onDark2 = Color(0xFFADB5C4); // white @ 68%
  static const onDark3 = Color(0xFF666E80); // white @ 40%
  static const onDarkLine = Color(0x24FFFFFF);

  /// Home screen background gradient.
  static const homeGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEEF2F6), Color(0xFFE7ECF2)],
  );

  /// The navy screening card / camera backdrop gradient (165deg in CSS).
  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy2, navy],
  );

  // ── Spacing ──────────────────────────────────────────────
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;

  // ── Radius ───────────────────────────────────────────────
  static const rSm = 8.0;
  static const rMd = 16.0;
  static const rLg = 24.0;
  static const rFull = 999.0;

  // ── Type scale ───────────────────────────────────────────
  static const tXs = 11.0;
  static const tSm = 13.0;
  static const tBase = 15.0;
  static const tMd = 17.0;
  static const tLg = 22.0;
  static const tXl = 32.0;

  // ── Shadow ───────────────────────────────────────────────
  static const shadowMd = BoxShadow(
    color: Color(0x147A6B5F),
    blurRadius: 32,
    offset: Offset(0, 12),
  );
}
