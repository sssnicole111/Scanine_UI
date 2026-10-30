// scanine splash screen, as one self-contained Flutter widget. No packages needed.
//
// What it does, in order (5.05 s in total):
//   0.00 - 0.85 s  cloud background, settling and waiting on open before drawing starts
//   0.85 - 2.55 s  "canine" draws itself stroke by stroke, centred on its own
//   2.60 - 3.48 s  a light grey scan line sweeps right to left, showing only inside the letters,
//                  then prints the s while the word glides right to sit centred as "scanine"
//   3.45 - 3.95 s  the tagline "scan + screen + care" fades in
//   3.95 - 4.45 s  everything holds still for half a second
//   4.45 - 4.80 s  the wordmark and tagline fade out, then onFinished is called
//
// SETUP
// 1. Copy this file into your project, for example lib/splash/scanine_splash.dart.
//
// 2. Add the tagline font. Download "Urbanist" from Google Fonts, put Urbanist-Medium.ttf in
//    assets/fonts/, and declare it in pubspec.yaml:
//
//      flutter:
//        fonts:
//          - family: Urbanist
//            fonts:
//              - asset: assets/fonts/Urbanist-Medium.ttf
//                weight: 500
//
//    If the font is missing, Flutter silently falls back to the system font; nothing breaks.
//    If you already use the google_fonts package you can pass
//    taglineStyle: GoogleFonts.urbanist(fontWeight: FontWeight.w500) instead, but a bundled font
//    is better for a splash because it is there on the very first frame.
//
// 3. Show it first and move on when it finishes:
//
//      class SplashScreen extends StatelessWidget {
//        const SplashScreen({super.key});
//
//        @override
//        Widget build(BuildContext context) {
//          return ScanineSplash(
//            onFinished: () {
//              Navigator.of(context).pushReplacement(
//                PageRouteBuilder<void>(
//                  transitionDuration: const Duration(milliseconds: 250),
//                  pageBuilder: (_, __, ___) => const HomeScreen(),
//                  transitionsBuilder: (_, animation, __, child) =>
//                      FadeTransition(opacity: animation, child: child),
//                ),
//              );
//            },
//          );
//        }
//      }
//
//      // in main.dart:  MaterialApp(home: const SplashScreen())
//
// 4. Optional but worth doing: set the native launch screen (the one shown before Flutter starts)
//    to the same flat colour, #EEF1F6, so there is no flash before the first frame.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// ----- colours -----
const Color _ink = Color(0xFF1F3864); // navy: the finished letters
const Color _lead2 = Color(0xFF7888AB); // each stroke is led by two paler copies of itself,
const Color _lead1 = Color(0xFFC2CBDC); // this one first, then the one above, then navy
const Color _scanLine = Color(0xFFDCE1EB); // the scan line: light grey
const Color _scanWake = Color(0xFF8E99B0); // the wake behind it: a mid grey that fades back to navy
const Color _taglineInk = Color(0xFF5A6A8C); // tagline words
const Color _taglinePlus = Color(0x8C5A6A8C); // the plus signs: the same colour at 55%
const Color _cloud = Color(0xFFEEF1F6); // background
const Color _cloudHi = Color(0xFFF9FAFD); // a touch brighter in the middle
const Color _cloudLo = Color(0xFFE6EAF2); // a touch deeper at the corners

// ----- timing, on the motion's own clock (in seconds) -----
const double _motionLength = 4.20;
const double _firstStroke = 0.85; // when the c starts drawing (calm pause after app opens)
const double _perLetter = 0.17; // delay from one letter to the next (smoother, more visible drawing)
const double _strokeTime = 0.60; // how long one stroke takes to draw
const double _echoLag = 0.08; // delay between the pale copy, the mid copy and the navy stroke
const double _sweepStart = 2.60; // the scan line enters at the e
const double _sweepEnd = 3.45; // and leaves past the s
const double _glideStart = 3.00; // the word glides to its final place while the s is printed
const double _glideEnd = 3.48;
const double _taglineStart = 3.45;
const double _taglineEnd = 3.95;

// ----- sizes, in design units (the design is 390 wide; the widget scales to fit the screen) -----
const double _designWidth = 390;
const double _typeHeightScale = 0.91; // balanced typography height scale (not too tall, not shrinked)
const double _slit = 7; // width of the scan line
const double _wake = 84; // length of the wake behind it
const double _taglineDrop = 56; // tagline baseline, measured down from the middle of the letters
const double _taglineRise = 6; // how far the tagline rises as it fades in

