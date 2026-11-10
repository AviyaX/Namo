import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'model.dart';

abstract interface class ContentRepository {
  Future<Library> load();
}

class AssetContentRepository implements ContentRepository {
  AssetContentRepository(
    this.bundle, {
    this.paths = const [
      'assets/content/namaskaraya_to_pin_dima.json',
      'assets/content/pirith.json',
    ],
  });

  final AssetBundle bundle;
  final List<String> paths;

  @override
  Future<Library> load() async {
    final categories = <Category>[];
    for (final path in paths) {
      final json = jsonDecode(await bundle.loadString(path));
      if (json is! Map<String, dynamic> || json['schema'] != 1) {
        throw const FormatException('Unsupported content schema.');
      }
      categories.addAll(Library.fromJson(json).categories);
    }
    return Library(categories: categories);
  }
}

final contentRepositoryProvider =
    Provider<ContentRepository>((ref) => AssetContentRepository(rootBundle));

/// A bundled file that fails to load will not load on a retry, so do not retry.
final libraryProvider = FutureProvider<Library>(
  (ref) => ref.watch(contentRepositoryProvider).load(),
  retry: (_, _) => null,
);
