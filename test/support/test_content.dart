import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/content/model.dart';

/// Made-up content for tests: one category, one reading, three sections.
/// s01: two verses, all three languages. s02: one verse, no English.
/// s03: two verses, only the first has English (an explanation).
Library testLibrary() => const Library(
  categories: [
    Category(
      id: 'c1',
      title: 'category 1',
      subtitle: 'subtitle 1',
      readings: [
        Reading(
          id: 'r1',
          title: 'reading 1',
          sections: [
            Section(
              id: 's01',
              number: 1,
              heading: 'heading 1',
              verses: [
                Verse(
                  id: 's01-v1',
                  paliSi: 'pali 1',
                  sinhala: 'sinhala 1',
                  english: 'english 1',
                  englishKind: EnglishKind.translation,
                ),
                Verse(
                  id: 's01-v2',
                  paliSi: 'pali 2',
                  sinhala: 'sinhala 2',
                  english: 'english 2',
                  englishKind: EnglishKind.translation,
                ),
              ],
            ),
            Section(
              id: 's02',
              number: 2,
              heading: 'heading 2',
              verses: [
                Verse(id: 's02-v1', paliSi: 'pali 3', sinhala: 'sinhala 3'),
              ],
            ),
            Section(
              id: 's03',
              number: 3,
              heading: 'heading 3',
              verses: [
                Verse(
                  id: 's03-v1',
                  paliSi: 'pali 4',
                  sinhala: 'sinhala 4',
                  english: 'english 4',
                  englishKind: EnglishKind.explanation,
                ),
                Verse(id: 's03-v2', paliSi: 'pali 5', sinhala: 'sinhala 5'),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

class FakeContentRepository implements ContentRepository {
  FakeContentRepository({this.failWith, this.library});

  final Object? failWith;

  /// Content to give instead of [testLibrary].
  final Library? library;

  @override
  Future<Library> load() async {
    if (failWith != null) throw failWith!;
    return library ?? testLibrary();
  }
}
