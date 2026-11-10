import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/key_value_store.dart';

const savedKey = 'namo.saved.v1';

@immutable
class Bookmark {
  const Bookmark({required this.readingId, required this.sectionId});

  final String readingId, sectionId;

  Map<String, dynamic> toJson() => {
    'readingId': readingId,
    'sectionId': sectionId,
  };

  static Bookmark? fromJson(Object? json) {
    if (json is! Map) return null;
    final readingId = json['readingId'], sectionId = json['sectionId'];
    if (readingId is! String || sectionId is! String) return null;
    return Bookmark(readingId: readingId, sectionId: sectionId);
  }

  @override
  bool operator ==(Object other) =>
      other is Bookmark &&
      other.readingId == readingId &&
      other.sectionId == sectionId;

  @override
  int get hashCode => Object.hash(readingId, sectionId);
}

/// Bookmarked sections (newest first) and favourite readings.
class SavedState {
  const SavedState({this.bookmarks = const [], this.favourites = const {}});

  final List<Bookmark> bookmarks;
  final Set<String> favourites;

  bool isBookmarked(String readingId, String sectionId) =>
      bookmarks.contains(Bookmark(readingId: readingId, sectionId: sectionId));

  bool isFavourite(String readingId) => favourites.contains(readingId);

  Map<String, dynamic> toJson() => {
    'bookmarks': [for (final b in bookmarks) b.toJson()],
    'favourites': favourites.toList(),
  };

  /// Damaged data gives the empty state; within it, an entry that cannot be
  /// read is dropped alone.
  factory SavedState.fromJson(Object? json) {
    if (json is! Map) return const SavedState();
    final marks = json['bookmarks'], favs = json['favourites'];
    final bookmarks = <Bookmark>[];
    if (marks is List) {
      for (final m in marks) {
        final b = Bookmark.fromJson(m);
        if (b != null && !bookmarks.contains(b)) bookmarks.add(b);
      }
    }
    return SavedState(
      bookmarks: List.unmodifiable(bookmarks),
      favourites: Set.unmodifiable(
        favs is List ? favs.whereType<String>() : const <String>[],
      ),
    );
  }
}

class SavedController extends Notifier<SavedState> {
  @override
  SavedState build() {
    final text = ref.read(keyValueStoreProvider).read(savedKey);
    if (text == null) return const SavedState();
    try {
      return SavedState.fromJson(jsonDecode(text));
    } on FormatException {
      return const SavedState();
    }
  }

  void _set(SavedState next) {
    state = next;
    ref.read(keyValueStoreProvider).save(savedKey, jsonEncode(next.toJson()));
  }

  void toggleBookmark(String readingId, String sectionId) {
    final mark = Bookmark(readingId: readingId, sectionId: sectionId);
    final on = state.bookmarks.contains(mark);
    _set(
      SavedState(
        bookmarks: List.unmodifiable(
          on
              ? state.bookmarks.where((b) => b != mark)
              : [mark, ...state.bookmarks],
        ),
        favourites: state.favourites,
      ),
    );
  }

  void toggleFavourite(String readingId) {
    final next = {...state.favourites};
    if (!next.remove(readingId)) next.add(readingId);
    _set(
      SavedState(
        bookmarks: state.bookmarks,
        favourites: Set.unmodifiable(next),
      ),
    );
  }
}

final savedProvider = NotifierProvider<SavedController, SavedState>(
  SavedController.new,
);
