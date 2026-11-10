import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/key_value_store.dart';
import 'reading_position.dart';

const positionKey = 'namo.position.v1';

/// Where a reading was left and how far through it that is (0–1).
class ReadingProgress {
  const ReadingProgress({required this.position, required this.progress});

  final ReadingPosition position;
  final double progress;

  Map<String, dynamic> toJson() => {
    'position': position.toJson(),
    'progress': progress,
  };

  /// Null without a readable position; a damaged progress is 0.
  static ReadingProgress? fromJson(Object? json) {
    if (json is! Map) return null;
    final position = ReadingPosition.fromJson(json['position']);
    if (position == null) return null;
    final progress = json['progress'];
    return ReadingProgress(
      position: position,
      progress: progress is num && progress.isFinite
          ? progress.toDouble().clamp(0.0, 1.0)
          : 0,
    );
  }
}

class PositionState {
  const PositionState({this.byReading = const {}, this.lastReadingId});

  final Map<String, ReadingProgress> byReading;

  /// The reading most recently saved, while it still has a position.
  final String? lastReadingId;

  Map<String, dynamic> toJson() => {
    'byReading': {for (final e in byReading.entries) e.key: e.value.toJson()},
    if (lastReadingId != null) 'lastReadingId': lastReadingId,
  };

  /// Damaged data gives the empty state; within it, an entry that cannot be
  /// read (or is filed under another reading's id) is dropped alone.
  factory PositionState.fromJson(Object? json) {
    if (json is! Map) return const PositionState();
    final raw = json['byReading'];
    final byReading = <String, ReadingProgress>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        final p = ReadingProgress.fromJson(e.value);
        if (e.key is String && p != null && p.position.readingId == e.key) {
          byReading[e.key as String] = p;
        }
      }
    }
    final last = json['lastReadingId'];
    return PositionState(
      byReading: Map.unmodifiable(byReading),
      lastReadingId: last is String && byReading.containsKey(last)
          ? last
          : null,
    );
  }
}

class PositionController extends Notifier<PositionState> {
  @override
  PositionState build() {
    final text = ref.read(keyValueStoreProvider).read(positionKey);
    if (text == null) return const PositionState();
    try {
      return PositionState.fromJson(jsonDecode(text));
    } on FormatException {
      return const PositionState();
    }
  }

  void _set(PositionState next) {
    state = next;
    ref
        .read(keyValueStoreProvider)
        .write(positionKey, jsonEncode(next.toJson()));
  }

  /// Does nothing once the app's providers are gone (the reader can save as
  /// the whole app closes).
  void save(ReadingPosition p, double progress) {
    if (!ref.mounted) return;
    _set(
      PositionState(
        byReading: Map.unmodifiable({
          ...state.byReading,
          p.readingId: ReadingProgress(
            position: p,
            progress: progress.clamp(0.0, 1.0),
          ),
        }),
        lastReadingId: p.readingId,
      ),
    );
  }

  void clear(String readingId) {
    if (!state.byReading.containsKey(readingId)) return;
    _set(
      PositionState(
        byReading: Map.unmodifiable({...state.byReading}..remove(readingId)),
        lastReadingId: state.lastReadingId == readingId
            ? null
            : state.lastReadingId,
      ),
    );
  }
}

final positionProvider = NotifierProvider<PositionController, PositionState>(
  PositionController.new,
);
