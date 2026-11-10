import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Small string storage. Task 13 overrides [keyValueStoreProvider] with a
/// saved one; nothing else changes.
abstract interface class KeyValueStore {
  String? read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _values = {};

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}

final keyValueStoreProvider =
    Provider<KeyValueStore>((_) => InMemoryKeyValueStore());
