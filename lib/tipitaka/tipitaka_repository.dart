/// Loads the shipped Tripitaka files: the manifest, the tree (once) and the
/// books (a few kept). Nothing is loaded until it is first asked for.
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tipitaka_book.dart';
import 'tipitaka_tree.dart';

typedef AssetBytes = Future<Uint8List> Function(String assetPath);

const tipitakaManifestAsset = 'assets/tipitaka/manifest.json';
const tipitakaTreeAsset = 'assets/tipitaka/tree.json.gz';
String tipitakaBookAsset(String file) => 'assets/tipitaka/text/$file.json.gz';

/// Unpacks gzip (first bytes 0x1f 0x8b); returns anything else unchanged.
///
/// A web host may serve a `.gz` file already unpacked (with
/// `Content-Encoding: gzip`), so plain bytes are accepted as they are.
Uint8List gunzipIfNeeded(Uint8List bytes) {
  if (bytes.length < 2 || bytes[0] != 0x1f || bytes[1] != 0x8b) return bytes;
  return GZipDecoder().decodeBytes(bytes, verify: true);
}

Object? _decodeJson(Uint8List bytes) =>
    jsonDecode(utf8.decode(gunzipIfNeeded(bytes)));

class TipitakaManifest {
  const TipitakaManifest({
    required this.commit,
    required this.commitDate,
    required this.readings,
    required this.parentsWithText,
  });

  /// Throws [FormatException] if [json] is not a manifest.
  factory TipitakaManifest.parse(Object? json) {
    if (json is! Map) throw const FormatException('manifest: not an object');
    final commit = json['commit'];
    final date = json['commitDate'];
    final readings = json['readings'];
    final parents = json['parentsWithText'];
    if (commit is! String ||
        date is! String ||
        readings is! int ||
        parents is! List) {
      throw const FormatException('manifest: missing fields');
    }
    return TipitakaManifest(
      commit: commit,
      commitDate: date,
      readings: readings,
      parentsWithText: {
        for (final p in parents)
          if (p is String) p,
      },
    );
  }

  final String commit, commitDate;
  final int readings;
  final Set<String> parentsWithText;
}

TipitakaTree _parseTree((Uint8List, Set<String>) input) =>
    TipitakaTree.parse(_decodeJson(input.$1), parentsWithText: input.$2);

TipitakaBook _parseBook((String, Uint8List) input) =>
    TipitakaBook.parse(input.$1, _decodeJson(input.$2));

Future<Uint8List> _rootBundleBytes(String path) async {
  final data = await rootBundle.load(path);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

class TipitakaRepository {
  /// [load] defaults to the app's asset bundle. Unpacking and parsing run on
  /// a background isolate via [compute] (inline on web) unless
  /// `inBackground` is false (useful under a fake clock in widget tests).
  TipitakaRepository({
    AssetBytes? load,
    int keepBooks = 4,
    this._inBackground = true,
    bool? paintFirst,
  }) : _paintFirst = paintFirst ?? kIsWeb,
       _load = load ?? _rootBundleBytes,
       _keepBooks = keepBooks < 1 ? 1 : keepBooks;

  final AssetBytes _load;
  final int _keepBooks;
  final bool _inBackground;

  /// On web `compute` runs on the same thread, so the end of the current
  /// frame is awaited first and the progress mark paints before the unpack
  /// and parse. [paintFirst] defaults to [kIsWeb].
  final bool _paintFirst;

  Future<TipitakaManifest>? _manifest;
  Future<TipitakaTree>? _tree;

  /// Most recently used last (a map literal keeps insertion order).
  final _books = <String, Future<TipitakaBook>>{};

  Future<R> _run<Q, R>(R Function(Q) work, Q input) async {
    if (!_inBackground) return work(input);
    if (_paintFirst) await _endOfFrame();
    return compute(work, input);
  }

  /// Waits for the current frame to finish drawing. Gives up after a moment
  /// (a hidden tab or a test that never pumps draws no frames).
  static Future<void> _endOfFrame() async {
    try {
      await SchedulerBinding.instance.endOfFrame.timeout(
        const Duration(milliseconds: 250),
        onTimeout: () {},
      );
    } catch (_) {
      // No binding: nothing to wait for.
    }
  }

  Future<TipitakaManifest> manifest() {
    final kept = _manifest;
    if (kept != null) return kept;
    final future = _started(() async {
      final bytes = await _bytes(tipitakaManifestAsset);
      return TipitakaManifest.parse(_decodeJson(bytes));
    }, onError: (f) {
      if (identical(_manifest, f)) _manifest = null;
    });
    return _manifest = future;
  }

  /// Loaded once, then kept.
  Future<TipitakaTree> tree() {
    final kept = _tree;
    if (kept != null) return kept;
    final future = _started(() async {
      final parents = (await manifest()).parentsWithText;
      final bytes = await _bytes(tipitakaTreeAsset);
      return _run(_parseTree, (bytes, parents));
    }, onError: (f) {
      if (identical(_tree, f)) _tree = null;
    });
    return _tree = future;
  }

  /// Keeps the `keepBooks` most recently used books.
  Future<TipitakaBook> book(String file) {
    final kept = _books.remove(file);
    if (kept != null) {
      _books[file] = kept;
      return kept;
    }
    final future = _started(() async {
      final bytes = await _bytes(tipitakaBookAsset(file));
      return _run(_parseBook, (file, bytes));
    }, onError: (f) {
      if (identical(_books[file], f)) _books.remove(file);
    });
    _books[file] = future;
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

final tipitakaRepositoryProvider = Provider<TipitakaRepository>(
  (ref) => TipitakaRepository(),
);

// A shipped file that fails to load will fail again: no automatic retry, so
// the message shows once. The repository forgets a failed load, so a reading
// opened again (or a provider invalidated) tries afresh.
Duration? _noRetry(int _, Object _) => null;

final tipitakaTreeProvider = FutureProvider<TipitakaTree>(
  (ref) => ref.watch(tipitakaRepositoryProvider).tree(),
  retry: _noRetry,
);

final tipitakaManifestProvider = FutureProvider<TipitakaManifest>(
  (ref) => ref.watch(tipitakaRepositoryProvider).manifest(),
  retry: _noRetry,
);

/// Null when the key is unknown or not a reading. Disposed when no longer
/// watched, so a reading does not keep its book in memory.
final tipitakaReadingProvider = FutureProvider.autoDispose
    .family<TipitakaReading?, String>((ref, key) async {
      final repository = ref.watch(tipitakaRepositoryProvider);
      final tree = await ref.watch(tipitakaTreeProvider.future);
      final node = tree.node(key);
      if (node == null || !tree.isReading(key)) return null;
      final book = await repository.book(node.file);
      return readingOf(tree, book, key);
    }, retry: _noRetry);
