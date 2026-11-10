import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small string storage. `main` overrides [keyValueStoreProvider] with a saved
/// one ([SharedPrefsKeyValueStore]).
abstract interface class KeyValueStore {
  String? read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

extension SafeSave on KeyValueStore {
  /// Writes without ever failing the caller: a write that throws, or whose
  /// future fails, is dropped (the app keeps working, unsaved).
  void save(String key, String value) {
    try {
      write(key, value).ignore();
    } catch (_) {}
  }
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

/// Saved storage that survives a restart (Android, iOS and web alike).
class SharedPrefsKeyValueStore implements KeyValueStore {
  SharedPrefsKeyValueStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? read(String key) {
    try {
      return _prefs.getString(key);
    } catch (_) {
      return null; // a value of another type under this key
    }
  }

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

/// The store to start the app on: saved storage, or, if that cannot be
/// opened, the in-memory one (nothing is saved, nothing crashes).
Future<KeyValueStore> openKeyValueStore({
  Future<SharedPreferences> Function() load = SharedPreferences.getInstance,
}) async {
  try {
    return SharedPrefsKeyValueStore(await load());
  } catch (_) {
    return InMemoryKeyValueStore();
  }
}

final keyValueStoreProvider = Provider<KeyValueStore>(
  (_) => InMemoryKeyValueStore(),
);
