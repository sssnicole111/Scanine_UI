import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/screening_result.dart';
import '../theme/routes.dart';
import 'referral_screen.dart';
import '../theme/tokens.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result});

  final ScreeningResult result;

  String get _timestamp {
    final now = DateTime.now();
    final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final m = now.minute.toString().padLeft(2, '0');
    return 'Today · $h:$m ${now.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: T.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(timestamp: _timestamp),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(T.s5, 0, T.s5, T.s5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeroCard(result: result),
                      const SizedBox(height: T.s4),
                      _VoteLine(result: result),
                      const SizedBox(height: T.s4),
                      _GuidanceCard(guidance: result.guidance),
                      const SizedBox(height: T.s4),
                      const Text(
                        'Scanine is a triage aid only. Not a veterinary diagnosis.',
                        style: TextStyle(fontSize: T.tXs, color: T.ink3),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(T.s5, 0, T.s5, T.s5 + bottomPad),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (result.urgency == Urgency.low) {
                        // "Continue monitoring" — no referral warranted.
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      } else {
                        AppRoutes.push(
                          context,
                          (_) => ReferralScreen(result: result),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      // Maroon when urgent; "Continue monitoring" uses navy
                      backgroundColor: switch (result.urgency) {
                        Urgency.high => T.danger,
                        Urgency.medium => T.amber,
                        Urgency.low => T.navy,
                      },
                      padding: const EdgeInsets.symmetric(vertical: T.s4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(T.rFull),
                      ),
                      textStyle: const TextStyle(
                        fontSize: T.tBase,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(result.referralText),
                        const SizedBox(width: T.s2),
                        const Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.timestamp});

  final String timestamp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(T.s5, T.s4, T.s5, T.s3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
            customBorder: const CircleBorder(),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: T.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chevron_left, size: 20, color: T.ink),
            ),
          ),
          Row(
            children: [
              Text(
                timestamp,
                style: const TextStyle(
                  fontSize: T.tSm,
                  color: T.ink3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: T.s2),
              _PendingBadge(),
            ],
          ),
        ],
      ),
    );
  }
}

/// The quiet "two conditions still in development" marker.
class _PendingBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => const _PendingSheet(),
      ),
      customBorder: const CircleBorder(),
      child: const SizedBox(
        width: 22,
        height: 22,
        child: Icon(Icons.error_outline, size: 15, color: T.ink3),
      ),
    );
  }
}

