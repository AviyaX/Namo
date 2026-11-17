import 'package:buddhist_gatha/books/book_model.dart';
import 'package:buddhist_gatha/books/book_search.dart';
import 'package:flutter_test/flutter_test.dart';

BookSummary _book(String id, String title, [String? subtitle]) => BookSummary(
  id: id,
  title: title,
  subtitle: subtitle,
  chapters: 1,
  pages: 1,
  file: 'assets/books/$id.json.gz',
  cover: 'assets/books/covers/$id.jpg',
);

final _books = [
  _book('flat', 'Flat book'),
  _book('nested', 'Nested book', 'A made-up subtitle'),
  // ශ්‍රී with a zero-width joiner, as the bundle spells it.
  _book('joined', 'ශ්‍රී පොත'),
];

List<String> _ids(String q) => [for (final b in searchBooks(_books, q)) b.id];

void main() {
  test('matches a title', () {
    expect(_ids('Flat'), ['flat']);
    expect(_ids('book'), ['flat', 'nested']);
  });

  test('matches a subtitle', () {
    expect(_ids('made-up'), ['nested']);
  });

  test('folds case and ignores U+200D', () {
    expect(_ids('NESTED  BOOK'), ['nested']);
    expect(_ids('ශ්රී'), ['joined']);
    expect(_ids('fl‍at'), ['flat']);
  });

  test('one character finds nothing', () {
    expect(searchBooks(_books, 'b'), isEmpty);
    expect(searchBooks(_books, ' '), isEmpty);
  });
}
