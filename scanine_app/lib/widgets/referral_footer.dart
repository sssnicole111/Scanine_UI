import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Colours of the result screen, shared by the referral questions and
/// summary so the three read as one flow.
abstract class RefTheme {
  static const navy = Color(0xFF073858);
  static const ink = Color(0xFF3A4668);
  static const muted = Color(0xFF5B6585);
  static const line = Color(0xFFDDE2EE);
  static const bg = Color(0xFFF5F7FB);
}

/// The result screen's pinned footer: a navy pill with an arrow, an
/// optional text link under it, over a fade into the page.
class RefFooter extends StatelessWidget {
  const RefFooter({
    super.key,
    required this.primaryText,
    required this.onPrimary,
    this.secondaryText,
    this.onSecondary,
  });

  final String primaryText;
  final VoidCallback onPrimary;
  final String? secondaryText;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 28, 24, math.max(bottomInset, 16) + 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [RefTheme.bg.withValues(alpha: 0.0), RefTheme.bg],
          stops: const [0.0, 0.40],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor: RefTheme.navy,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      primaryText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'InstrumentSans',
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
          if (secondaryText != null) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 44,
              child: TextButton(
                onPressed: onSecondary,
                style: TextButton.styleFrom(foregroundColor: RefTheme.muted),
                child: Text(
                  secondaryText!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'InstrumentSans',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
