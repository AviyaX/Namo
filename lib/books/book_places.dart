import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/key_value_store.dart';
import 'book_model.dart';

/// JSON `{"<book id>": {"n": 3, "key": "1-2", "offset": 120.5,
/// "spot": [2, 140]}}`. "key" and "spot" were added later; an entry without
/// them is still read.
const bookPlacesKey = 'namo.books.places.v1';

/// A position in a page's text: the [block] (an index into the page's
/// blocks) and the character [char] within it. Block -1 is the chapter title.
@immutable
class BookSpot implements Comparable<BookSpot> {
  const BookSpot(this.block, this.char);

  /// The start of the chapter title.
  static const title = BookSpot(-1, 0);

  /// The start of the first block.
  static const start = BookSpot(0, 0);

  final int block;
  final int char;

  @override
  int compareTo(BookSpot other) => block != other.block
      ? block.compareTo(other.block)
      : char.compareTo(other.char);

  @override
  bool operator ==(Object other) =>
      other is BookSpot && other.block == block && other.char == char;

  @override
  int get hashCode => Object.hash(block, char);

  @override
  String toString() => 'BookSpot($block, $char)';

  /// Null when [json] is not `[block, char]` of whole numbers, with block at
  /// least -1 and char at least 0.
  static BookSpot? _fromJson(Object? json) {
    if (json is! List || json.length != 2) return null;
    final block = json[0], char = json[1];
    if (block is! int || char is! int || block < -1 || char < 0) return null;
    return BookSpot(block, char);
  }
}

/// Where the person stopped in one book.
@immutable
class BookPlace {
  const BookPlace({required this.n, this.key, required this.offset, this.spot});

  /// The page (its `n`, 1-based).
  final int n;

  /// The page's key (its name on the website, e.g. "1-2"), when known. A
  /// re-fetched book can number its pages differently; the key still finds
  /// the same page.
  final String? key;

  /// The reader's scroll offset on that page, in logical pixels.
  final double offset;

  /// The text position on that page, when known. It does not depend on the
  /// screen or text size, so it finds the same place in either reading mode.
  final BookSpot? spot;

  /// The page this place is in [book]: the page with [key] when there is
  /// one, else [n].
  int pageIn(Book book) {
    final key = this.key;
    if (key != null) {
      for (final page in book.pages) {
        if (page.key == key) return page.n;
      }
    }
    return n;
  }

  Map<String, dynamic> toJson() => {
    'n': n,
    if (key != null) 'key': key,
    'offset': offset,
    if (spot != null) 'spot': [spot!.block, spot!.char],
  };

  /// Null when [json] cannot be read. A key that is not text, or a spot that
  /// is damaged, is left out.
  static BookPlace? _fromJson(Object? json) {
    if (json is! Map) return null;
    final n = json['n'], key = json['key'], offset = json['offset'];
    if (n is! int || n < 1) return null;
    if (offset is! num || !offset.isFinite) return null;
    return BookPlace(
      n: n,
      key: key is String && key.isNotEmpty ? key : null,
      offset: offset < 0 ? 0 : offset.toDouble(),
      spot: BookSpot._fromJson(json['spot']),
    );
  }
}

class BookPlaces {
  const BookPlaces([this.byBook = const {}]);

  final Map<String, BookPlace> byBook;

  BookPlace? of(String id) => byBook[id];

  Map<String, dynamic> toJson() => {
    for (final e in byBook.entries) e.key: e.value.toJson(),
  };

  /// Damaged data gives the empty state; within it, an entry that cannot be
  /// read is dropped alone.
  factory BookPlaces.fromJson(Object? json) {
    if (json is! Map) return const BookPlaces();
    final byBook = <String, BookPlace>{};
    for (final e in json.entries) {
      final place = BookPlace._fromJson(e.value);
      if (e.key is String && place != null) byBook[e.key as String] = place;
    }
    return BookPlaces(Map.unmodifiable(byBook));
  }
}

class BookPlacesController extends Notifier<BookPlaces> {
  @override
  BookPlaces build() {
    final text = ref.read(keyValueStoreProvider).read(bookPlacesKey);
    if (text == null) return const BookPlaces();
    try {
      return BookPlaces.fromJson(jsonDecode(text));
    } on FormatException {
      return const BookPlaces();
    }
  }

  void _set(BookPlaces next) {
    state = next;
    ref
        .read(keyValueStoreProvider)
        .save(bookPlacesKey, jsonEncode(next.toJson()));
  }

  /// Remembers page [n] (whose key is [key]) at [offset], and at text
  /// position [spot] when given, for book [id].
  /// Does nothing once the provider is gone (a reader saving its place as
  /// the whole app closes).
  void remember(
    String id, {
    required int n,
    String? key,
    required double offset,
    BookSpot? spot,
  }) {
    if (!ref.mounted) return;
    final place = BookPlace(
      n: n < 1 ? 1 : n,
      key: key,
      offset: offset.isFinite && offset > 0 ? offset : 0,
      spot: spot,
    );
    _set(BookPlaces(Map.unmodifiable({...state.byBook, id: place})));
  }
}

final bookPlacesProvider = NotifierProvider<BookPlacesController, BookPlaces>(
  BookPlacesController.new,
);
