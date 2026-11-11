import '../content/model.dart';
import '../settings/reading_language.dart';

/// One thing the reader screen shows, in order.
sealed class ReaderItem {
  String get sectionId;
  String? get verseId;
}

/// A section heading with any notes about missing or explanatory text.
class HeadingItem extends ReaderItem {
  HeadingItem(
    this.section,
    this.notes, {
    this.romanTitle,
    this.credit,
    this.canBookmark = true,
  });

  final Section section;
  final List<String> notes;

  /// The Roman Pali name shown under the heading (a pirith).
  final String? romanTitle;

  /// The line crediting the recording (a pirith).
  final String? credit;

  /// False for a pirith, which has no separate bookmark inside it.
  final bool canBookmark;

  @override
  String get sectionId => section.id;

  @override
  String? get verseId => null;
}

/// One verse in one language. [secondary] is true for the second chosen
/// language, which is drawn in the quiet colour.
class VerseTextItem extends ReaderItem {
  VerseTextItem({
    required this.sectionId,
    required this.verseId,
    required this.language,
    required this.text,
    required this.secondary,
  });

  @override
  final String sectionId;
  @override
  final String verseId;
  final ReadingLanguage language;
  final String text;
  final bool secondary;
}

/// One block of a pirith: its phrases together, shown in [languages] (the
/// chosen selection, in order). [index] is the block's zero-based position
/// in the reading.
class PhraseBlockItem extends ReaderItem {
  PhraseBlockItem({
    required this.sectionId,
    required this.verseId,
    required this.index,
    required this.phrases,
    required this.languages,
  });

  @override
  final String sectionId;
  @override
  final String verseId;
  final int index;
  final List<Phrase> phrases;
  final List<ReadingLanguage> languages;
}

const _explanationNote =
    'The English here explains each quality; it is not a line-by-line '
    'translation.';

List<String> _notes(Section section, List<ReadingLanguage> languages) {
  final notes = <String>[];
  for (final l in languages) {
    switch (section.coverOf(l)) {
      case LanguageCover.none:
        notes.add('${l.label} is not yet available for this section.');
      case LanguageCover.part:
        notes.add('${l.label} is not yet available for part of this section.');
      case LanguageCover.all:
        break;
    }
  }
  final explains =
      languages.contains(ReadingLanguage.english) &&
      section.verses.any(
        (v) =>
            v.english != null && v.englishKind == EnglishKind.explanation,
      );
  if (explains) notes.add(_explanationNote);
  return notes;
}

/// What the reader shows for [reading], in order. A verse with no text in a
/// language gives no item for that language.
List<ReaderItem> buildReaderItems(
  Reading reading,
  LanguageSelection selection,
  TwoLanguageLayout layout,
) {
  final languages = selection.languages;
  final items = <ReaderItem>[];

  if (reading.isPhrased) {
    // A pirith: always flowing passages of phrases, whatever the layout setting.
    var block = 0;
    for (final s in reading.sections) {
      items.add(
        HeadingItem(
          s,
          const [],
          romanTitle: reading.titleRoman,
          credit: reading.audio?.label,
          canBookmark: false,
        ),
      );
      for (final v in s.verses) {
        items.add(
          PhraseBlockItem(
            sectionId: s.id,
            verseId: v.id,
            index: block++,
            phrases: v.phrases,
            languages: languages,
          ),
        );
      }
    }
    return items;
  }

  VerseTextItem? item(Section s, Verse v, int index) {
    final text = v.text(languages[index]);
    if (text == null) return null;
    return VerseTextItem(
      sectionId: s.id,
      verseId: v.id,
      language: languages[index],
      text: text,
      secondary: index == 1,
    );
  }

  for (final s in reading.sections) {
    items.add(HeadingItem(s, _notes(s, languages)));
    if (layout == TwoLanguageLayout.verse) {
      for (final v in s.verses) {
        for (var i = 0; i < languages.length; i++) {
          final t = item(s, v, i);
          if (t != null) items.add(t);
        }
      }
    } else {
      for (var i = 0; i < languages.length; i++) {
        for (final v in s.verses) {
          final t = item(s, v, i);
          if (t != null) items.add(t);
        }
      }
    }
  }
  return items;
}
