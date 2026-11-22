import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/key_value_store.dart';
import 'bana_catalogue.dart';

const banaLastPartKey = 'bana.lastPart';

/// The last part opened in each series: series id to video id.
class BanaProgress extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    final text = ref.read(keyValueStoreProvider).read(banaLastPartKey);
    if (text == null) return const {};
    try {
      final json = jsonDecode(text);
      if (json is! Map) return const {};
      return Map.unmodifiable({
        for (final e in json.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      });
    } on FormatException {
      return const {};
    }
  }

  /// Remembers [b] as the last part opened in its series (if it has one).
  void opened(Bana b) {
    final series = b.series;
    if (series == null || !ref.mounted) return;
    state = Map.unmodifiable({...state, series: b.id});
    ref.read(keyValueStoreProvider).save(banaLastPartKey, jsonEncode(state));
  }

  String? lastPart(String seriesId) => state[seriesId];
}

final banaProgressProvider = NotifierProvider<BanaProgress, Map<String, String>>(
  BanaProgress.new,
);
