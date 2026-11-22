import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../audio/audio_host.dart';
import '../storage/key_value_store.dart';
import 'bana_catalogue.dart';

const banaListKey = 'bana.list';
const banaFetchedAtKey = 'bana.fetchedAt';
const banaBundledAsset = 'assets/bana/bana.json';
const banaRefreshEvery = Duration(hours: 24);

/// The text at [url], or null on any failure.
typedef BanaFetch = Future<String?> Function(Uri url);

Uri get banaListUrl => Uri.parse('$audioBaseUrl/audio/bana/bana.json');

Future<String?> _httpFetch(Uri url) async {
  try {
    final r = await http
        .get(url, headers: {'User-Agent': audioUserAgent})
        .timeout(const Duration(seconds: 20));
    return r.statusCode == 200 ? r.body : null;
  } catch (_) {
    return null;
  }
}

final banaFetchProvider = Provider<BanaFetch>((_) => _httpFetch);

final banaClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

class BanaCatalogueController extends AsyncNotifier<BanaCatalogue> {
  @override
  Future<BanaCatalogue> build() async {
    final store = ref.read(keyValueStoreProvider);
    final bundled = BanaCatalogue.parse(
      await rootBundle.loadString(banaBundledAsset),
    )!;
    final text = store.read(banaListKey);
    final stored = text == null ? null : BanaCatalogue.parse(text);
    final current = stored != null && stored.version >= bundled.version
        ? stored
        : bundled;
    if (_due(store)) unawaited(_refresh(current.version));
    return current;
  }

  bool _due(KeyValueStore store) {
    final at = DateTime.tryParse(store.read(banaFetchedAtKey) ?? '');
    if (at == null) return true;
    return ref.read(banaClockProvider)().difference(at) >= banaRefreshEvery;
  }

  Future<void> _refresh(int version) async {
    final store = ref.read(keyValueStoreProvider);
    final fetch = ref.read(banaFetchProvider);
    final now = ref.read(banaClockProvider)();
    String? body;
    try {
      body = await fetch(banaListUrl);
    } catch (_) {}
    if (!ref.mounted) return;
    store.save(banaFetchedAtKey, now.toIso8601String());
    if (body == null) return;
    final fresh = BanaCatalogue.parse(body);
    if (fresh == null || fresh.version <= version) return;
    store.save(banaListKey, body);
    state = AsyncData(fresh);
  }
}

final banaCatalogueProvider =
    AsyncNotifierProvider<BanaCatalogueController, BanaCatalogue>(
      BanaCatalogueController.new,
    );
