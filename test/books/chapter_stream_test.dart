import 'dart:async';

import 'package:buddhist_gatha/books/book_model.dart';
import 'package:buddhist_gatha/books/book_places.dart';
import 'package:buddhist_gatha/books/pagination/book_paginator.dart';
import 'package:buddhist_gatha/books/pagination/chapter_stream.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// A book of [chapters] chapters; chapter [empty] (if given) has no text.
Book _book(int chapters, {int? empty}) => Book(
  id: 'b',
  title: 'B',
  pages: [
    for (var n = 1; n <= chapters; n++)
      BookPage(
        n: n,
        key: '$n',
        level: 1,
        title: 'Chapter $n',
        url: 'https://example.invalid/$n.html',
        blocks: n == empty ? const [] : const [BookPara('text')],
      ),
  ],
);

/// A fake cut: [perChapter] pages over 200 blocks; page `i` starts at block
/// `i * 200 ~/ perChapter`. Counts how many pages were pulled per chapter.
Iterable<ScreenPage> Function(BookPage) _cutInto(
  int perChapter, [
  Map<int, int>? pulled,
]) {
  return (page) sync* {
    for (var i = 0; i < perChapter; i++) {
      pulled?[page.n] = (pulled[page.n] ?? 0) + 1;
      yield ScreenPage([
        BlockSlice(
          0,
          spot: BookSpot(i * 200 ~/ perChapter, 0),
          top: 0,
          height: 10,
        ),
      ]);
    }
  };
}

ChapterStream _stream(
  Book book,
  int n, {
  BookSpot? spot,
  int perChapter = 10,
  Map<int, int>? pulled,
}) => ChapterStream(
  book: book,
  n: n,
  spot: spot,
  cut: _cutInto(perChapter, pulled),
  yieldFrame: () async {},
);

Future<void> _settle() => pumpEventQueue(times: 400);

