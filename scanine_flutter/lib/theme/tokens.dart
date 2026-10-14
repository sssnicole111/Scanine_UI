import 'package:flutter/material.dart';

/// Design tokens ported 1:1 from the unified Scanine design system.
/// Matches the PWA's App.css and HomeScreen styles.
class T {
  // ── Unified Palette ──────────────────────────────────────
  static const ink = Color(0xFF193863);
  static const ink2 = Color(0xFF5F708A);
  static const ink3 = Color(0xFF8E9CB2);
  static const surface = Color(0xFFFFFFFF);
  static const bg = Color(0xFFF8FAFD);
  static const bgGradientEnd = Color(0xFFEEF2F7);
  static const line = Color(0x14193863);

  // Status & Feedback
  static const success = Color(0xFF10B981);
  static const successBg = Color(0xFFE8F8F2);
  static const successInk = Color(0xFF0D8A68);
  static const successRing = Color(0x3810B981);

  static const danger = Color(0xFFEF4444);
  static const dangerBg = Color(0xFFFEF2F2);

  // Navy System
  static const navy = Color(0xFF193863);
  static const navyDark = Color(0xFF142E53);
  static const navySoft = Color(0xFF1F4273);
  static const navy2 = Color(0xFF1F4273);

  // Accents & Grays
  static const mist = Color(0xFFC5D0DE);
  static const barGray = Color(0xFFCDD5E2);
  static const amber = Color(0xFFF59E0B);
  static const amberBg = Color(0x1FF59E0B);
  static const amberGlow = Color(0x38F59E0B);

  static const onDark = Color(0xFFFFFFFF);
  static const onDark2 = Color(0xB8FFFFFF); // white @ 72%
  static const onDark3 = Color(0x73FFFFFF); // white @ 45%
  static const onDarkLine = Color(0x24FFFFFF);

  /// Home screen background gradient.
  static const homeGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bg, bgGradientEnd],
  );

  /// The navy CTA & card gradient.
  static const cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navySoft, navyDark],
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
  static const shadowSm = BoxShadow(
    color: Color(0x0A193863),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  static const shadowMd = BoxShadow(
    color: Color(0x1F142E53),
    blurRadius: 36,
    offset: Offset(0, 16),
  );
}
