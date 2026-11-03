import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/scan_trace.dart';
import '../models/screening_result.dart';
import '../theme/routes.dart';
import 'referral_screen.dart';

/// Design tokens matching the result screen prototype and design specification.
class _ResultTheme {
  static const navy = Color(0xFF073858);
  static const ink = Color(0xFF3A4668);
  static const muted = Color(0xFF5B6585);
  static const line = Color(0xFFDDE2EE);
  static const bg = Color(0xFFF5F7FB);
  static const amber = Color(0xFF8A5A00);
  static const dotAmber = Color(0xFFF5A524);
  static const stepNumber = Color(0xFF8A94B0);
}

/// The updated Scanine Result Screen featuring the interactive Grad-CAM/Photo
/// comparison slider, dynamic hero compaction on accordion expand, vector
/// Scanine badge and handle icons, numbered guidance steps, and seamless
/// bottom gradient fade.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.result,
    this.trace,
  });

  final ScreeningResult result;

  /// Pre-computed Grad-CAM trace passed from AnalyzingScreen.
  final ScanTrace? trace;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  // Both accordions collapsed by default
  final Set<String> _openRows = <String>{};
  double _sliderPercent = 0.50;
  _GuidanceTab _selectedTab = _GuidanceTab.dos;

  @override
  void initState() {
    super.initState();
    _resetSelectedTab();
  }

  @override
  void didUpdateWidget(covariant ResultScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result) {
      _resetSelectedTab();
    }
  }

  void _resetSelectedTab() {
    final p = widget.result.protocol;
    if (p != null) {
      if (p.startHere.isNotEmpty) {
        _selectedTab = _GuidanceTab.dos;
      } else if (p.doNot.isNotEmpty) {
        _selectedTab = _GuidanceTab.dont;
      } else if (p.monitoring.isNotEmpty) {
        _selectedTab = _GuidanceTab.monitor;
      } else if (p.homeCare.isNotEmpty) {
        _selectedTab = _GuidanceTab.homeCare;
      }
    } else {
      _selectedTab = _GuidanceTab.dos;
    }
  }

  String get _timestamp {
    final now = DateTime.now();
    final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final m = now.minute.toString().padLeft(2, '0');
    final amPm = now.hour < 12 ? 'AM' : 'PM';
    return 'Today · $h:$m $amPm';
  }

  void _toggleRow(String key) {
    setState(() {
      if (_openRows.contains(key)) {
        _openRows.remove(key);
      } else {
        _openRows.add(key);
      }
    });
  }

  static double _guidanceContainerHeight(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return (screenHeight * 0.315).clamp(240.0, 300.0);
  }

  Widget _buildGuidanceContent(BuildContext context, TriageProtocol p) {
    final tabs = <({_GuidanceTab tab, String label, List<GuidanceStep> steps})>[];

    if (p.startHere.isNotEmpty) {
      tabs.add((
        tab: _GuidanceTab.dos,
        label: "Do's",
        steps: p.startHere,
      ));
    }
    if (p.doNot.isNotEmpty) {
      tabs.add((
        tab: _GuidanceTab.dont,
        label: "Don't",
        steps: p.doNot,
      ));
    }
    if (p.monitoring.isNotEmpty) {
      tabs.add((
        tab: _GuidanceTab.monitor,
        label: 'Monitor',
        steps: p.monitoring,
      ));
    }
    if (p.homeCare.isNotEmpty) {
      tabs.add((
        tab: _GuidanceTab.homeCare,
        label: 'Home care',
        steps: p.homeCare,
      ));
    }

    if (tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeTab = tabs.firstWhere(
      (t) => t.tab == _selectedTab,
      orElse: () => tabs.first,
    );

    return SizedBox(
      height: _guidanceContainerHeight(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left vertical rail with plain text tabs, top-aligned, not scrollable
          IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < tabs.length; i++)
                  _RailTab(
                    label: tabs[i].label,
                    isSelected: activeTab.tab == tabs[i].tab,
                    onTap: () {
                      if (_selectedTab != tabs[i].tab) {
                        setState(() {
                          _selectedTab = tabs[i].tab;
                        });
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 1px vertical hairline divider filling container's full height
          Container(
            key: const Key('guidance_divider'),
            width: 1.0,
            color: _ResultTheme.line,
          ),
          const SizedBox(width: 16),
          // Right column: expanded vertically scrollable list of steps
          Expanded(
            child: _GuidanceStepsPane(
              key: ValueKey('${identityHashCode(widget.result)}_${_selectedTab.name}'),
              steps: activeTab.steps,
            ),
          ),
        ],
      ),
    );
  }

  void _openFullscreenViewer() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.85),
        pageBuilder: (context, anim, secAnim) {
          return FadeTransition(
            opacity: anim,
            child: _FullscreenImageViewer(
              result: widget.result,
              initialPercent: _sliderPercent,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    // Keep hero height stable so opening/closing accordion rows never jerks the slider
    const double heroHeight = 360.0;

    final config = _ResultConfig.fromResult(r);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // icons on dark photo hero
        systemNavigationBarColor: _ResultTheme.bg,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _ResultTheme.bg,
        body: Stack(
          children: [
            // Scrollable view containing Hero and Body Content
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Interactive Hero with comparison slider
                    SizedBox(
                      height: heroHeight,
                      width: double.infinity,
                      child: _HeroComparisonSlider(
                        result: r,
                        height: heroHeight,
                        percent: _sliderPercent,
                        timestamp: _timestamp,
                        onPercentChanged: (p) => setState(() => _sliderPercent = p),
                        onBack: () => Navigator.of(context).popUntil((route) => route.isFirst),
                        onExpand: _openFullscreenViewer,
                      ),
                    ),

                    // Content Body
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),

                          // Status Badge (only if tag is non-empty)
                          if (config.tag.isNotEmpty) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ScanineBadgeIcon(
                                  color: config.statusColor,
                                  size: 14,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  config.tag,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: config.statusColor,
                                    fontFamily: 'InstrumentSans',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],

                        // Headline
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: 'InstrumentSans',
                              fontSize: 36,
                              height: 42 / 36,
                              letterSpacing: -0.9,
                            ),
                            children: [
                              TextSpan(
                                text: '${config.line1}\n',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w400,
                                  color: _ResultTheme.ink,
                                ),
                              ),
                              TextSpan(
                                text: config.line2,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                  color: _ResultTheme.navy,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Subtitle
                        const Text(
                          'This is a preliminary screening result only. Veterinary confirmation is still necessary.',
                          style: TextStyle(
                            fontSize: 14,
                            color: _ResultTheme.muted,
                            fontFamily: 'InstrumentSans',
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Row 0: Definition / What does this mean?
                        _AccordionRow(
                          title: config.row1Title,
                          isOpen: _openRows.contains('row1'),
                          onTap: () => _toggleRow('row1'),
                          isLast: false,
                          content: Text(
                            config.row1Text,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 23 / 16,
                              color: _ResultTheme.navy,
                              fontFamily: 'InstrumentSans',
                            ),
                          ),
                        ),

                        // Row 1: Guidance (First-response guidance or Care guidance / How to get a clearer scan)
                        _AccordionRow(
                          title: config.protocol != null ? 'First-response guidance' : config.row2Title,
                          isOpen: _openRows.contains('row2'),
                          onTap: () => _toggleRow('row2'),
                          isLast: true,
                          content: config.protocol != null
                              ? _buildGuidanceContent(context, config.protocol!)
                              : _StepsList(steps: config.row2Steps),
                        ),

                        const SizedBox(height: 16),

                        // Bottom clearance to ensure scroll past sticky action buttons
                        SizedBox(
                          height: (config.secondaryButton != null ? 148 : 96) +
                              math.max(MediaQuery.paddingOf(context).bottom, 16.0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Pinned Action Buttons with soft gradient scrim
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ActionFooter(
              primaryText: config.primaryButton,
              secondaryText: config.secondaryButton,
              onPrimaryTap: () {
                if (r.inconclusive) {
                  // Retake scan -> go back to Camera/Upload screen
                  Navigator.of(context).pop();
                } else if (r.urgency == Urgency.low) {
                  // Continue monitoring -> back to Home
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else {
                  // Refer to veterinarian
                  AppRoutes.push(
                    context,
                    (_) => ReferralScreen(result: r),
                  );
                }
              },
              onSecondaryTap: config.secondaryButton != null
                  ? () {
                      AppRoutes.push(
                        context,
                        (_) => ReferralScreen(result: r),
                      );
                    }
                  : null,
            ),
          ),
        ],
      ),
    ),
    );
  }
}

/// Helper model encapsulating texts and metadata for the result state.
class _ResultConfig {
  final String tag;
  final Color statusColor;
  final String line1;
  final String line2;
  final String row1Title;
  final String row1Text;
  final TriageProtocol? protocol;
  final String row2Title;
  final List<String> row2Steps;
  final String primaryButton;
  final String? secondaryButton;

  const _ResultConfig({
    required this.tag,
    required this.statusColor,
    required this.line1,
    required this.line2,
    required this.row1Title,
    required this.row1Text,
    this.protocol,
    required this.row2Title,
    required this.row2Steps,
    required this.primaryButton,
    this.secondaryButton,
  });

  factory _ResultConfig.fromResult(ScreeningResult result) {
    if (result.inconclusive) {
      return const _ResultConfig(
        tag: 'Low confidence',
        statusColor: _ResultTheme.amber,
        line1: 'We couldn’t get a',
        line2: 'clear read',
        row1Title: 'Why wasn’t it clear?',
        row1Text: 'The image was too blurry or dark for a reliable result.',
        protocol: null,
        row2Title: 'How to get a clearer scan',
        row2Steps: [
          'Focus on the dog’s skin, not fur or surroundings.',
          'Use bright, even light and hold the phone steady.',
          'Keep the affected area clearly in view.',
        ],
        primaryButton: 'Retake scan',
        secondaryButton: 'Refer to veterinarian',
      );
    }

    final isHealthy = result.condition.toLowerCase() == 'healthy' ||
        result.urgency == Urgency.low;

    if (isHealthy) {
      return const _ResultConfig(
        tag: '',
        statusColor: _ResultTheme.muted,
        line1: 'No signs of',
        line2: 'skin problems',
        row1Title: 'What does this mean?',
        row1Text: 'The scan did not highlight any areas of concern.',
        protocol: null,
        row2Title: 'Care guidance',
        row2Steps: [
          'Keep checking the coat weekly.',
          'Rescan if you notice redness, hair loss or scratching.',
        ],
        primaryButton: 'Continue monitoring',
        secondaryButton: null,
      );
    }

    // Condition matches (e.g. Ringworm, Hotspot, FAD)
    final cond = result.condition.toLowerCase();
    String line2 = result.condition.toLowerCase();
    String row1Title = 'What is ${result.conditionLabel}?';
    String row1Text = 'A canine skin condition requiring veterinary evaluation.';

    if (cond.contains('ringworm')) {
      line2 = 'ringworm';
      row1Title = 'What is dermatophytosis?';
      row1Text =
          'A fungal infection of the skin, hair and nails, commonly called ringworm.';
    } else if (cond.contains('hotspot') || cond.contains('hot spot')) {
      line2 = 'a hot spot';
      row1Title = 'What is acute moist dermatitis?';
      row1Text =
          'A rapidly developing, painful bacterial skin infection commonly called a hot spot.';
    } else if (cond.contains('fad') || cond.contains('flea')) {
      line2 = 'flea allergy';
      row1Title = 'What is flea allergy dermatitis?';
      row1Text =
          'An allergic reaction to flea saliva that causes intense itching, inflammation, and skin irritation.';
    }

    return _ResultConfig(
      tag: '',
      statusColor: _ResultTheme.muted,
      line1: 'This looks like',
      line2: line2,
      row1Title: row1Title,
      row1Text: row1Text,
      protocol: result.protocol,
      row2Title: '',
      row2Steps: const [],
      primaryButton: 'Refer to veterinarian',
      secondaryButton: null,
    );
  }
}

class _HeroComparisonSlider extends StatelessWidget {
  const _HeroComparisonSlider({
    required this.result,
    required this.height,
    required this.percent,
    required this.timestamp,
    required this.onPercentChanged,
    required this.onBack,
    required this.onExpand,
  });

  final ScreeningResult result;
  final double height;
  final double percent;
  final String timestamp;
  final ValueChanged<double> onPercentChanged;
  final VoidCallback onBack;
  final VoidCallback onExpand;

  bool get _showHeatmap => !result.inconclusive && result.hasHeatmap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final topBarTop = math.max(topPadding, 20.0) + 12.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final p = percent.clamp(0.04, 0.96);
        final dividerX = width * p;
        final handleY = height * 0.55;

        final isHealthy = result.condition.toLowerCase() == 'healthy' ||
            result.urgency == Urgency.low;
        final handleDotColor = isHealthy ? Colors.white : _ResultTheme.dotAmber;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            if (!_showHeatmap) return;
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final local = details.localPosition;
            onPercentChanged((local.dx / box.size.width).clamp(0.04, 0.96));
          },
          onTapDown: (details) {
            if (!_showHeatmap) return;
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final local = details.localPosition;
            onPercentChanged((local.dx / box.size.width).clamp(0.04, 0.96));
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Layer 1: Raw photo (bottom base layer)
              _buildRawLayer(),

              // Inconclusive: one even scrim over the blurred photo. The only
              // gradient left is the shared bottom fade into the page.
              if (result.inconclusive)
                IgnorePointer(
                  child: ColoredBox(
                    color: const Color(0xFF14243B).withValues(alpha: 0.35),
                  ),
                ),

              // Layer 2: Heatmap layer (clipped to percent)
              if (_showHeatmap)
                ClipRect(
                  clipper: _HorizontalClipper(p),
                  child: _buildHeatmapLayer(),
                ),

              // Bottom smooth fade into page background
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
                          _ResultTheme.bg.withValues(alpha: 0.0),
                          _ResultTheme.bg.withValues(alpha: 0.35),
                          _ResultTheme.bg.withValues(alpha: 0.80),
                          _ResultTheme.bg,
                        ],
                        stops: const [0.0, 0.35, 0.70, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // Divider line
              if (_showHeatmap)
                Positioned(
                  left: dividerX - 0.75,
                  top: 0,
                  bottom: 0,
                  width: 1.5,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.95),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          stops: const [0.55, 0.92],
                        ),
                      ),
                    ),
                  ),
                ),

              // Left chevron (<)
              if (_showHeatmap)
                Positioned(
                  left: dividerX - 58,
                  top: handleY - 8,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: ((p - 0.12) / 0.08).clamp(0.0, 1.0),
                      duration: const Duration(milliseconds: 100),
                      child: const CustomPaint(
                        size: Size(12, 16),
                        painter: _ChevronPainter(isLeft: true),
                      ),
                    ),
                  ),
                ),

              // Right chevron (>)
              if (_showHeatmap)
                Positioned(
                  left: dividerX + 46,
                  top: handleY - 8,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: ((0.88 - p) / 0.08).clamp(0.0, 1.0),
                      duration: const Duration(milliseconds: 100),
                      child: const CustomPaint(
                        size: Size(12, 16),
                        painter: _ChevronPainter(isLeft: false),
                      ),
                    ),
                  ),
                ),

              // Interactive Slider Handle
              if (_showHeatmap)
                Positioned(
                  left: dividerX - 26,
                  top: handleY - 26,
                  width: 52,
                  height: 52,
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: const Size(52, 52),
                      painter: _HandlePainter(dotColor: handleDotColor),
                    ),
                  ),
                ),

              // Tags (Heatmap on left, Photo on right)
              if (_showHeatmap) ...[
                Positioned(
                  left: 24,
                  bottom: 72,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: p < 0.22 ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: const Text(
                        'Heatmap',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'InstrumentSans',
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 24,
                  bottom: 72,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: p > 0.78 ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: const Text(
                        'Photo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'InstrumentSans',
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // No heatmap: a centred pill on the photo, clear of the light
              // bottom fade so the white text stays readable.
              if (!_showHeatmap)
                const Positioned(
                  left: 24,
                  right: 24,
                  top: 0,
                  bottom: 40,
                  child: IgnorePointer(
                    child: Center(child: _HeatmapUnavailablePill()),
                  ),
                ),

              // Top Bar (Back, Timestamp, Expand)
              Positioned(
                top: topBarTop,
                left: 24,
                right: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onBack,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),

                    // Timestamp
                    Flexible(
                      child: Text(
                        timestamp,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'InstrumentSans',
                        ),
                      ),
                    ),

                    // Expand image button
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onExpand,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRawLayer() {
    Widget imageWidget;
    if (result.imagePath != null && File(result.imagePath!).existsSync()) {
      imageWidget = Image.file(
        File(result.imagePath!),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      imageWidget = Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5A5450), Color(0xFF8F8A86)],
          ),
        ),
      );
    }

    if (result.inconclusive) {
      // Clamp the blur at the edges; the default lets it fade to transparent,
      // which showed the page colour as a halo around the photo.
      return ClipRect(
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: 10,
            sigmaY: 10,
            tileMode: TileMode.clamp,
          ),
          child: imageWidget,
        ),
      );
    }

    return imageWidget;
  }

  Widget _buildHeatmapLayer() {
    if (result.heatmap != null) {
      return Image.memory(
        result.heatmap!,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
      );
    }

    // Fallback radial gradient if heatmap byte array is not available
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.2, 0.04),
          radius: 0.8,
          colors: [
            Color(0xFFD8231F),
            Color(0xFFE8502A),
            Color(0xFFF5A524),
            Color(0xFFD4D83A),
            Color(0xFF4DBE7E),
            Color(0x002D6FB8),
          ],
          stops: [0.0, 0.14, 0.30, 0.44, 0.58, 0.80],
        ),
      ),
    );
  }
}

