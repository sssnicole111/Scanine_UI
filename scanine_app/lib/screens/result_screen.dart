import 'dart:io';

import 'package:flutter/material.dart';

import '../models/scan_trace.dart';
import '../models/screening_result.dart';
import '../theme/routes.dart';
import 'referral_screen.dart';
import '../theme/tokens.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.result,
    this.trace,
  });

  final ScreeningResult result;

  /// Pre-computed Grad-CAM trace passed from AnalyzingScreen.
  /// When present, [result.heatmap] already matches [trace.heatmapPng].
  /// This field exists only so the type is available for future use by
  /// child widgets; the heatmap PNG is always accessed via [result.heatmap].
  final ScanTrace? trace;

  String get _timestamp {
    final now = DateTime.now();
    final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final m = now.minute.toString().padLeft(2, '0');
    return 'Today · $h:$m ${now.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(timestamp: _timestamp),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(T.s5, 0, T.s5, T.s5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroCard(result: result, trace: trace),
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
              padding: const EdgeInsets.fromLTRB(T.s5, 0, T.s5, T.s5),
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
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.timestamp});

  final String timestamp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(T.s5, T.s2, T.s5, T.s3),
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
          Text(
            timestamp,
            style: const TextStyle(
              fontSize: T.tSm,
              color: T.ink3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}


class _HeroCard extends StatefulWidget {
  const _HeroCard({required this.result, this.trace});

  final ScreeningResult result;
  final ScanTrace? trace;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  // Land on the heat map by default, not the raw photo
  bool _showHeatmap = true;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final showingHeatmap = _showHeatmap && result.hasHeatmap && !result.inconclusive;

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
            if (result.inconclusive)
              // Amber-slate gradient for inconclusive — no heatmap shown
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2C3E5A), Color(0xFF1A2A3A)],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.help_outline_rounded,
                    size: 72,
                    color: Color(0x3DF59E0B),
                  ),
                ),
              )
            else if (showingHeatmap)
              Image.memory(result.heatmap!, fit: BoxFit.cover)
            else if (result.imagePath != null)
              Image.file(File(result.imagePath!), fit: BoxFit.cover)
            else
              Container(
                decoration: const BoxDecoration(gradient: T.cardGradient),
              ),
            // Scrim so the condition text stays legible.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC000000), Color(0x00000000)],
                  stops: [0.0, 0.55],
                ),
              ),
            ),
            if (result.hasHeatmap)
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
                        onTap: () => setState(() => _showHeatmap = false),
                      ),
                      _TogglePill(
                        label: 'Heatmap',
                        active: showingHeatmap,
                        onTap: () => setState(() => _showHeatmap = true),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: T.s3,
              right: T.s3,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: T.s3, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xB3000000),
                  borderRadius: BorderRadius.circular(T.rFull),
                ),
                child: result.inconclusive
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 13, color: T.amber),
                          SizedBox(width: 4),
                          Text(
                            'Low confidence',
                            style: TextStyle(
                              color: T.amber,
                              fontSize: T.tSm,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        '${result.confidencePercent}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: T.tSm,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
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
                    result.inconclusive
                        ? 'Retake scan for a clearer result'
                        : result.conditionLabel,
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
    if (result.inconclusive) {
      return Text(
        result.totalFrames == 0
            ? 'No frame data available — please retake the scan.'
            : '${result.agreeVotes}/${result.totalFrames} '
              '${result.tta ? "augmented views" : "frames"} agreed '
              '— confidence below threshold.',
        style: const TextStyle(fontSize: T.tSm, color: T.amber),
      );
    }
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
