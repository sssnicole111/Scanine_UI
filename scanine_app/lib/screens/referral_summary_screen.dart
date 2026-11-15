import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/referral_answers.dart';
import '../models/screening_result.dart';
import '../theme/routes.dart';
import '../widgets/referral_footer.dart';
import 'referral_screen.dart';

/// One screen for the owner to show the vet: the photo (with the heatmap
/// for a condition), what it screened as, and the owner's answers written
/// as plain sentences. Laid out like the result screen.
class ReferralSummaryScreen extends StatelessWidget {
  const ReferralSummaryScreen({
    super.key,
    required this.result,
    required this.answers,
  });

  final ScreeningResult result;
  final ReferralAnswers answers;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _timestamp {
    final now = DateTime.now();
    final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final m = now.minute.toString().padLeft(2, '0');
    final amPm = now.hour < 12 ? 'AM' : 'PM';
    return '${now.day} ${_months[now.month - 1]} ${now.year}, $h:$m $amPm';
  }

  bool get _healthy =>
      !result.inconclusive &&
      (result.condition.toLowerCase() == 'healthy' ||
          result.urgency == Urgency.low);

  String get _screenedAs {
    if (result.inconclusive) return 'inconclusive';
    if (_healthy) return 'healthy skin';
    final c = result.condition.toLowerCase();
    if (c.contains('ringworm')) return 'ringworm';
    if (c.contains('hotspot') || c.contains('hot spot')) return 'a hot spot';
    if (c.contains('fad') || c.contains('flea')) return 'flea allergy';
    return c;
  }

  String get _evidence {
    final pct = result.confidencePercent;
    if (result.tta || result.totalFrames <= 1) {
      return '$pct% confidence, from one uploaded photo.';
    }
    return '$pct% confidence, with ${result.agreeVotes} of '
        '${result.totalFrames} frames agreeing.';
  }

  @override
  Widget build(BuildContext context) {
    const heroHeight = 300.0;
    final top = MediaQuery.of(context).padding.top;
    final showHeat = !result.inconclusive && result.hasHeatmap && !_healthy;
    final hasPhoto =
        result.imagePath != null && File(result.imagePath!).existsSync();

    final spans = <TextSpan>[TextSpan(text: _evidence)];
    for (final s in answers.sentences()) {
      spans.add(const TextSpan(text: ' '));
      for (final (text, bold) in s) {
        spans.add(TextSpan(
          text: text,
          style: bold
              ? const TextStyle(
                  fontWeight: FontWeight.w600, color: RefTheme.navy)
              : null,
        ));
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: RefTheme.bg,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: RefTheme.bg,
        body: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 160),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: heroHeight,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (showHeat)
                            Image.memory(result.heatmap!, fit: BoxFit.cover)
                          else if (hasPhoto)
                            Image.file(File(result.imagePath!),
                                fit: BoxFit.cover)
                          else
                            const ColoredBox(color: Color(0xFF6F6A66)),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 150,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      RefTheme.bg.withValues(alpha: 0.0),
                                      RefTheme.bg.withValues(alpha: 0.35),
                                      RefTheme.bg.withValues(alpha: 0.80),
                                      RefTheme.bg,
                                    ],
                                    stops: const [0.0, 0.35, 0.70, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: math.max(top, 20.0) + 4,
                            left: 8,
                            right: 20,
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                  icon: const Icon(Icons.chevron_left_rounded,
                                      size: 28, color: Colors.white),
                                  tooltip: 'Back',
                                ),
                                const Spacer(),
                                Text(
                                  _timestamp,
                                  style: const TextStyle(
                                    fontFamily: 'InstrumentSans',
                                    fontSize: 13,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                          color: Color(0x66000000),
                                          blurRadius: 6),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -24),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Scanine screening summary',
                              style: TextStyle(
                                fontFamily: 'InstrumentSans',
                                fontSize: 13,
                                color: RefTheme.muted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontFamily: 'InstrumentSans',
                                  fontSize: 32,
                                  height: 38 / 32,
                                  letterSpacing: -0.8,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Screened as\n',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      color: RefTheme.ink,
                                    ),
                                  ),
                                  TextSpan(
                                    text: _screenedAs,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                      color: RefTheme.navy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontFamily: 'InstrumentSans',
                                  fontSize: 15,
                                  height: 1.6,
                                  color: RefTheme.ink,
                                ),
                                children: spans,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.only(top: 12),
                              decoration: const BoxDecoration(
                                border: Border(
                                    top: BorderSide(color: RefTheme.line)),
                              ),
                              child: const Text(
                                'Preliminary screening only, not a veterinary '
                                'diagnosis.',
                                style: TextStyle(
                                  fontFamily: 'InstrumentSans',
                                  fontSize: 13,
                                  color: RefTheme.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RefFooter(
                primaryText: 'Find a vet',
                onPrimary: () => AppRoutes.push(
                  context,
                  (_) => ReferralScreen(result: result, answers: answers),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
