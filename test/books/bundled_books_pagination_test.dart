/// Cuts every chapter of every bundled book, at the app's largest text on
/// a small phone, and checks no paragraph text is lost or repeated and no
/// page is taller than its box. It takes about a minute (some 74,000
/// pages), so it is tagged slow; it still runs in the normal suite.
@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:buddhist_gatha/books/book_blocks.dart';
import 'package:buddhist_gatha/books/book_model.dart';
import 'package:buddhist_gatha/books/book_pages_view.dart';
import 'package:buddhist_gatha/books/pagination/book_paginator.dart';
import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/settings/settings.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';

/// The page box on a 320×568 phone (the top bar 56 high, the page arrows'
/// bar 98, [scrollTopPadding] and [NamoSpace.sm] round the page, a 16 px
/// margin each side), as the reader cuts it.
const _box = PageBox(width: 288, height: 398);

/// Each bundled book, parsed from its asset file.
List<Book> _bundledBooks() {
  final files =
      Directory('assets/books')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json.gz'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final f in files)
      Book.parse(jsonDecode(utf8.decode(gzip.decode(f.readAsBytesSync())))),
  ];
}

/// The size of a bundled picture, read from its file as the app reads it.
Size? _imageSize(String asset) {
  final file = File(asset);
  if (!file.existsSync()) return null;
  return pngSize(ByteData.sublistView(file.readAsBytesSync()));
}

/// Fails unless the paragraph [block]'s slices, in page order, give back
/// its text exactly: one whole block, or lines that start where the last
/// ended (or one past a hard line break there) and run to its end.
void _expectWhole(String where, String text, List<PageSlice> slices) {
  expect(slices, isNotEmpty, reason: '$where: lost');
  if (slices.any((s) => s is BlockSlice)) {
    expect(slices, hasLength(1), reason: '$where: repeated');
    return;
  }
  var at = 0;
  for (final s in slices) {
    expect(s, isA<LinesSlice>(), reason: where);
    final lines = s as LinesSlice;
    expect(lines.item, 0, reason: where);
    final follows =
        lines.charStart == at ||
        (at > 0 && lines.charStart == at + 1 && text[at] == '\n');
    expect(
      follows,
      isTrue,
      reason: '$where: lines from ${lines.charStart}, last ended at $at',
    );
    expect(lines.charEnd, greaterThan(lines.charStart), reason: where);
    at = lines.charEnd;
  }
  expect(at, text.length, reason: '$where: text lost at the end');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);

  test(
    'every chapter of every bundled book cuts whole at the largest text '
    'on a small phone',
    timeout: const Timeout(Duration(minutes: 5)),
    () {
      final books = _bundledBooks();
      expect(books, hasLength(23));
      final styles = BookTextStyles.from(
        palette: NamoPalette.light,
        settings: const AppSettings(fontScale: 1.6),
      );
      var chapters = 0, pages = 0;
      for (final book in books) {
        for (final chapter in book.pages) {
          if (!chapter.hasText) continue;
          chapters++;
          final cut = paginate(
            chapter,
            styles,
            _box,
            imageSize: _imageSize,
          ).toList();
          pages += cut.length;
          final byBlock = <int, List<PageSlice>>{};
          for (var p = 0; p < cut.length; p++) {
            final where = '${book.id} n ${chapter.n} page ${p + 1}';
            var bottom = 0.0;
            for (final s in cut[p].slices) {
              byBlock.putIfAbsent(s.block, () => []).add(s);
              if (s.top + s.height > bottom) bottom = s.top + s.height;
            }
            expect(
              bottom,
              lessThanOrEqualTo(_box.height + 0.01),
              reason: where,
            );
          }
          for (var b = 0; b < chapter.blocks.length; b++) {
            final block = chapter.blocks[b];
            final where = '${book.id} n ${chapter.n} block $b';
            if (block is BookPara) {
              _expectWhole(where, block.text, byBlock[b] ?? const []);
            } else {
              expect(byBlock[b], isNotNull, reason: '$where: lost');
            }
          }
        }
      }
      // Every chapter with text was cut (2816 into some 74,000 pages today).
      expect(chapters, greaterThan(2000));
      expect(pages, greaterThan(chapters));
    },
  );
}
