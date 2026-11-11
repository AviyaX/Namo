enum ReadingLanguage {
  sinhala('si', 'Sinhala'),
  english('en', 'English'),
  pali('pi', 'Pali');

  const ReadingLanguage(this.code, this.label);

  final String code;
  final String label;

  static ReadingLanguage? fromCode(String code) {
    for (final l in values) {
      if (l.code == code) return l;
    }
    return null;
  }
}

enum ToggleOutcome { changed, refusedThird, refusedLast }

/// Which languages are shown: one or two, in the order they were chosen.
class LanguageSelection {
  const LanguageSelection(this.languages);

  final List<ReadingLanguage> languages;

  static const initial =
      LanguageSelection([ReadingLanguage.pali, ReadingLanguage.sinhala]);

  bool has(ReadingLanguage l) => languages.contains(l);

  (LanguageSelection, ToggleOutcome) toggle(ReadingLanguage l) {
    if (has(l)) {
      if (languages.length == 1) return (this, ToggleOutcome.refusedLast);
      return (
        LanguageSelection([...languages.where((x) => x != l)]),
        ToggleOutcome.changed,
      );
    }
    if (languages.length >= 2) return (this, ToggleOutcome.refusedThird);
    return (LanguageSelection([...languages, l]), ToggleOutcome.changed);
  }

  /// Drops unknown and repeated codes, keeps the first two, and falls back to
  /// [initial] if none remain.
  static LanguageSelection fromCodes(List<Object?> codes) {
    final out = <ReadingLanguage>[];
    for (final c in codes) {
      final l = c is String ? ReadingLanguage.fromCode(c) : null;
      if (l != null && !out.contains(l)) out.add(l);
      if (out.length == 2) break;
    }
    return out.isEmpty ? initial : LanguageSelection(out);
  }
}

enum TwoLanguageLayout {
  section('Section by section'),
  verse('Verse by verse');

  const TwoLanguageLayout(this.label);

  final String label;
}
