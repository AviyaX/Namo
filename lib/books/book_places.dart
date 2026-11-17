import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/key_value_store.dart';
import 'book_model.dart';

/// JSON `{"<book id>": {"n": 3, "key": "1-2", "offset": 120.5}}`. "key" was
/// added later; an entry without it is still read.
const bookPlacesKey = 'namo.books.places.v1';

/// Where the person stopped in one book.
@immutable
class BookPlace {
  const BookPlace({required this.n, this.key, required this.offset});

  /// The page (its `n`, 1-based).
  final int n;

  /// The page's key (its name on the website, e.g. "1-2"), when known. A
  /// re-fetched book can number its pages differently; the key still finds
  /// the same page.
  final String? key;

  /// The reader's scroll offset on that page, in logical pixels.
  final double offset;

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
  };

  /// Null when [json] cannot be read. A key that is not text is left out.
  static BookPlace? _fromJson(Object? json) {
    if (json is! Map) return null;
    final n = json['n'], key = json['key'], offset = json['offset'];
    if (n is! int || n < 1) return null;
    if (offset is! num || !offset.isFinite) return null;
    return BookPlace(
      n: n,
      key: key is String && key.isNotEmpty ? key : null,
      offset: offset < 0 ? 0 : offset.toDouble(),
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

  /// Remembers page [n] (whose key is [key]) at [offset] for book [id].
  /// Does nothing once the provider is gone (a reader saving its place as
  /// the whole app closes).
  void remember(
    String id, {
    required int n,
    String? key,
    required double offset,
  }) {
    if (!ref.mounted) return;
    final place = BookPlace(
      n: n < 1 ? 1 : n,
      key: key,
      offset: offset.isFinite && offset > 0 ? offset : 0,
    );
    _set(BookPlaces(Map.unmodifiable({...state.byBook, id: place})));
  }
}

final bookPlacesProvider = NotifierProvider<BookPlacesController, BookPlaces>(
  BookPlacesController.new,
);
