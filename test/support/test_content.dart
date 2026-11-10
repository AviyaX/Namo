import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/content/model.dart';

/// Made-up content for tests: one category, one reading, three sections.
Library testLibrary() => const Library(categories: [
      Category(
        id: 'c1',
        title: 'category 1',
        subtitle: 'subtitle 1',
        readings: [
          Reading(id: 'r1', title: 'reading 1', sections: [
            Section(id: 's01', number: 1, heading: 'heading 1'),
            Section(id: 's02', number: 2, heading: 'heading 2'),
            Section(id: 's03', number: 3, heading: 'heading 3'),
          ]),
        ],
      ),
    ]);

class FakeContentRepository implements ContentRepository {
  FakeContentRepository({this.failWith});

  final Object? failWith;

  @override
  Future<Library> load() async {
    if (failWith != null) throw failWith!;
    return testLibrary();
  }
}