/// Shown in place of the heatmap slider when there is no heatmap to compare.
class _HeatmapUnavailablePill extends StatelessWidget {
  const _HeatmapUnavailablePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_off_outlined, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Heatmap not available for this scan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'InstrumentSans',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom horizontal clipper for split-view comparison.
class _HorizontalClipper extends CustomClipper<Rect> {
  final double percent;
  _HorizontalClipper(this.percent);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * percent, size.height);
  }

  @override
  bool shouldReclip(_HorizontalClipper oldClipper) =>
      oldClipper.percent != percent;
}

/// Custom painter for the comparison chevrons (< and >).
class _ChevronPainter extends CustomPainter {
  final bool isLeft;
  const _ChevronPainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    if (isLeft) {
      path.moveTo(8, 2);
      path.lineTo(3, 8);
      path.lineTo(8, 14);
    } else {
      path.moveTo(4, 2);
      path.lineTo(9, 8);
      path.lineTo(4, 14);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) =>
      oldDelegate.isLeft != isLeft;
}

/// Custom painter for the Scanine logo slider handle.
class _HandlePainter extends CustomPainter {
  final Color dotColor;
  const _HandlePainter({required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    const r = 20.0;

    // Arc from 32 deg to 328 deg (sweep 296 deg)
    final startRad = 32.0 * math.pi / 180.0;
    final sweepRad = (328.0 - 32.0) * math.pi / 180.0;

    final arcPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      startRad,
      sweepRad,
      false,
      arcPaint,
    );

    // Center dot with white outline
    final fillPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, 5.5, fillPaint);

    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(c, 5.5, strokePaint);
  }

  @override
  bool shouldRepaint(_HandlePainter oldDelegate) =>
      oldDelegate.dotColor != dotColor;
}

