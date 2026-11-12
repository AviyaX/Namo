import 'dart:io';
import 'dart:typed_data';

import 'package:buddhist_gatha/content/content_repository.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';
import '../support/test_content.dart';
import 'tipitaka_support.dart';

/// The app opened at [location] with a made-up (or given) Tipitaka.
class TipitakaApp {
  TipitakaApp(this.container, this.store);
  final ProviderContainer container;
  final InMemoryKeyValueStore store;

  void go(String location) => container.read(routerProvider).go(location);

  String get location => container
      .read(routerProvider)
      .routeInformationProvider
      .value
      .uri
      .toString();
}

Future<TipitakaApp> openTipitakaApp(
  WidgetTester t,
  String location, {
  Size size = const Size(400, 900),
  AssetBytes? load,
  InMemoryKeyValueStore? store,
}) async {
  await t.pumpWidget(const SizedBox());
  final kv = store ?? InMemoryKeyValueStore();
  await pumpApp(
    t,
    size: size,
    overrides: [
      contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
      keyValueStoreProvider.overrideWithValue(kv),
      tipitakaRepositoryProvider.overrideWithValue(
        TipitakaRepository(
          load: load ?? fakeAssets(tinyTipitaka()),
          inBackground: false,
        ),
      ),
    ],
    location: location,
  );
  return TipitakaApp(
    ProviderScope.containerOf(t.element(find.byType(MaterialApp))),
    kv,
  );
}

/// The shipped manifest and tree, read from disk now (outside the fake clock
/// of a widget test) and served from memory. Books are not served.
Future<AssetBytes> shippedTreeAssets() async {
  final bytes = <String, Uint8List>{
    for (final path in [tipitakaManifestAsset, tipitakaTreeAsset])
      path: Uint8List.fromList(await File(path).readAsBytes()),
  };
  return (path) async {
    final b = bytes[path];
    if (b == null) throw StateError('no asset $path');
    return b;
  };
}
