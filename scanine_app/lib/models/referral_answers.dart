/// The owner's answers to the questions asked before the referral summary.
/// They are the questions vet dermatology intake forms start with: how
/// itchy, since when, which way it is going, flea prevention, whether others
/// at home are affected, and what was already tried. Every one is optional.
class ReferralAnswers {
  const ReferralAnswers({
    this.itch,
    this.duration,
    this.trend,
    this.fleaPrevention,
    this.othersAffected,
    this.treatments = '',
  });

  final String? itch;
  final String? duration;
  final String? trend;
  final String? fleaPrevention;
  final String? othersAffected;
  final String treatments;

  static const itchOptions = ['Not itchy', 'A little', 'A lot', 'Nonstop'];
  static const durationOptions = [
    'Under a week',
    '1–4 weeks',
    '1–3 months',
    'Longer',
  ];
  static const trendOptions = ['Worse', 'Same', 'Better'];
  static const fleaOptions = ['Monthly', 'Sometimes', 'None', 'Not sure'];
  static const othersOptions = ['No', 'Yes', 'Not sure'];

  bool get isEmpty =>
      itch == null &&
      duration == null &&
      trend == null &&
      fleaPrevention == null &&
      othersAffected == null &&
      treatments.trim().isEmpty;

  /// The answers as plain sentences for the vet. Each sentence is a list of
  /// (text, emphasised) parts so the summary can bold the answers.
  List<List<(String, bool)>> sentences() {
    final out = <List<(String, bool)>>[];

    const since = {
      'Under a week': 'less than a week ago',
      '1–4 weeks': '1 to 4 weeks ago',
      '1–3 months': '1 to 3 months ago',
      'Longer': 'more than 3 months ago',
    };
    const trendText = {
      'Worse': 'getting worse',
      'Same': 'staying the same',
      'Better': 'getting better',
    };
    if (duration != null) {
      out.add([
        ('First noticed ', false),
        (since[duration]!, true),
        if (trend != null) ...[(' and ', false), (trendText[trend]!, true)],
        ('.', false),
      ]);
    } else if (trend != null) {
      out.add([('It is ', false), (trendText[trend]!, true), ('.', false)]);
    }

    const itchText = {
      'Not itchy': 'not itchy',
      'A little': 'a little itchy',
      'A lot': 'itching a lot',
      'Nonstop': 'itching nonstop',
    };
    if (itch != null) {
      out.add([('The dog is ', false), (itchText[itch]!, true), ('.', false)]);
    }

    const fleaText = {
      'Monthly': 'given monthly',
      'Sometimes': 'given sometimes',
      'None': 'not given',
      'Not sure': 'not known',
    };
    if (fleaPrevention != null) {
      out.add([
        ('Flea and tick prevention is ', false),
        (fleaText[fleaPrevention]!, true),
        ('.', false),
      ]);
    }

    switch (othersAffected) {
      case 'Yes':
        out.add([
          ('Another pet or person ', false),
          ('has similar skin problems', true),
          ('.', false),
        ]);
      case 'No':
        out.add([('No other pet or person', true), (' is affected.', false)]);
      case 'Not sure':
        out.add([
          ('It is ', false),
          ('not known', true),
          (' whether other pets or people are affected.', false),
        ]);
    }

    final tried = treatments.trim();
    if (tried.isNotEmpty) {
      out.add([
        ('Already tried: ', false),
        (tried.endsWith('.') ? tried : '$tried.', false),
      ]);
    }
    return out;
  }

  ReferralAnswers copyWith({
    String? Function()? itch,
    String? Function()? duration,
    String? Function()? trend,
    String? Function()? fleaPrevention,
    String? Function()? othersAffected,
    String? treatments,
  }) =>
      ReferralAnswers(
        itch: itch != null ? itch() : this.itch,
        duration: duration != null ? duration() : this.duration,
        trend: trend != null ? trend() : this.trend,
        fleaPrevention:
            fleaPrevention != null ? fleaPrevention() : this.fleaPrevention,
        othersAffected:
            othersAffected != null ? othersAffected() : this.othersAffected,
        treatments: treatments ?? this.treatments,
      );
}