/// Custom widget for the status badge icon.
class _ScanineBadgeIcon extends StatelessWidget {
  final Color color;
  final double size;
  const _ScanineBadgeIcon({required this.color, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ScanineBadgePainter(color: color),
    );
  }
}

class _ScanineBadgePainter extends CustomPainter {
  final Color color;
  const _ScanineBadgePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 52.0;
    canvas.save();
    canvas.scale(scale);

    const c = Offset(26, 26);
    const r = 20.0;
    final startRad = 38.0 * math.pi / 180.0;
    final sweepRad = (322.0 - 38.0) * math.pi / 180.0;

    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = 5.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      startRad,
      sweepRad,
      false,
      arcPaint,
    );

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, 5.2, dotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScanineBadgePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Accordion row component with subtle hairlines and rotating +/- icon.
class _AccordionRow extends StatelessWidget {
  const _AccordionRow({
    required this.title,
    required this.isOpen,
    required this.onTap,
    required this.content,
    required this.isLast,
  });

  final String title;
  final bool isOpen;
  final VoidCallback onTap;
  final Widget content;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: const BorderSide(color: _ResultTheme.line, width: 1.0),
          bottom: isLast
              ? const BorderSide(color: _ResultTheme.line, width: 1.0)
              : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(minHeight: 60),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _ResultTheme.navy,
                        fontFamily: 'InstrumentSans',
                      ),
                    ),
                  ),
                  _AnimatedPlusMinus(
                    isOpen: isOpen,
                    color: _ResultTheme.muted,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: content,
            ),
            crossFadeState:
                isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 280),
            sizeCurve: Curves.easeInOutCubic,
            firstCurve: Curves.easeInOutCubic,
            secondCurve: Curves.easeInOutCubic,
          ),
        ],
      ),
    );
  }
}