class _PendingSheet extends StatelessWidget {
  const _PendingSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: T.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rLg)),
      ),
      padding: const EdgeInsets.fromLTRB(T.s5, T.s3, T.s5, T.s6),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x24101B34),
                  borderRadius: BorderRadius.circular(T.rFull),
                ),
              ),
            ),
            const SizedBox(height: T.s5),
            const Text(
              'In development',
              style: TextStyle(
                fontSize: T.tBase,
                fontWeight: FontWeight.w700,
                color: T.ink,
              ),
            ),
            const SizedBox(height: T.s2),
            const Text(
              'Scanine currently reports ringworm and dermatologically '
              'normal skin. Two conditions from the full model are still '
              'being trained:',
              style: TextStyle(fontSize: T.tSm, color: T.ink2, height: 1.5),
            ),
            const SizedBox(height: T.s4),
            ...kPendingClasses.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: T.s3),
                child: Container(
                  padding: const EdgeInsets.only(left: T.s3),
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: T.amber, width: 2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        style: const TextStyle(
                          fontSize: T.tSm,
                          fontWeight: FontWeight.w600,
                          color: T.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.description,
                        style: const TextStyle(
                          fontSize: T.tXs,
                          color: T.ink3,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: T.s2),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: T.bg,
                  foregroundColor: T.ink,
                  padding: const EdgeInsets.symmetric(vertical: T.s3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(T.rFull),
                  ),
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero card
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCard extends StatefulWidget {
  const _HeroCard({required this.result});

  final ScreeningResult result;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  // Show heatmap by default when it is available and the result is conclusive.
  bool _showHeatmap = true;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    // Inconclusive results never have a meaningful heatmap to show.
    final heatmapAvailable = result.hasHeatmap && !result.inconclusive;
    final showingHeatmap = _showHeatmap && heatmapAvailable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(T.rLg),
          child: SizedBox(
            height: 320,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Background image ─────────────────────────────
                if (showingHeatmap)
                  Image.memory(result.heatmap!, fit: BoxFit.cover)
                else if (result.imagePath != null)
                  Image.file(File(result.imagePath!), fit: BoxFit.cover)
                else
                  Container(
                    decoration: const BoxDecoration(gradient: T.cardGradient),
                  ),

                // ── Scrim so text stays legible ──────────────────
                // For inconclusive results use a heavier, uniform scrim so
                // gradient artefacts don't show.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: result.inconclusive
                        ? const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0xDD000000), Color(0x44000000)],
                            stops: [0.0, 0.7],
                          )
                        : const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0xCC000000), Color(0x00000000)],
                            stops: [0.0, 0.55],
                          ),
                  ),
                ),

                // ── Photo / Heatmap toggle (only when conclusive) ─
                if (heatmapAvailable)
                  Positioned(
                    top: T.s3,
                    left: T.s3,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0x8A000000),
                        borderRadius: BorderRadius.circular(T.rFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TogglePill(
                            label: 'Photo',
                            active: !showingHeatmap,
                            onTap: () =>
                                setState(() => _showHeatmap = false),
                          ),
                          _TogglePill(
                            label: 'Heatmap',
                            active: showingHeatmap,
                            onTap: () =>
                                setState(() => _showHeatmap = true),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── "Heatmap not available" badge (inconclusive) ──
                if (result.inconclusive)
                  Positioned(
                    top: T.s3,
                    left: T.s3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: T.s3, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0x8A000000),
                        borderRadius: BorderRadius.circular(T.rFull),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.white70, size: 13),
                          SizedBox(width: 5),
                          Text(
                            'Heatmap not available',
                            style: TextStyle(
                              fontSize: T.tXs,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Confidence badge ─────────────────────────────
                Positioned(
                  top: T.s3,
                  right: T.s3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: T.s3, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xB3000000),
                      borderRadius: BorderRadius.circular(T.rFull),
                    ),
                    child: Text(
                      '${result.confidencePercent}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: T.tSm,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                // ── Condition label ──────────────────────────────
                Positioned(
                  left: T.s5,
                  right: T.s5,
                  bottom: T.s5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.condition,
                        style: const TextStyle(
                          fontSize: T.tXl,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.32,
                        ),
                      ),
                      Text(
                        result.conditionLabel,
                        style: const TextStyle(
                          fontSize: T.tBase,
                          color: Color(0xCCFFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: T.s3, vertical: 5),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(T.rFull),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: T.tSm,
            fontWeight: FontWeight.w600,
            color: active ? T.ink : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _VoteLine extends StatelessWidget {
  const _VoteLine({required this.result});

  final ScreeningResult result;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${result.agreeVotes}/${result.totalFrames} '
      '${result.tta ? "augmented views" : "frames"} agreed '
      'on ${result.condition}',
      style: const TextStyle(fontSize: T.tSm, color: T.ink2),
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({required this.guidance});

  final List<String> guidance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(T.s5),
      decoration: BoxDecoration(
        color: T.surface,
        borderRadius: BorderRadius.circular(T.rLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FIRST-RESPONSE GUIDANCE',
            style: TextStyle(
              fontSize: T.tXs,
              fontWeight: FontWeight.w700,
              color: T.ink3,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: T.s4),
          ...guidance.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: T.s3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: T.navy,
                    ),
                  ),
                  const SizedBox(width: T.s2 + 2),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(
                        fontSize: T.tBase,
                        color: T.ink,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