void main() {
  test('opens at the page holding the spot', () async {
    final s = _stream(_book(3), 2, spot: const BookSpot(65, 3));
    addTearDown(s.dispose);
    await _settle();
    expect(s.n, 2);
    expect(s.index, 3);
    expect(s.current!.start, const BookSpot(60, 0));
  });

  test('a null spot opens at the first page', () async {
    final s = _stream(_book(3), 2, spot: null);
    addTearDown(s.dispose);
    await _settle();
    expect(s.index, 0);
    expect(s.current!.start, const BookSpot(0, 0));
  });

  test('current is null until the first page is cut', () async {
    final s = _stream(_book(3), 2, spot: null);
    addTearDown(s.dispose);
    expect(s.current, isNull);
    await _settle();
    expect(s.current, isNotNull);
  });

  test(
    "next on the last page crosses to the next chapter's first page",
    () async {
      final s = _stream(_book(3), 1, spot: const BookSpot(199, 0));
      addTearDown(s.dispose);
      await _settle();
      expect(s.index, 9);
      expect(s.peekNext!.start, const BookSpot(0, 0));
      expect(s.next(), isTrue);
      expect(s.n, 2);
      expect(s.index, 0);
      expect(s.current!.start, const BookSpot(0, 0));
    },
  );

  test(
    'previous from the first page lands on the last of the previous',
    () async {
      final s = _stream(_book(3), 2, spot: null);
      addTearDown(s.dispose);
      await _settle();
      expect(s.peekPrevious!.start, const BookSpot(180, 0));
      expect(s.previous(), isTrue);
      expect(s.n, 1);
      expect(s.index, 9);
      expect(s.count, 10);
    },
  );

  test('at the ends next and previous return false', () async {
    final s = _stream(_book(2), 1, spot: null);
    addTearDown(s.dispose);
    await _settle();
    expect(s.peekPrevious, isNull);
    expect(s.previous(), isFalse);
    expect(s.waiting, isFalse);
    s.jumpTo(2, const BookSpot(199, 0));
    await _settle();
    expect(s.peekNext, isNull);
    expect(s.next(), isFalse);
    expect(s.waiting, isFalse);
  });

  test('chapters without text are skipped', () async {
    final s = _stream(_book(3, empty: 2), 1, spot: const BookSpot(199, 0));
    addTearDown(s.dispose);
    await _settle();
    expect(s.next(), isTrue);
    expect(s.n, 3);
  });

  test('count is null until the chapter is cut, then its length', () async {
    final gate = Completer<void>();
    var gated = true;
    final s = ChapterStream(
      book: _book(3),
      n: 2,
      spot: null,
      cut: _cutInto(10),
      yieldFrame: () async {
        if (gated) await gate.future;
      },
    );
    addTearDown(s.dispose);
    await _settle();
    expect(s.count, isNull);
    gated = false;
    gate.complete();
    await _settle();
    expect(s.count, 10);
  });

  test('cuts four pages per frame, current chapter first', () async {
    final pulled = <int, int>{};
    var frames = 0;
    final gates = <Completer<void>>[];
    final s = ChapterStream(
      book: _book(3),
      n: 2,
      spot: null,
      cut: _cutInto(10, pulled),
      yieldFrame: () {
        frames++;
        final c = Completer<void>();
        gates.add(c);
        return c.future;
      },
    );
    addTearDown(s.dispose);
    await _settle();
    expect(pulled, isEmpty);
    gates.last.complete();
    await _settle();
    expect(pulled, {2: 4});
    gates.last.complete();
    await _settle();
    gates.last.complete();
    await _settle();
    expect(pulled, {2: 10});
    gates.last.complete();
    await _settle();
    expect(pulled, {2: 10, 3: 4});
    expect(frames, 5);
  });

  test('a turn into an uncut neighbour waits, then becomes ready', () async {
    final gates = <Completer<void>>[];
    final s = ChapterStream(
      book: _book(3),
      n: 1,
      spot: const BookSpot(199, 0),
      cut: _cutInto(10),
      yieldFrame: () {
        final c = Completer<void>();
        gates.add(c);
        return c.future;
      },
    );
    addTearDown(s.dispose);
    Future<void> frame() async {
      await _settle();
      gates.removeLast().complete();
      await _settle();
    }

    for (var i = 0; i < 3; i++) {
      await frame(); // current chapter, 4 + 4 + 2 pages
    }
    expect(s.count, 10);
    expect(s.next(), isFalse);
    expect(s.waiting, isTrue);
    var notified = 0;
    s.addListener(() => notified++);
    await frame();
    expect(s.waiting, isFalse);
    expect(notified, greaterThan(0));
    expect(s.next(), isTrue);
    expect(s.n, 2);
  });

  test('re-cut keeps the passage', () async {
    final s = _stream(_book(3), 2, spot: const BookSpot(140, 0));
    addTearDown(s.dispose);
    await _settle();
    expect(s.index, 7);
    s.recut(_cutInto(20));
    await _settle();
    expect(s.index, 14);
    expect(s.current!.start, const BookSpot(140, 0));
    expect(s.count, 20);
    expect(s.peekNext!.start, const BookSpot(150, 0));
  });

  test('re-cut holds the old page until the spot is cut', () async {
    final gates = <Completer<void>>[];
    final s = ChapterStream(
      book: _book(3),
      n: 2,
      spot: const BookSpot(140, 0),
      cut: _cutInto(10),
      yieldFrame: () {
        if (gates.isEmpty) return Future<void>.value();
        final c = Completer<void>();
        gates.add(c);
        return c.future;
      },
    );
    addTearDown(s.dispose);
    await _settle();
    final old = s.current;
    expect(old, isNotNull);
    gates.add(Completer<void>());
    s.recut(_cutInto(20));
    await _settle();
    expect(s.current, same(old));
    expect(s.index, 7);
    while (gates.isNotEmpty && s.current == old) {
      gates.removeLast().complete();
      await _settle();
    }
    expect(s.current!.start, const BookSpot(140, 0));
    expect(s.index, 14);
  });

  test('only three chapters stay cut', () async {
    final pulled = <int, int>{};
    final s = _stream(_book(5), 1, spot: null, pulled: pulled);
    addTearDown(s.dispose);
    await _settle();
    for (var chapter = 2; chapter <= 4; chapter++) {
      await _settle();
      for (var i = 0; i < 10; i++) {
        expect(s.next(), isTrue);
      }
      expect(s.n, chapter);
      await _settle();
    }
    expect(pulled.keys.toSet(), {1, 2, 3, 4, 5});
    // Chapter 1 was released: going back three chapters needs it re-cut.
    for (var chapter = 3; chapter >= 2; chapter--) {
      await _settle();
      for (var i = 0; i < 10; i++) {
        expect(s.previous(), isTrue);
      }
      expect(s.n, chapter);
    }
    expect(s.peekPrevious, isNull);
    expect(s.previous(), isFalse);
    expect(s.waiting, isTrue);
    await _settle();
    expect(s.peekPrevious, isNotNull);
    expect(s.waiting, isFalse);
    expect(pulled[1], 20);
  });

  test('jumpTo opens another chapter at a spot', () async {
    final s = _stream(_book(5), 1, spot: null);
    addTearDown(s.dispose);
    await _settle();
    s.jumpTo(4, const BookSpot(100, 0));
    await _settle();
    expect(s.n, 4);
    expect(s.index, 5);
    expect(s.count, 10);
    expect(s.peekNext!.start, const BookSpot(120, 0));
  });

  test('disposing stops cutting without a late notification', () async {
    final gate = Completer<void>();
    final pulled = <int, int>{};
    final s = ChapterStream(
      book: _book(3),
      n: 2,
      spot: null,
      cut: _cutInto(10, pulled),
      yieldFrame: () => gate.future,
    );
    await _settle();
    s.dispose();
    gate.complete();
    await _settle();
    expect(pulled, isEmpty);
  });

  test('a textless chapter between two keeps both neighbours cut', () async {
    final pulled = <int, int>{};
    final s = _stream(
      _book(3, empty: 2),
      1,
      spot: const BookSpot(199, 0),
      pulled: pulled,
    );
    addTearDown(s.dispose);
    await _settle();
    expect(s.next(), isTrue);
    expect(s.n, 3);
    await _settle();
    expect(s.peekPrevious, isNotNull);
    expect(s.previous(), isTrue);
    expect(s.n, 1);
    expect(s.peekNext, isNotNull);
    expect(s.next(), isTrue);
    expect(s.n, 3);
    expect(s.peekPrevious, isNotNull);
    await _settle();
    expect(pulled, {1: 10, 3: 10});
  });

  test('opening on a textless chapter resolves to a reading page', () async {
    final s = _stream(_book(3, empty: 2), 2, spot: null);
    addTearDown(s.dispose);
    await _settle();
    expect(s.n, 3);
    expect(s.current, isNotNull);
    s.jumpTo(2, null);
    await _settle();
    expect(s.n, 3);
    expect(s.current, isNotNull);
  });

  test('a book with no text has no pages and nothing to wait for', () async {
    final s = _stream(_book(1, empty: 1), 1, spot: null);
    addTearDown(s.dispose);
    await _settle();
    expect(s.current, isNull);
    expect(s.next(), isFalse);
    expect(s.previous(), isFalse);
    expect(s.waiting, isFalse);
  });

  test('a successful turn clears waiting', () async {
    final gates = <Completer<void>>[];
    final s = ChapterStream(
      book: _book(3),
      n: 2,
      spot: const BookSpot(0, 0),
      cut: _cutInto(10),
      yieldFrame: () {
        final c = Completer<void>();
        gates.add(c);
        return c.future;
      },
    );
    addTearDown(s.dispose);
    Future<void> frame() async {
      await _settle();
      gates.removeLast().complete();
      await _settle();
    }

    await frame(); // 4 pages of chapter 2
    expect(s.previous(), isFalse); // first page, previous chapter not cut
    expect(s.waiting, isTrue);
    expect(s.next(), isTrue);
    expect(s.waiting, isFalse);
  });

  test('an error in the cut is reported, not thrown', () async {
    final errors = <FlutterErrorDetails>[];
    final old = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = old);
    final s = ChapterStream(
      book: _book(3),
      n: 2,
      spot: null,
      cut: (page) sync* {
        throw StateError('bad cut');
      },
      yieldFrame: () async {},
    );
    addTearDown(s.dispose);
    await _settle();
    expect(errors, hasLength(1));
    expect(errors.single.exception, isA<StateError>());
    expect(s.waiting, isFalse);
  });
}
