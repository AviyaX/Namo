import 'dart:convert';

import 'package:buddhist_gatha/bana/bana_catalogue.dart';
import 'package:buddhist_gatha/bana/bana_repository.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _list(int version) => jsonEncode({'version': version});

class _Env {
  _Env({this.reply});
  final store = InMemoryKeyValueStore();
  String? reply;
  int fetches = 0;
  DateTime now = DateTime(2026, 11, 22, 9);

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        banaFetchProvider.overrideWithValue((url) async {
          fetches++;
          expect(url.path, '/audio/bana/bana.json');
          return reply;
        }),
        banaClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<BanaCatalogue> load(ProviderContainer c) async {
    final cat = await c.read(banaCatalogueProvider.future);
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return cat;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late int bundledVersion;

  setUpAll(() async {
    bundledVersion = BanaCatalogue.parse(
      await rootBundle.loadString('assets/bana/bana.json'),
    )!.version;
  });

  test('the list request sends no User-Agent on the web (CORS preflight)', () {
    expect(banaFetchHeaders(web: true), isEmpty);
    expect(banaFetchHeaders(web: false), containsPair('User-Agent', isNotEmpty));
  });

  test('shows the bundled list with an empty store', () async {
    final env = _Env();
    final cat = await env.load(env.container());
    expect(cat.version, bundledVersion);
    expect(cat.bana, isNotEmpty);
  });

  test('a stored newer list wins over the bundled one', () async {
    final env = _Env();
    env.store.write(banaListKey, _list(bundledVersion + 5));
    env.store.write(banaFetchedAtKey, env.now.toIso8601String());
    final cat = await env.load(env.container());
    expect(cat.version, bundledVersion + 5);
  });

  test('a stored older list does not beat the bundled one', () async {
    final env = _Env();
    env.store.write(banaListKey, _list(bundledVersion - 1));
    final cat = await env.load(env.container());
    expect(cat.version, bundledVersion);
  });

  test('fetches once a day', () async {
    final env = _Env();
    await env.load(env.container());
    expect(env.fetches, 1);
    env.now = env.now.add(const Duration(hours: 23));
    await env.load(env.container());
    expect(env.fetches, 1);
    env.now = env.now.add(const Duration(hours: 2));
    await env.load(env.container());
    expect(env.fetches, 2);
  });

  test('keeps a newer fetched list and stores it', () async {
    final newer = _list(bundledVersion + 1);
    final env = _Env(reply: newer);
    final c = env.container();
    await env.load(c);
    expect(
      c.read(banaCatalogueProvider).requireValue.version,
      bundledVersion + 1,
    );
    expect(env.store.read(banaListKey), newer);
    expect(env.store.read(banaFetchedAtKey), isNotNull);
  });

  final cases = <String, String?>{
    'malformed': 'not json',
    'older': _list(0),
    'the same version': _list(-1), // replaced below with the bundled version
    'a failure': null,
  };
  for (final entry in cases.entries) {
    test('ignores a fetched list that is ${entry.key}', () async {
      final env = _Env(
        reply: entry.key == 'the same version'
            ? _list(bundledVersion)
            : entry.value,
      );
      final c = env.container();
      await env.load(c);
      expect(
        c.read(banaCatalogueProvider).requireValue.version,
        bundledVersion,
      );
      expect(env.store.read(banaListKey), isNull);
      expect(env.store.read(banaFetchedAtKey), env.now.toIso8601String());
    });
  }
}
