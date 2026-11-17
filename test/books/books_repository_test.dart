import 'dart:typed_data';

import 'package:buddhist_gatha/books/book_model.dart';
import 'package:buddhist_gatha/books/books_repository.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tipitaka/tipitaka_support.dart';
import 'books_support.dart';

/// Wraps [inner], recording every requested path in order.
class _Recording {
  _Recording(this.inner);
  final AssetBytes inner;
  final paths = <String>[];
  int count(String path) => paths.where((p) => p == path).length;
  Future<Uint8List> call(String path) {
    paths.add(path);
    return inner(path);
  }
}

void main() {
  final flat = tinyBookFile(tinyBookFlatId);
  final nested = tinyBookFile(tinyBookNestedId);

  test('index is read once and books only when asked', () async {
    final assets = _Recording(fakeAssets(tinyBooks()));
    final repo = BooksRepository(load: assets.call);
    await Future<void>.delayed(Duration.zero);
    expect(assets.paths, isEmpty);

    final results = await Future.wait([repo.index(), repo.index()]);
    expect(identical(results[0], results[1]), isTrue);
    expect(identical(await repo.index(), results[0]), isTrue);
    expect(assets.paths, [booksIndexAsset]);

    final book = await repo.book(nested);
    expect(book.id, tinyBookNestedId);
    expect(identical(await repo.book(nested), book), isTrue);
    expect(assets.paths, [booksIndexAsset, nested]);
  });

  test('a book is parsed from gzip and plain bytes alike', () async {
    for (final gzip in [true, false]) {
      for (final inBackground in [true, false]) {
        final repo = BooksRepository(
          load: fakeAssets(tinyBooks(), gzip: gzip),
          inBackground: inBackground,
        );
        final why = 'gzip $gzip, inBackground $inBackground';
        final book = await repo.book(nested);
        expect(book.pages.length, 7, reason: why);
        expect(book.page(7)!.blocks.last, isA<BookImage>(), reason: why);
        expect((await repo.index()).books.length, 2, reason: why);
      }
    }
  });

  test('a failed load is forgotten so the next call retries', () async {
    var fail = true;
    final inner = fakeAssets(tinyBooks());
    final assets = _Recording((path) {
      if (fail) throw StateError('broken $path');
      return inner(path);
    });
    final repo = BooksRepository(load: assets.call);
    await expectLater(repo.index(), throwsStateError);
    await expectLater(repo.book(flat), throwsStateError);
    fail = false;
    expect((await repo.index()).books.length, 2);
    expect((await repo.book(flat)).id, tinyBookFlatId);
    expect(assets.count(booksIndexAsset), 2);
    expect(assets.count(flat), 2);

    // A file that is not a book fails as a FormatException.
    final notBook = BooksRepository(
      load: fakeAssets({
        nested: <Object>[1, 2],
      }),
    );
    await expectLater(notBook.book(nested), throwsFormatException);
  });

  test('only the two most recent books are kept', () async {
    final third = tinyBookFile('third');
    final assets = _Recording(
      fakeAssets({...tinyBooks(), third: tinyBookFlat()}),
    );
    final repo = BooksRepository(load: assets.call);
    await repo.book(flat);
    await repo.book(nested);
    await repo.book(flat); // flat becomes the most recent
    await repo.book(third); // drops nested, the least recent
    await repo.book(flat);
    expect(assets.count(flat), 1);
    await repo.book(nested);
    expect(assets.count(nested), 2);
    // nested coming back dropped third.
    await repo.book(third);
    expect(assets.count(third), 2);
  });

  test('bookProvider fails for an unknown id', () async {
    final c = ProviderContainer(
      overrides: [
        booksRepositoryProvider.overrideWithValue(
          BooksRepository(load: fakeAssets(tinyBooks()), inBackground: false),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect((await c.read(booksIndexProvider.future)).books.length, 2);
    final book = await c.read(bookProvider(tinyBookFlatId).future);
    expect(book.title, 'Flat book');
    await expectLater(
      c.read(bookProvider('nope').future),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', 'no book nope'),
      ),
    );
  });
}
