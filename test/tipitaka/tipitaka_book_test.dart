import 'package:buddhist_gatha/tipitaka/tipitaka_book.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_tree.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tipitaka_support.dart';

void main() {
  final tree =
      TipitakaTree.parse(tinyTree(), parentsWithText: tinyParentsWithText);
  final bookA = TipitakaBook.parse('vp-a', tinyBookA());
  final bookB = TipitakaBook.parse('ap-b', tinyBookB());

  group('TipitakaBook', () {
    test('flattens pages in order', () {
      expect(bookA.file, 'vp-a');
      expect(bookA.pali.length, 14);
      expect(bookA.sinhala.length, 14);
      expect(bookA.pali.first.text, 'Title A');
      expect(bookA.pali.first.type, EntryType.centered);
      expect(bookA.pali.first.level, 2);
      expect(bookA.pali.first.page, 0);
      expect(bookA.pali[5].text, 'Part two');
      expect(bookA.pali[5].page, 1);
      expect(bookA.pali[4].level, isNull);
      expect(bookA.pali.last.text, 'two ten text');
      expect(bookA.pali.last.type, EntryType.unindented);
      expect(bookA.pali.last.page, 2);
      expect(bookA.pali[8].type, EntryType.gatha);
      expect(bookA.pali[8].text, 'verse line\nverse line');
      expect(bookA.flatIndex(0, 0), 0);
      expect(bookA.flatIndex(1, 2), 7);
      expect(bookA.flatIndex(2, 3), 13);
      expect(bookA.flatIndex(2, 4), -1);
      expect(bookA.flatIndex(9, 0), -1);
    });

    test('unknown type becomes paragraph', () {
      expect(bookA.pali[9].type, EntryType.paragraph);
      expect(bookA.pali[9].text, 'odd type');
    });

    test('sinhala is null where page lists differ in length', () {
      expect(bookA.sinhala.sublist(10), [null, null, null, null]);
      expect(bookB.sinhala.every((e) => e == null), isTrue);
      expect(bookB.sinhala.length, bookB.pali.length);
    });

    test('sinhala is null where the text is blank', () {
      expect(bookA.sinhala[6], isNull);
      expect(bookA.sinhala[5]!.text, 's Part two');
      expect(bookA.sinhala[0]!.text, 's Title A');
      expect(bookA.sinhala[0]!.page, 0);
    });

    test('footnotes are per page and language', () {
      expect(bookA.footnotes(0, pali: true), ['pali note one']);
      expect(bookA.footnotes(0, pali: false), ['sinh note one', 'sinh note two']);
      expect(bookA.footnotes(1, pali: true), isEmpty);
      expect(bookA.footnotes(7, pali: true), isEmpty);
      expect(bookA.footnotes(-1, pali: false), isEmpty);
    });

    test('parse throws FormatException for a non-book', () {
      expect(() => TipitakaBook.parse('x', null), throwsFormatException);
      expect(() => TipitakaBook.parse('x', [1]), throwsFormatException);
      expect(() => TipitakaBook.parse('x', {'pages': 'no'}), throwsFormatException);
      expect(
          () => TipitakaBook.parse('x', {
                'pages': [
                  {'pali': {'entries': [7]}},
                ],
              }),
          throwsFormatException);
      expect(
          () => TipitakaBook.parse('x', {
                'pages': [{'sinh': {'entries': []}}],
              }),
          throwsFormatException);
    });
  });

  group('readingOf', () {
    List<String> texts(TipitakaReading r) => r.pali.map((e) => e.text).toList();

    test('first reading includes title entries before the first node', () {
      final r = readingOf(tree, bookA, 'vp-1-1')!;
      expect(r.key, 'vp-1-1');
      expect(r.book, same(bookA));
      expect(texts(r).first, 'Title A');
      expect(r.hasSinhala, isTrue);
    });

    test('a reading includes the heading-only parents just above it', () {
      final r = readingOf(tree, bookA, 'vp-1-1')!;
      expect(texts(r),
          ['Title A', 'Root vp', 'Part one', 'Leaf one one', 'Leaf one text {1}']);
      expect(r.sinhala.length, r.pali.length);
      final ap = readingOf(tree, bookB, 'ap-1')!;
      expect(texts(ap), ['Root ap', 'Ap one', 'ap one text']);
    });

    test('a parent with text ends at its first child', () {
      final r = readingOf(tree, bookA, 'vp-2')!;
      expect(texts(r), ['Part two', 'Part two intro']);
      expect(r.sinhala.map((e) => e?.text), ['s Part two', null]);
    });

    test('last reading runs to the end of the file', () {
      final r = readingOf(tree, bookA, 'vp-2-10')!;
      expect(texts(r), ['Leaf two ten', 'two ten text']);
      expect(r.hasSinhala, isFalse);
      expect(texts(readingOf(tree, bookA, 'vp-2-2')!),
          ['Leaf two two', 'two two text']);
    });

    test('every entry of a file is in exactly one reading', () {
      for (final book in [bookA, bookB]) {
        final shown = <String>[];
        for (final key in tree.readings) {
          final r = readingOf(tree, book, key);
          if (r != null) shown.addAll(texts(r));
        }
        expect(shown, book.pali.map((e) => e.text).toList(), reason: book.file);
      }
    });

    test('null for a non-reading parent and for an unknown key', () {
      expect(readingOf(tree, bookA, 'vp-1'), isNull);
      expect(readingOf(tree, bookA, 'vp'), isNull);
      expect(readingOf(tree, bookA, 'nope'), isNull);
      expect(readingOf(tree, bookA, 'atta-vp-1'), isNull);
      expect(readingOf(tree, bookB, 'vp-1-1'), isNull); // other file
    });
  });
}