/// The scanine splash. It plays once, then calls [onFinished].
class ScanineSplash extends StatefulWidget {
  const ScanineSplash({
    super.key,
    required this.onFinished,
    this.taglineStyle,
    this.hold = const Duration(milliseconds: 500),
    this.fadeOut = const Duration(milliseconds: 350),
    this.patternAsset = 'assets/images/splash_pattern.png',
    this.patternOpacity = 0.70,
  });

  /// Optional subtle background texture pattern asset path.
  final String? patternAsset;

  /// Opacity of the background texture pattern (0.0 to 1.0).
  final double patternOpacity;

  /// Called once, when the splash has finished fading out. Open the next screen here.
  final VoidCallback onFinished;

  /// Merged over the tagline's own style (Urbanist, weight 500, 17.85, muted navy).
  /// Leave it out when Urbanist is declared in pubspec.yaml.
  final TextStyle? taglineStyle;

  /// How long the finished splash stays still before it fades.
  final Duration hold;

  /// How long the fade to the next screen takes.
  final Duration fadeOut;

  /// Length of the motion itself, before the hold.
  static const Duration motion = Duration(milliseconds: 4200);

  @override
  State<ScanineSplash> createState() => _ScanineSplashState();
}

class _ScanineSplashState extends State<ScanineSplash> with SingleTickerProviderStateMixin {
  final _Wordmark _wordmark = _Wordmark();
  late final AnimationController _clock;
  late final double _motion, _hold, _fadeOut; // in seconds
  late TextPainter _tagline;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _motion = ScanineSplash.motion.inMicroseconds / 1e6;
    _hold = widget.hold.inMicroseconds / 1e6;
    _fadeOut = widget.fadeOut.inMicroseconds / 1e6;
    _clock = AnimationController(
      vsync: this,
      duration: ScanineSplash.motion + widget.hold + widget.fadeOut,
      // Keep the real duration even when the device asks for reduced motion;
      // that case is handled below by skipping straight to the finished frame.
      animationBehavior: AnimationBehavior.preserve,
    )..addStatusListener(_onStatus);
    _tagline = _layOutTagline();
    // A font that arrives late (for example through google_fonts) changes the tagline's width.
    PaintingBinding.instance.systemFonts.addListener(_onFontsChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    // With reduced motion on, nothing draws or sweeps: the finished wordmark appears, holds and fades.
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _clock.forward(from: _motion / (_motion + _hold + _fadeOut));
    } else {
      // Wait for the first frame to complete so the screen is ready and visible before motion starts
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _clock.forward(from: 0.0);
        }
      });
    }
  }

  @override
  void didUpdateWidget(ScanineSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taglineStyle != widget.taglineStyle) {
      _replaceTagline();
    }
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onFontsChanged);
    _clock.dispose();
    _tagline.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    // Wait for the current frame to finish, so onFinished is always free to navigate.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onFinished();
      }
    });
  }

  void _onFontsChanged() {
    if (mounted) {
      setState(_replaceTagline);
    }
  }

  void _replaceTagline() {
    final TextPainter old = _tagline;
    _tagline = _layOutTagline();
    old.dispose();
  }

  TextPainter _layOutTagline() {
    const TextStyle base = TextStyle(
      fontFamily: 'Urbanist',
      fontWeight: FontWeight.w500,
      fontSize: 17.85,
      letterSpacing: 0.0,
      height: 1.0,
      color: _taglineInk,
    );
    const TextStyle plus = TextStyle(color: _taglinePlus);
    return TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      text: TextSpan(
        style: base.merge(widget.taglineStyle),
        children: const <InlineSpan>[
          TextSpan(text: 'scan'),
          TextSpan(text: ' + ', style: plus),
          TextSpan(text: 'screen'),
          TextSpan(text: ' + ', style: plus),
          TextSpan(text: 'care'),
        ],
      ),
    )..layout();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Transparent bars so the splash colour extends edge-to-edge.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Semantics(
        label: 'scanine. scan, screen, care.',
        textDirection: TextDirection.ltr,
        image: true,
        child: RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Base cloud background
              const DecoratedBox(
                decoration: BoxDecoration(color: _cloud),
              ),
              // 2. Subtle watercolor pattern texture
              if (widget.patternAsset != null)
                Opacity(
                  opacity: widget.patternOpacity,
                  child: Image.asset(
                    widget.patternAsset!,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              // 3. Foreground animated wordmark, sweep & tagline
              SizedBox.expand(
                child: CustomPaint(
                  painter: _SplashPainter(
                    clock: _clock,
                    wordmark: _wordmark,
                    tagline: _tagline,
                    motion: _motion,
                    hold: _hold,
                    fadeOut: _fadeOut,
                    hasPattern: widget.patternAsset != null,
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

class _SplashPainter extends CustomPainter {
  _SplashPainter({
    required this.clock,
    required this.wordmark,
    required this.tagline,
    required this.motion,
    required this.hold,
    required this.fadeOut,
    this.hasPattern = false,
  }) : super(repaint: clock);

  final Animation<double> clock;
  final _Wordmark wordmark;
  final TextPainter tagline;
  final double motion, hold, fadeOut; // in seconds
  final bool hasPattern;

  // Everything that fades out together lives inside this box (design units, centred on the screen).
  static const Rect _sceneBounds = Rect.fromLTRB(-195, -80, 195, 110);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final double seconds = clock.value * (motion + hold + fadeOut);
    // The same moment on the motion's own clock. It stops at the end of the motion,
    // so the picture stays still through the hold and the fade.
    final double m = math.min(seconds / motion, 1.0) * _motionLength;

    _paintBackground(canvas, size);

    final double opacity = 1 - _inOutSine(_seg(seconds, motion + hold, motion + hold + fadeOut));
    if (opacity <= 0) {
      return;
    }

    // From here on the canvas is in design units, with the origin at the centre of the screen
    // and the middle of the letters on y = 0.
    final double scale = (size.shortestSide / _designWidth).clamp(0.85, 1.5).toDouble();
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    if (opacity < 1) {
      canvas.saveLayer(_sceneBounds, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    }
    _paintWordmark(canvas, m);
    _paintTagline(canvas, m);
    if (opacity < 1) {
      canvas.restore();
    }
    canvas.restore();
  }

  // A soft oval glow: centred just above the middle, reaching 72% of the width and of the height.
  void _paintBackground(Canvas canvas, Size size) {
    final double w = size.width, h = size.height;
    if (!hasPattern) {
      canvas.drawRect(Offset.zero & size, Paint()..color = _cloud);
    }
    canvas.save();
    canvas.translate(0.5 * w, 0.49 * h);
    canvas.scale(0.72 * w, 0.72 * h);
    canvas.drawRect(
      const Rect.fromLTRB(-0.5 / 0.72, -0.49 / 0.72, 0.5 / 0.72, 0.51 / 0.72),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          1,
          hasPattern
              ? const <Color>[
                  Color(0x25F9FAFD),
                  Color(0x00EEF1F6),
                  Color(0x20E6EAF2),
                ]
              : const <Color>[_cloudHi, _cloud, _cloudLo],
          const <double>[0, 0.5, 1],
        ),
    );
    canvas.restore();
  }

  void _paintWordmark(Canvas canvas, double m) {
    final _Wordmark w = wordmark;
    // Where the scan line is, in design units. It travels from the right edge of the e to the left edge of the s.
    final double scanX = _lerp(w.scanFrom, w.scanTo, _settle.transform(_seg(m, _sweepStart, _sweepEnd)));
    // It fades in as it enters and out as it leaves.
    final double on = _seg(m, _sweepStart, _sweepStart + 0.08) * (1 - _seg(m, _sweepEnd - 0.10, _sweepEnd));
    // Left edge of the word. "canine" starts centred by itself and glides right as the s is printed.
    final double wordX = w.restX - w.shift * (1 - _settle.transform(_seg(m, _glideStart, _glideEnd)));
    // The scan line's position measured from the word's own left edge.
    final double cut = scanX - wordX;

    canvas.save();
    canvas.translate(wordX, _Wordmark.baseline * _typeHeightScale);
    canvas.scale(1.0, _typeHeightScale);
    w.paintDrawing(canvas, m, cut);
    if (on > 0) {
      // The wake: a grey copy of the letters, strongest right behind the line and fading out to the right.
      _paintThroughBand(
        canvas,
        cut,
        Rect.fromLTRB(cut + _slit - 2, _Wordmark.top, cut + _slit - 2 + _wake, _Wordmark.bottom),
        _scanWake,
        <double>[0.85 * on, 0],
        const <double>[0, 1],
      );
      // The line itself: a light copy of the letters seen through a narrow slit with soft edges.
      _paintThroughBand(
        canvas,
        cut,
        Rect.fromLTRB(cut - 1, _Wordmark.top, cut - 1 + _slit, _Wordmark.bottom),
        _scanLine,
        <double>[0, on, on, 0],
        const <double>[0, 0.35, 0.65, 1],
      );
    }
    canvas.restore();
  }

  // Paints the letters in one flat colour, but only inside [band], and with their strength
  // following [alphas] from the band's left edge to its right edge. Because it is always a copy
  // of the letters, the scan line can never show outside them.
  void _paintThroughBand(
    Canvas canvas,
    double cut,
    Rect band,
    Color color,
    List<double> alphas,
    List<double> stops,
  ) {
    canvas.save();
    canvas.clipRect(band);
    canvas.saveLayer(band, Paint());
    wordmark.paintSolid(canvas, color, cut);
    canvas.drawRect(
      band,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          band.centerLeft,
          band.centerRight,
          <Color>[for (final double a in alphas) Color.fromRGBO(0, 0, 0, a)],
          stops,
        ),
    );
    canvas.restore();
    canvas.restore();
  }

  // The tagline fades in as one line, rising a few pixels into place.
  void _paintTagline(Canvas canvas, double m) {
    final double a = _outCubic(_seg(m, _taglineStart, _taglineEnd));
    if (a <= 0) {
      return;
    }
    final double ascent = tagline.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final Offset at = Offset(-tagline.width / 2, _taglineDrop + (1 - a) * _taglineRise - ascent);
    if (a < 1) {
      canvas.saveLayer((at & tagline.size).inflate(4), Paint()..color = Color.fromRGBO(0, 0, 0, a));
    }
    tagline.paint(canvas, at);
    if (a < 1) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SplashPainter oldDelegate) {
    return oldDelegate.clock != clock ||
        oldDelegate.tagline != tagline ||
        oldDelegate.motion != motion ||
        oldDelegate.hold != hold ||
        oldDelegate.fadeOut != fadeOut ||
        oldDelegate.hasPattern != hasPattern;
  }
}

/// One pen stroke of a letter, and when it is drawn.
class _Stroke {
  _Stroke(this.path, this.start, this.duration) : metric = path.computeMetrics().first;

  final Path path;
  final ui.PathMetric metric; // lets a stroke be drawn part of the way
  final double start;
  final double duration;
}

/// The lowercase "scanine" lettering. Built once, in its own units: x runs from the left edge of
/// the s, y = 0 is the baseline and up is negative. Letters are 38 tall with an 8 wide stroke.
class _Wordmark {
  _Wordmark() {
    _build();
  }

  static const double _xHeight = 38;
  static const double _bowl = 15; // radius of the round letters, measured to the middle of the stroke
  static const double _middle = -19; // the middle of the letters' height
  static const double _iconSize = 19.0;
  static const double _dotPop = 0.22; // how long the dot of the i takes to pop in

  /// Where the baseline sits below the middle of the letters.
  static const double baseline = 19;

  /// Top and bottom of everything the letters can cover, with a little room to spare.
  static const double top = -72, bottom = 8;

  final List<List<_Stroke>> _letters = <List<_Stroke>>[];
  late final Offset _dotCentre;
  late final double _dotStart;
  late final double _sRight; // right edge of the s

  /// Left edge of the finished word, with the word centred on x = 0.
  late final double restX;

  /// How far left of [restX] the word sits while only "canine" is showing, so that it is centred alone.
  late final double shift;

  /// Where the scan line starts and ends.
  late final double scanFrom, scanTo;

  final Paint _pen = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 8
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.miter;

  // Angles are in degrees, measured clockwise on screen from "3 o'clock" (so -90 is the top).
  static double _deg(double degrees) => degrees * math.pi / 180;

  void _build() {
    double x = 0; // left edge of the next letter
    double startOf(int letter) => _firstStroke + (letter - 1) * _perLetter;

    // s: two stacked ovals, drawn top to bottom in one stroke. It is not part of the opening
    // draw (the scan line reveals it), so it starts "long ago" and is always complete.
    {
      const double rx = 10.5, ry = 7.5;
      final double cx = x + 4 + rx;
      final Path path = Path()
        ..arcTo(Rect.fromCenter(center: Offset(cx, -26.5), width: 2 * rx, height: 2 * ry), _deg(-28), _deg(-242), true)
        ..arcTo(Rect.fromCenter(center: Offset(cx, -11.5), width: 2 * rx, height: 2 * ry), _deg(-90), _deg(242), false);
      _letters.add(<_Stroke>[_Stroke(path, -9, _strokeTime * 1.1)]);
      _sRight = 2 * rx + 8;
      x += _sRight + 4;
    }
    final double canineLeft = x;

    // c: most of a circle, open on the right
    {
      final double cx = x + 4 + _bowl;
      final Path path = Path()
        ..arcTo(Rect.fromCircle(center: Offset(cx, _middle), radius: _bowl), _deg(-42), _deg(-276), true);
      _letters.add(<_Stroke>[_Stroke(path, startOf(1), _strokeTime)]);
      x += 4 + _bowl + _bowl * math.cos(_deg(42)) + 2.7 + 3;
    }

    // a: the stem rises, then the bowl swings round from it
    {
      final double cx = x + 4 + _bowl;
      final Rect circle = Rect.fromCircle(center: Offset(cx, _middle), radius: _bowl);
      final Path bowl = Path()
        ..arcTo(circle, 0, -math.pi, true)
        ..arcTo(circle, -math.pi, -math.pi, false);
      _letters.add(<_Stroke>[
        _Stroke(bowl, startOf(2) + 0.10, _strokeTime),
        _stem(cx + _bowl, startOf(2)),
      ]);
      x += 2 * _bowl + 8 + 6;
    }

    // n
    _letters.add(_n(x, startOf(3)));
    x += 29 + 6;

    // i: the stem, then the dot pops
    _letters.add(<_Stroke>[_stem(x + 4, startOf(4))]);
    _dotCentre = Offset(x + 4, -_xHeight - 16.5);
    _dotStart = startOf(4) + 0.28;
    x += 8 + 6;

    // n
    _letters.add(_n(x, startOf(5)));
    x += 29 + 6;

    // e: the bar, then all the way round
    {
      final double cx = x + 4 + _bowl;
      final Path path = Path()
        ..moveTo(cx - _bowl, _middle)
        ..lineTo(cx + _bowl, _middle)
        ..arcTo(Rect.fromCircle(center: Offset(cx, _middle), radius: _bowl), 0, _deg(-320), false);
      _letters.add(<_Stroke>[_Stroke(path, startOf(6), _strokeTime * 1.1)]);
      x += 2 * _bowl + 8;
    }

    final double width = x;
    restX = -width / 2;
    shift = canineLeft / 2;
    scanFrom = restX - shift + width + 4;
    scanTo = restX - 8;
  }

  _Stroke _stem(double x, double start) {
    return _Stroke(
      Path()
        ..moveTo(x, 0)
        ..lineTo(x, -_xHeight),
      start,
      _strokeTime * 0.8,
    );
  }

  List<_Stroke> _n(double x, double start) {
    const double arch = 10.5; // radius of the arch
    final double sx = x + 4;
    final Path path = Path()
      ..arcTo(Rect.fromCircle(center: Offset(sx + arch, -23.5), radius: arch), math.pi, math.pi, true)
      ..lineTo(sx + 2 * arch, 0);
    return <_Stroke>[_stem(sx, start), _Stroke(path, start + 0.10, _strokeTime)];
  }

  /// The wordmark at moment [m]: each stroke arrives as a pale copy, then a mid copy, then navy.
  /// The s shows only to the right of [cut], which is where the scan line has already been.
  void paintDrawing(Canvas canvas, double m, double cut) {
    for (int i = 0; i < _letters.length; i++) {
      if (i == 0 && !_openS(canvas, cut)) {
        continue;
      }
      for (final _Stroke s in _letters[i]) {
        final double navyFrom = s.start + 2 * _echoLag;
        final double navy = _draw(_seg(m, navyFrom, navyFrom + s.duration));
        if (navy < 1) {
          _trace(canvas, s, _draw(_seg(m, s.start, s.start + s.duration)), _lead1);
          _trace(canvas, s, _draw(_seg(m, s.start + _echoLag, s.start + _echoLag + s.duration)), _lead2);
        }
        _trace(canvas, s, navy, _ink);
      }
      if (i == 0) {
        canvas.restore();
      }
    }
    if (m >= _dotStart) {
      final double pop = _softBack(_seg(m, _dotStart, _dotStart + _dotPop));
      _paintIcon(
        canvas,
        pop,
        navyColor: _ink,
        grayColor: const Color(0xFFC5CAD6),
      );
    }
  }

  /// The finished wordmark in one flat [color], with the s still cut off at [cut].
  void paintSolid(Canvas canvas, Color color, double cut) {
    _pen.color = color;
    for (int i = 0; i < _letters.length; i++) {
      if (i == 0 && !_openS(canvas, cut)) {
        continue;
      }
      for (final _Stroke s in _letters[i]) {
        canvas.drawPath(s.path, _pen);
      }
      if (i == 0) {
        canvas.restore();
      }
    }
    _paintIcon(
      canvas,
      1.0,
      navyColor: color,
      grayColor: color,
      uniformColor: true,
    );
  }

  /// Paints the official Scanine brand mark icon replacing the dot above the "i".
  /// Consists of five separate outer C-shaped segments, a fixed navy center dot,
  /// and a right-facing opening.
  void _paintIcon(
    Canvas canvas,
    double pop, {
    required Color navyColor,
    required Color grayColor,
    bool uniformColor = false,
  }) {
    if (pop <= 0.001) return;

    final double size = _iconSize * pop;
    final double arcRadius = size * (72.0 / 192.0);
    final double strokeWidth = size * (24.0 / 192.0);
    final double dotRadius = size * (19.5 / 192.0);

    // Segment definitions (in degrees, clockwise from 3 o'clock):
    // 1. Lower right: 35.0° -> 87.0° (sweep 52.0°)
    // 2. Lower left:  95.0° -> 147.0° (sweep 52.0°)
    // 3. Left:        155.0° -> 207.0° (sweep 52.0°)
    // 4. Upper left:  215.0° -> 267.0° (sweep 52.0°)
    // 5. Upper right: 275.0° -> 327.0° (sweep 52.0°)
    const segmentAngles = [
      (35.0, 52.0),
      (95.0, 52.0),
      (155.0, 52.0),
      (215.0, 52.0),
      (275.0, 52.0),
    ];

    final rect = Rect.fromCircle(center: Offset.zero, radius: arcRadius);

    canvas.save();
    canvas.translate(_dotCentre.dx, _dotCentre.dy);
    // Counteract _typeHeightScale so the icon is rendered as a true circle
    canvas.scale(1.0, 1.0 / _typeHeightScale);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    for (int i = 0; i < 5; i++) {
      final isNavy = uniformColor || (i < 3);
      strokePaint.color = isNavy ? navyColor : grayColor;
      final (startDeg, sweepDeg) = segmentAngles[i];
      final startRad = startDeg * (math.pi / 180.0);
      final sweepRad = sweepDeg * (math.pi / 180.0);
      canvas.drawArc(rect, startRad, sweepRad, false, strokePaint);
    }

    final dotPaint = Paint()
      ..color = navyColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, dotRadius, dotPaint);

    canvas.restore();
  }

  // Limits painting to the part of the s that the scan line has passed. Returns false, having
  // changed nothing, when no part of the s is showing yet; otherwise the caller must restore.
  bool _openS(Canvas canvas, double cut) {
    if (cut >= _sRight + 1) {
      return false;
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(cut, top, _sRight + 1, bottom));
    return true;
  }

  void _trace(Canvas canvas, _Stroke s, double progress, Color color) {
    if (progress <= 0.001) {
      return;
    }
    final Path path = progress >= 1 ? s.path : s.metric.extractPath(0, s.metric.length * progress);
    canvas.drawPath(path, _pen..color = color);
  }
}

// ----- easing -----

/// How far [x] is from [a] to [b], held at 0 before [a] and at 1 after [b].
double _seg(double x, double a, double b) {
  if (b <= a) {
    return x >= b ? 1.0 : 0.0;
  }
  return ((x - a) / (b - a)).clamp(0.0, 1.0).toDouble();
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _outCubic(double x) {
  final double u = 1 - x;
  return 1 - u * u * u;
}

double _inOutCubic(double x) {
  if (x < 0.5) {
    return 4 * x * x * x;
  }
  final double u = -2 * x + 2;
  return 1 - u * u * u / 2;
}

double _inOutSine(double x) => (1 - math.cos(math.pi * x)) / 2;

/// Stroke drawing: a quick start and a soft landing.
double _draw(double x) => 0.4 * _inOutCubic(x) + 0.6 * _outCubic(x);

/// The dot's pop: lands a touch past full size, then settles.
double _softBack(double x) {
  final double u = x - 1;
  return 1 + 2 * u * u * u + u * u;
}

/// The scan line and the glide: leaves gently, moves decisively, takes its time landing.
const Cubic _settle = Cubic(0.3, 0.0, 0.1, 1.0);
