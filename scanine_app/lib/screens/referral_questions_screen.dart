import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/referral_answers.dart';
import '../models/screening_result.dart';
import '../theme/routes.dart';
import '../widgets/referral_footer.dart';
import 'referral_summary_screen.dart';

/// "Before you go, tell your vet": six quick questions asked between the
/// result and the referral summary. Every answer is optional; the ones
/// given are written into the summary.
class ReferralQuestionsScreen extends StatefulWidget {
  const ReferralQuestionsScreen({super.key, required this.result});

  final ScreeningResult result;

  @override
  State<ReferralQuestionsScreen> createState() =>
      _ReferralQuestionsScreenState();
}

class _ReferralQuestionsScreenState extends State<ReferralQuestionsScreen> {
  var _answers = const ReferralAnswers();

  void _set(ReferralAnswers a) => setState(() => _answers = a);

  void _next({bool skipped = false}) {
    FocusScope.of(context).unfocus();
    AppRoutes.push(
      context,
      (_) => ReferralSummaryScreen(
        result: widget.result,
        answers: skipped ? const ReferralAnswers() : _answers,
      ),
    );
  }

  /// Tapping the chosen answer again clears it.
  String? Function() _toggle(String? current, String tapped) =>
      () => current == tapped ? null : tapped;

  @override
  Widget build(BuildContext context) {
    final a = _answers;
    final top = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: RefTheme.bg,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: RefTheme.bg,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              Positioned.fill(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(24, top + 12, 24, 200),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.chevron_left_rounded,
                            size: 28, color: RefTheme.navy),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                        tooltip: 'Back',
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontFamily: 'InstrumentSans',
                          fontSize: 32,
                          height: 38 / 32,
                          letterSpacing: -0.8,
                        ),
                        children: [
                          TextSpan(
                            text: 'Before you go,\n',
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: RefTheme.ink,
                            ),
                          ),
                          TextSpan(
                            text: 'tell your vet',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: RefTheme.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Added to your summary.',
                      style: TextStyle(
                        fontFamily: 'InstrumentSans',
                        fontSize: 14,
                        color: RefTheme.muted,
                      ),
                    ),
                    _Question(
                      title: 'How itchy is your dog?',
                      hint: 'Scratching, licking, chewing or rubbing.',
                      columns: 2,
                      options: ReferralAnswers.itchOptions,
                      value: a.itch,
                      onTap: (o) => _set(a.copyWith(itch: _toggle(a.itch, o))),
                    ),
                    _Question(
                      title: 'When did you first notice it?',
                      columns: 2,
                      options: ReferralAnswers.durationOptions,
                      value: a.duration,
                      onTap: (o) =>
                          _set(a.copyWith(duration: _toggle(a.duration, o))),
                    ),
                    _Question(
                      title: 'Is it changing?',
                      columns: 3,
                      options: ReferralAnswers.trendOptions,
                      value: a.trend,
                      onTap: (o) =>
                          _set(a.copyWith(trend: _toggle(a.trend, o))),
                    ),
                    _Question(
                      title: 'Flea and tick prevention',
                      columns: 2,
                      options: ReferralAnswers.fleaOptions,
                      value: a.fleaPrevention,
                      onTap: (o) => _set(a.copyWith(
                          fleaPrevention: _toggle(a.fleaPrevention, o))),
                    ),
                    _Question(
                      title: 'Does another pet or person have it?',
                      columns: 3,
                      options: ReferralAnswers.othersOptions,
                      value: a.othersAffected,
                      onTap: (o) => _set(a.copyWith(
                          othersAffected: _toggle(a.othersAffected, o))),
                    ),
                    const _Title('Anything already tried?', hint: 'Optional.'),
                    TextField(
                      onChanged: (v) => _set(a.copyWith(treatments: v)),
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 200,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        fontFamily: 'InstrumentSans',
                        fontSize: 14,
                        color: RefTheme.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Medicated shampoo, twice a week',
                        hintStyle: const TextStyle(
                          fontFamily: 'InstrumentSans',
                          fontSize: 14,
                          color: Color(0xFF8A94B0),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        counterStyle: const TextStyle(
                            fontSize: 11, color: RefTheme.muted),
                        contentPadding: const EdgeInsets.all(14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: RefTheme.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: RefTheme.navy, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: RefFooter(
                  primaryText: 'Make summary',
                  onPrimary: _next,
                  secondaryText: 'Skip',
                  onSecondary: () => _next(skipped: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, {this.hint});

  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'InstrumentSans',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: RefTheme.ink,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: const TextStyle(
                fontFamily: 'InstrumentSans',
                fontSize: 13,
                color: RefTheme.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({
    required this.title,
    this.hint,
    required this.columns,
    required this.options,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String? hint;
  final int columns;
  final List<String> options;
  final String? value;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += columns) {
      if (i > 0) rows.add(const SizedBox(height: 8));
      rows.add(Row(
        children: [
          for (var j = i; j < i + columns; j++) ...[
            if (j > i) const SizedBox(width: 8),
            Expanded(
              child: j < options.length
                  ? _Answer(
                      label: options[j],
                      selected: options[j] == value,
                      onTap: () => onTap(options[j]),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_Title(title, hint: hint), ...rows],
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? RefTheme.navy : RefTheme.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'InstrumentSans',
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? RefTheme.navy : RefTheme.ink,
            ),
          ),
        ),
      ),
    );
  }
}
