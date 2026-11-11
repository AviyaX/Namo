import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/model.dart';
import '../settings/reading_language.dart';

/// The time source for Home; tests replace it.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

String greetingFor(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'Good morning';
  if (h >= 12 && h < 17) return 'Good afternoon';
  return 'Good evening';
}

class GathaPick {
  const GathaPick(this.reading, this.section, this.verse);

  final Reading reading;
  final Section section;
  final Verse verse;
}

const _maxLines = 4;
const _maxChars = 320;

int _length(String? s) => s?.runes.length ?? 0;

bool _eligible(Verse v) {
  if (v.isPhrased) return false;
  if (v.check != CheckStatus.checkedAgainstSource) return false;
  final pali = v.paliSi;
  if (pali == null || pali.split('\n').length > _maxLines) return false;
  for (final t in [v.paliSi, v.paliRoman, v.sinhala, v.english]) {
    if (_length(t) > _maxChars) return false;
  }
  return true;
}

/// Checked, short verses in content order.
List<GathaPick> eligibleGathas(Library library) => [
  for (final c in library.categories)
    for (final r in c.readings)
      for (final s in r.sections)
        for (final v in s.verses)
          if (_eligible(v)) GathaPick(r, s, v),
];

/// Whole days from 1 January 1970 to the calendar date of [now].
int dayNumber(DateTime now) => DateTime.utc(
  now.year,
  now.month,
  now.day,
).difference(DateTime.utc(1970)).inDays;

GathaPick? gathaForDay(Library library, DateTime now) {
  final eligible = eligibleGathas(library);
  if (eligible.isEmpty) return null;
  return eligible[dayNumber(now) % eligible.length];
}

/// The chosen languages the verse has text for, in chosen order; the Pali
/// text when none of them has any.
List<(ReadingLanguage, String)> gathaTexts(
  Verse verse,
  LanguageSelection selection,
) {
  final out = <(ReadingLanguage, String)>[];
  for (final l in selection.languages) {
    final t = verse.text(l);
    if (t != null) out.add((l, t));
  }
  if (out.isEmpty) {
    out.add((ReadingLanguage.pali, verse.text(ReadingLanguage.pali) ?? ''));
  }
  return out;
}
