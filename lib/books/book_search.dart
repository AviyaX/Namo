import '../library/search.dart';
import 'book_model.dart';

/// The books whose title or subtitle holds [query], in shelf order. Folded
/// as the Library's search folds; plain "contains", never a pattern. A query
/// shorter than [searchMinLength] finds nothing.
List<BookSummary> searchBooks(List<BookSummary> books, String query) {
  final q = foldForSearch(query);
  if (q.runes.length < searchMinLength) return const [];
  return [
    for (final b in books)
      if (foldForSearch(b.title).contains(q) ||
          (b.subtitle != null && foldForSearch(b.subtitle!).contains(q)))
        b,
  ];
}
