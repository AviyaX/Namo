import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a third language is refused', () {
    final (s, o) = LanguageSelection.initial.toggle(ReadingLanguage.english);
    expect(o, ToggleOutcome.refusedThird);
    expect(s.languages, [ReadingLanguage.pali, ReadingLanguage.sinhala]);
  });

  test('the last language cannot be switched off', () {
    const one = LanguageSelection([ReadingLanguage.sinhala]);
    final (s, o) = one.toggle(ReadingLanguage.sinhala);
    expect(o, ToggleOutcome.refusedLast);
    expect(s.languages, [ReadingLanguage.sinhala]);
  });

  test('switching off then on puts the language second', () {
    final (a, o1) = LanguageSelection.initial.toggle(ReadingLanguage.pali);
    expect(o1, ToggleOutcome.changed);
    expect(a.languages, [ReadingLanguage.sinhala]);
    final (b, o2) = a.toggle(ReadingLanguage.english);
    expect(o2, ToggleOutcome.changed);
    expect(b.languages, [ReadingLanguage.sinhala, ReadingLanguage.english]);
    expect(b.has(ReadingLanguage.english), isTrue);
    expect(b.has(ReadingLanguage.pali), isFalse);
  });

  test('fromCodes repairs bad saved values', () {
    expect(LanguageSelection.fromCodes(['si', 'en', 'pi']).languages,
        [ReadingLanguage.sinhala, ReadingLanguage.english]);
    expect(LanguageSelection.fromCodes(['xx', 7, null]).languages,
        LanguageSelection.initial.languages);
    expect(LanguageSelection.fromCodes(['en', 'en']).languages,
        [ReadingLanguage.english]);
    expect(LanguageSelection.fromCodes([]).languages,
        LanguageSelection.initial.languages);
  });
}
