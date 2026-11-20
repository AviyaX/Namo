/// Loads the bundled books: the index (once) and the books (a few kept).
/// Nothing is loaded until it is first asked for.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tipitaka/tipitaka_repository.dart' show AssetBytes, gunzipIfNeeded;
import 'book_model.dart';

const booksIndexAsset = 'assets/books/index.json';

Object? _decodeJson(Uint8List bytes) =>
    jsonDecode(utf8.decode(gunzipIfNeeded(bytes)));

/// Unpacks and parses one book file: (asset path, bytes). Top-level, so it
/// can run in [compute].
Book parseBookBytes((String, Uint8List) input) {
  final (path, bytes) = input;
  try {
    return Book.parse(_decodeJson(bytes));
  } on FormatException catch (e) {
    throw FormatException('$path: ${e.message}');
  }
}

Future<Uint8List> _rootBundleBytes(String path) async {
  final data = await rootBundle.load(path);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

class BooksRepository {
  /// [load] defaults to the app's asset bundle. A book is unpacked and parsed
  /// on a background isolate via [compute] (inline on web) unless
  /// `inBackground` is false (useful under a fake clock in widget tests).
  BooksRepository({
    AssetBytes? load,
    this._inBackground = true,
    int keepBooks = 2,
  }) : _load = load ?? _rootBundleBytes,
       _keepBooks = keepBooks < 1 ? 1 : keepBooks;

  final AssetBytes _load;
  final bool _inBackground;
  final int _keepBooks;

  Future<BooksIndex>? _index;

  /// Most recently used last (a map literal keeps insertion order).
  final _books = <String, Future<Book>>{};

  /// Loaded once, then kept.
  Future<BooksIndex> index() {
    final kept = _index;
    if (kept != null) return kept;
    final future = _started(
      () async {
        final bytes = await _bytes(booksIndexAsset);
        return BooksIndex.parse(_decodeJson(bytes));
      },
      onError: (f) {
        if (identical(_index, f)) _index = null;
      },
    );
    return _index = future;
  }

  /// The book at [assetPath]; keeps the `keepBooks` most recently used.
  Future<Book> book(String assetPath) {
    final kept = _books.remove(assetPath);
    if (kept != null) {
      _books[assetPath] = kept;
      return kept;
    }
    final future = _started(
      () async {
        final bytes = await _bytes(assetPath);
        final input = (assetPath, bytes);
        if (!_inBackground) return parseBookBytes(input);
        return compute(parseBookBytes, input);
      },
      onError: (f) {
        if (identical(_books[assetPath], f)) _books.remove(assetPath);
      },
    );
    _books[assetPath] = future;
    while (_books.length > _keepBooks) {
      _books.remove(_books.keys.first);
    }
    return future;
  }

  /// The asset's bytes; a loader that throws at once still fails later, as
  /// a future, so the caller has stored the future before [_started]'s
  /// error handler runs.
  Future<Uint8List> _bytes(String path) => Future.sync(() => _load(path));

  /// Runs [work]; if it fails, calls [onError] with the returned future (so
  /// it can be forgotten and the next call tries again) and passes the error
  /// on.
  static Future<T> _started<T>(
    Future<T> Function() work, {
    required void Function(Future<T>) onError,
  }) {
    late final Future<T> future;
    future = () async {
      try {
        return await work();
      } catch (_) {
        onError(future);
        rethrow;
      }
    }();
    return future;
  }
}

final booksRepositoryProvider = Provider<BooksRepository>(
  (ref) => BooksRepository(),
);

// A shipped file that fails to load will fail again: no automatic retry, so
// the message shows once. The repository forgets a failed load, so a book
// opened again (or a provider invalidated) tries afresh.
Duration? _noRetry(int _, Object _) => null;

final booksIndexProvider = FutureProvider<BooksIndex>(
  (ref) => ref.watch(booksRepositoryProvider).index(),
  retry: _noRetry,
);

/// The book with this id. Disposed when no longer watched, so a closed book
/// does not stay in memory beyond the repository's few.
final bookProvider = FutureProvider.autoDispose.family<Book, String>((
  ref,
  id,
) async {
  final repository = ref.watch(booksRepositoryProvider);
  final index = await ref.watch(booksIndexProvider.future);
  final summary = index.byId(id) ?? (throw StateError('no book $id'));
  return repository.book(summary.file);
}, retry: _noRetry);
