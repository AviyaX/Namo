import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/key_value_store.dart';
import 'tipitaka_tree.dart';

const tipitakaPlacesKey = 'namo.tipitaka.places.v1';
const tipitakaSavedKey = 'namo.tipitaka.saved.v1';
const tipitakaViewKey = 'namo.tipitaka.view.v1';

/// Decoded stored JSON, or null when absent or damaged.
Object? _readJson(Ref ref, String key) {
  final text = ref.read(keyValueStoreProvider).read(key);
  if (text == null) return null;
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}

double _clampFraction(num v) {
  final d = v.toDouble();
  if (d.isNaN) return 0;
  return d.clamp(0.0, 1.0);
}

/// Where the person stopped reading one text.
@immutable
class TipitakaPlace {
  const TipitakaPlace({
    required this.key,
    required this.entry,
    required this.fraction,
    required this.order,
  });

  final String key;

  /// Index within the reading of the entry at the top.
  final int entry;

  /// 0..1, how far down that entry.
  final double fraction;

  /// A counter (highest existing + 1), not a clock.
  final int order;

  Map<String, dynamic> toJson() => {
    'key': key,
    'entry': entry,
    'fraction': fraction,
    'order': order,
  };

  static TipitakaPlace? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'],
        entry = json['entry'],
        fraction = json['fraction'],
        order = json['order'];
    if (key is! String || entry is! num || fraction is! num || order is! num) {
      return null;
    }
    if (!entry.isFinite || !fraction.isFinite || !order.isFinite) return null;
    return TipitakaPlace(
      key: key,
      entry: entry.toInt() < 0 ? 0 : entry.toInt(),
      fraction: _clampFraction(fraction),
      order: order.toInt(),
    );
  }
}

class TipitakaPlaces {
  const TipitakaPlaces([this.recent = const []]);

  static const keep = 200;

  /// Most recently read first.
  final List<TipitakaPlace> recent;

  TipitakaPlace? of(String key) {
    for (final p in recent) {
      if (p.key == key) return p;
    }
    return null;
  }
}

class TipitakaPlacesController extends Notifier<TipitakaPlaces> {
  @override
  TipitakaPlaces build() {
    final json = _readJson(ref, tipitakaPlacesKey);
    if (json is! List) return const TipitakaPlaces();
    final byKey = <String, TipitakaPlace>{};
    for (final item in json) {
      final p = TipitakaPlace.fromJson(item);
      if (p == null) continue;
      final old = byKey[p.key];
      if (old == null || p.order > old.order) byKey[p.key] = p;
    }
    return _from(byKey.values);
  }

  static TipitakaPlaces _from(Iterable<TipitakaPlace> places) {
    final sorted = places.toList()..sort((a, b) => b.order.compareTo(a.order));
    return TipitakaPlaces(
      List.unmodifiable(sorted.take(TipitakaPlaces.keep)),
    );
  }

  void _set(TipitakaPlaces next) {
    state = next;
    ref
        .read(keyValueStoreProvider)
        .save(
          tipitakaPlacesKey,
          jsonEncode([for (final p in next.recent) p.toJson()]),
        );
  }

  /// [entry]: index within the reading of the entry at the top; [fraction]
  /// 0..1. Gives the place the highest order; drops the oldest beyond
  /// [TipitakaPlaces.keep].
  void remember(String key, {required int entry, required double fraction}) {
    final top = state.recent.isEmpty ? 0 : state.recent.first.order;
    final place = TipitakaPlace(
      key: key,
      entry: entry < 0 ? 0 : entry,
      fraction: _clampFraction(fraction),
      order: top + 1,
    );
    _set(_from([place, ...state.recent.where((p) => p.key != key)]));
  }

  void drop(Iterable<String> keys) {
    final gone = keys.toSet();
    if (!state.recent.any((p) => gone.contains(p.key))) return;
    _set(_from(state.recent.where((p) => !gone.contains(p.key))));
  }
}

final tipitakaPlacesProvider =
    NotifierProvider<TipitakaPlacesController, TipitakaPlaces>(
      TipitakaPlacesController.new,
    );

/// Bookmarked reading keys, newest first.
class TipitakaSavedController extends Notifier<List<String>> {
  @override
  List<String> build() {
    final json = _readJson(ref, tipitakaSavedKey);
    if (json is! List) return const [];
    return List.unmodifiable(json.whereType<String>().toSet());
  }

  void _set(List<String> next) {
    state = List.unmodifiable(next);
    ref.read(keyValueStoreProvider).save(tipitakaSavedKey, jsonEncode(next));
  }

  void toggle(String key) {
    _set(
      state.contains(key)
          ? state.where((k) => k != key).toList()
          : [key, ...state],
    );
  }

  void drop(Iterable<String> keys) {
    final gone = keys.toSet();
    if (!state.any(gone.contains)) return;
    _set(state.where((k) => !gone.contains(k)).toList());
  }
}

final tipitakaSavedProvider =
    NotifierProvider<TipitakaSavedController, List<String>>(
      TipitakaSavedController.new,
    );

enum TipitakaView { pali, sinhala, both }

/// Null until the person chooses.
class TipitakaViewController extends Notifier<TipitakaView?> {
  @override
  TipitakaView? build() {
    final json = _readJson(ref, tipitakaViewKey);
    if (json is! String) return null;
    for (final v in TipitakaView.values) {
      if (v.name == json) return v;
    }
    return null;
  }

  void choose(TipitakaView view) {
    state = view;
    ref.read(keyValueStoreProvider).save(tipitakaViewKey, jsonEncode(view.name));
  }
}

final tipitakaViewProvider =
    NotifierProvider<TipitakaViewController, TipitakaView?>(
      TipitakaViewController.new,
    );

TipitakaView defaultTipitakaView({required bool wide}) =>
    wide ? TipitakaView.both : TipitakaView.sinhala;

void _prune(
  TipitakaPlacesController places,
  TipitakaSavedController saved,
  TipitakaPlaces placed,
  List<String> bookmarked,
  TipitakaTree tree,
) {
  places.drop([
    for (final p in placed.recent)
      if (!tree.isReading(p.key)) p.key,
  ]);
  saved.drop([
    for (final k in bookmarked)
      if (!tree.isReading(k)) k,
  ]);
}

/// Drops places and bookmarks whose key is not a reading in [tree].
void pruneTipitakaState(WidgetRef ref, TipitakaTree tree) => _prune(
  ref.read(tipitakaPlacesProvider.notifier),
  ref.read(tipitakaSavedProvider.notifier),
  ref.read(tipitakaPlacesProvider),
  ref.read(tipitakaSavedProvider),
  tree,
);

/// The same, for callers without a WidgetRef (a [ProviderContainer]).
void pruneTipitakaStateIn(ProviderContainer container, TipitakaTree tree) =>
    _prune(
      container.read(tipitakaPlacesProvider.notifier),
      container.read(tipitakaSavedProvider.notifier),
      container.read(tipitakaPlacesProvider),
      container.read(tipitakaSavedProvider),
      tree,
    );