/// Micro-animation that rotates vertical segment 90° into horizontal to form minus.
class _AnimatedPlusMinus extends StatelessWidget {
  final bool isOpen;
  final Color color;

  const _AnimatedPlusMinus({
    required this.isOpen,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base horizontal bar
          Container(
            width: 14,
            height: 1.6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          // Rotating vertical bar
          AnimatedRotation(
            turns: isOpen ? 0.0 : 0.25,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            child: Container(
              width: 14,
              height: 1.6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Numbered guidance steps list (01, 02, 03...).
class _StepsList extends StatelessWidget {
  final List<String> steps;
  const _StepsList({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  (i + 1).toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: _ResultTheme.stepNumber,
                    fontFamily: 'InstrumentSans',
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  steps[i],
                  style: const TextStyle(
                    fontSize: 16,
                    height: 23 / 16,
                    color: _ResultTheme.navy,
                    fontFamily: 'InstrumentSans',
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Bottom sticky action buttons with soft gradient backdrop.
class _ActionFooter extends StatelessWidget {
  final String primaryText;
  final String? secondaryText;
  final VoidCallback onPrimaryTap;
  final VoidCallback? onSecondaryTap;

  const _ActionFooter({
    required this.primaryText,
    this.secondaryText,
    required this.onPrimaryTap,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 28, 24, math.max(bottomInset, 16) + 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _ResultTheme.bg.withValues(alpha: 0.0),
            _ResultTheme.bg,
          ],
          stops: const [0.0, 0.40],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary Pill Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onPrimaryTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: _ResultTheme.navy,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),

          // Secondary Link Button (if applicable)
          if (secondaryText != null) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 44,
              child: TextButton(
                onPressed: onSecondaryTap,
                style: TextButton.styleFrom(
                  foregroundColor: _ResultTheme.navy,
                ),
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

/// Fullscreen interactive scan inspection modal.
class _FullscreenImageViewer extends StatefulWidget {
  final ScreeningResult result;
  final double initialPercent;

  const _FullscreenImageViewer({
    required this.result,
    required this.initialPercent,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late double _percent;
  bool _showComparison = true;

  @override
  void initState() {
    super.initState();
    _percent = widget.initialPercent;
  }

  @override
  Widget build(BuildContext context) {
    final hasHeat = widget.result.hasHeatmap && !widget.result.inconclusive;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    hasHeat && _showComparison
                        ? 'Heatmap Comparison'
                        : 'Scan Image',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'InstrumentSans',
                    ),
                  ),
                  if (hasHeat)
                    IconButton(
                      icon: Icon(
                        _showComparison
                            ? Icons.visibility_rounded
                            : Icons.compare_rounded,
                        color: Colors.white,
                      ),
                      tooltip: _showComparison ? 'View Raw' : 'Compare Heatmap',
                      onPressed: () {
                        setState(() => _showComparison = !_showComparison);
                      },
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),

            // Image area with interactive pinch zoom
            Expanded(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: (details) {
                            if (!hasHeat || !_showComparison) return;
                            final box = context.findRenderObject() as RenderBox?;
                            if (box == null) return;
                            final local = details.localPosition;
                            setState(() {
                              _percent = (local.dx / box.size.width)
                                  .clamp(0.04, 0.96);
                            });
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Raw Layer
                              if (widget.result.imagePath != null &&
                                  File(widget.result.imagePath!).existsSync())
                                Image.file(
                                  File(widget.result.imagePath!),
                                  fit: BoxFit.cover,
                                )
                              else
                                Container(color: Colors.grey.shade900),

                              // Heatmap Layer
                              if (hasHeat && _showComparison)
                                ClipRect(
                                  clipper: _HorizontalClipper(_percent),
                                  child: Image.memory(
                                    widget.result.heatmap!,
                                    fit: BoxFit.cover,
                                  ),
                                ),

                              // Divider
                              if (hasHeat && _showComparison)
                                Positioned(
                                  left: constraints.maxWidth * _percent - 1,
                                  top: 0,
                                  bottom: 0,
                                  width: 2,
                                  child: Container(color: Colors.white),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            if (!hasHeat)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: _HeatmapUnavailablePill(),
              ),

            // Bottom tip
            if (hasHeat && _showComparison)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Drag horizontally to wipe between Heatmap and Photo. Pinch to zoom.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontFamily: 'InstrumentSans',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
enum _GuidanceTab { dos, dont, monitor, homeCare }

class _RailTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RailTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 38.0,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            softWrap: false,
            style: TextStyle(
              fontFamily: 'InstrumentSans',
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? _ResultTheme.navy : _ResultTheme.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _GuidanceStepsPane extends StatefulWidget {
  final List<GuidanceStep> steps;

  const _GuidanceStepsPane({
    super.key,
    required this.steps,
  });

  @override
  State<_GuidanceStepsPane> createState() => _GuidanceStepsPaneState();
}

class _GuidanceStepsPaneState extends State<_GuidanceStepsPane> {
  final ScrollController _scrollController = ScrollController();
  bool _hasMoreBelow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateAffordance());
  }

  @override
  void didUpdateWidget(covariant _GuidanceStepsPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.steps != widget.steps) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateAffordance());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateAffordance() {
    if (!mounted || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final canScroll = pos.maxScrollExtent > 0;
    final hasMore = canScroll && pos.pixels < (pos.maxScrollExtent - 1.0);
    if (hasMore != _hasMoreBelow) {
      setState(() => _hasMoreBelow = hasMore);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _updateAffordance();
              if (notification is OverscrollNotification) {
                final parent = PrimaryScrollController.maybeOf(context);
                if (parent != null && parent.hasClients) {
                  parent.position.jumpTo(
                    (parent.offset + notification.overscroll)
                        .clamp(0.0, parent.position.maxScrollExtent),
                  );
                }
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(top: 9.0, bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < widget.steps.length; i++) ...[
                    if (i > 0) const SizedBox(height: 18),
                    _GuidanceStepItem(step: widget.steps[i]),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (_hasMoreBelow)
          Positioned(
            key: const Key('guidance_bottom_fade'),
            left: 0,
            right: 0,
            bottom: 0,
            height: 24.0,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _ResultTheme.bg.withValues(alpha: 0.0),
                      _ResultTheme.bg,
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GuidanceStepItem extends StatelessWidget {
  final GuidanceStep step;

  const _GuidanceStepItem({
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step.action,
          style: const TextStyle(
            fontFamily: 'InstrumentSans',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.35,
            color: _ResultTheme.navy,
          ),
        ),
        if (step.reason.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            step.reason,
            style: const TextStyle(
              fontFamily: 'InstrumentSans',
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              height: 1.45,
              color: _ResultTheme.muted,
            ),
          ),
        ],
      ],
    );
  }
}