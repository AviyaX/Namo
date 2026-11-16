import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../settings/auto_download.dart';
import '../storage/key_value_store.dart';
import 'audio_catalogue.dart';
import 'audio_host.dart';
import 'downloader.dart';
import 'recording_files.dart';
import 'recording_location.dart';
import 'recording_store.dart';

/// One recording as the store keeps it.
class _Entry {
  _Entry(this.recording);

  final Recording recording;
  Availability availability = Availability.notDownloaded;
  double progress = 0;
  String? reason;

  /// The group of its task in the downloader; null when it has none.
  String? group;
  bool requiresWiFi = false;

  /// Its download was damaged once and fetched again.
  bool damagedOnce = false;

  /// The store cancelled its task itself: the next `canceled` is not news.
  bool cancelledByStore = false;

  /// Its download finished and the file is being checked: not to be queued.
  bool verifying = false;

  RecordingStatus get status => RecordingStatus(
    availability: availability,
    progress: availability == Availability.downloading ? progress : 0,
    reason: reason,
    bytes: recording.bytes,
  );

  void show(Availability a, {String? reason}) {
    availability = a;
    this.reason = reason;
  }
}

/// The recordings on a phone: downloaded once, checked, kept on the device.
class DeviceRecordingStore implements RecordingStore {
  DeviceRecordingStore({
    required List<Recording> recordings,
    required this._downloader,
    required this._files,
    required this._store,
    required this._autoDownload,
    required this._turnOffAutoDownload,
    this._urlOf = recordingUrl,
  }) : _entries = [for (final r in recordings) _Entry(r)] {
    _byPath = {for (final e in _entries) e.recording.path: e};
    _snapshot = ValueNotifier(_build());
  }

  final List<_Entry> _entries;
  late final Map<String, _Entry> _byPath;
  final Downloader _downloader;
  final RecordingFiles _files;
  final KeyValueStore _store;
  final VoidCallback _turnOffAutoDownload;
  final Uri Function(Recording) _urlOf;
  AutoDownload _autoDownload;
  late final ValueNotifier<RecordingsSnapshot> _snapshot;

  /// The downloader's base directory; null until it has started.
  String? _base;
  bool _started = false;

  /// The downloader could not start: nothing can be downloaded.
  bool _unavailable = false;
  bool _ready = false;
  bool _disposed = false;
  final _early = <DownloadEvent>[];
  StreamSubscription<DownloadEvent>? _events;
  Map<String, String> _verified = {};

  /// Changes when every file is removed, so checks under way are dropped.
  int _generation = 0;

  /// Runs the store's own work one piece at a time.
  Future<void> _turn = Future.value();

  @override
  ValueListenable<RecordingsSnapshot> get snapshot => _snapshot;

  /// Where [r] is kept, under the downloader's base directory.
  String relativeFile(Recording r) => 'recordings/${r.path}';

  /// Starts the downloader, checks what is on the device and queues what is
  /// missing. Never throws: without a downloader nothing is downloaded.
  Future<void> start() {
    _started = true;
    return _inTurn(_start);
  }

  Future<void> _start() async {
    try {
      _base = await _downloader.start();
    } catch (_) {
      _unavailable = true;
      return;
    }
    _events = _downloader.events.listen(_onEvent);
    _verified = _readVerified();
    var active = <DownloadRequest>[];
    try {
      active = await _downloader.active();
    } catch (_) {}
    final activeById = {for (final t in active) t.id: t};

    final verifiedBefore = Map.of(_verified);
    for (final e in _entries) {
      if (await _onDevice(e.recording)) {
        e.show(Availability.downloaded);
        continue;
      }
      final task = activeById[e.recording.path];
      if (task != null) {
        e.group = task.group;
        e.requiresWiFi = task.requiresWiFi;
        e.show(Availability.waiting);
      }
    }
    if (!mapEquals(verifiedBefore, _verified)) _saveVerified();

    if (_autoDownload != AutoDownload.off) {
      for (final e in _entries) {
        if (e.availability == Availability.notDownloaded && e.group == null) {
          await _enqueue(e, autoGroup, _wifiOnly);
        }
      }
    }
    _ready = true;
    _emit();
    for (final event in List.of(_early)) {
      unawaited(_handle(event));
    }
    _early.clear();
  }

  /// True when a file of the right size and content is there; a wrong one is
  /// deleted.
  Future<bool> _onDevice(Recording r) async {
    final path = _fileOf(r);
    try {
      final size = await _files.sizeOf(path);
      if (size == null) return false;
      if (size == r.bytes) {
        if (_verified[r.path] == r.sha256) return true;
        if (await _files.sha256Of(path) == r.sha256) {
          _verified[r.path] = r.sha256;
          return true;
        }
      }
      _verified.remove(r.path);
      await _files.delete(path);
    } catch (_) {}
    return false;
  }

  /// Follows the setting: the automatic queue is cancelled and queued again
  /// with the new connection rule, or not at all when off.
  void setAutoDownload(AutoDownload v) {
    if (v == _autoDownload) return;
    _autoDownload = v;
    if (!_started) return;
    unawaited(
      _inTurn(() async {
        if (_base == null) return;
        for (final e in _entries.where((e) => e.group == autoGroup)) {
          e.cancelledByStore = true;
          e.group = null;
          e.show(Availability.notDownloaded);
        }
        await _cancel(autoGroup);
        if (_autoDownload != AutoDownload.off) {
          for (final e in _entries) {
            if (e.availability != Availability.downloaded &&
                e.group == null &&
                !e.verifying) {
              await _enqueue(e, autoGroup, _wifiOnly);
            }
          }
        }
        _emit();
      }),
    );
  }

  @override
  Future<void> download(Recording r) => _inTurn(() async {
    final e = _byPath[r.path];
    if (e == null) return;
    if (_unavailable) return _showUnavailable([e]);
    if (_base == null) return;
    await _fetchNow(e);
    _emit();
  });

  @override
  Future<void> downloadAll() => _inTurn(() async {
    if (_unavailable) return _showUnavailable(_entries);
    if (_base == null) return;
    for (final e in _entries) {
      await _fetchNow(e);
    }
    _emit();
  });

  /// Marks [entries] failed: without a downloader nothing can be fetched.
  void _showUnavailable(Iterable<_Entry> entries) {
    for (final e in entries) {
      if (e.availability == Availability.downloaded) continue;
      e.show(Availability.failed, reason: unavailableMessage);
    }
    _emit();
  }

  /// Moves [e] to the manual queue, on any connection. A download already
  /// moving, or already asked for, or being checked, is left alone.
  Future<void> _fetchNow(_Entry e) async {
    if (e.availability == Availability.downloaded ||
        e.availability == Availability.downloading ||
        e.verifying) {
      return;
    }
    if (e.group == manualGroup) return;
    if (e.group == autoGroup) {
      e.cancelledByStore = true;
      try {
        await _downloader.cancel(e.recording.path);
      } catch (_) {}
    }
    await _enqueue(e, manualGroup, false);
  }

  @override
  Future<void> removeAll() => _inTurn(() async {
    _autoDownload = AutoDownload.off;
    _turnOffAutoDownload();
    _generation++;
    for (final e in _entries.where((e) => e.group != null)) {
      e.cancelledByStore = true;
      e.group = null;
    }
    if (_base != null) {
      await _cancel(autoGroup);
      await _cancel(manualGroup);
      for (final e in _entries) {
        try {
          await _files.delete(_fileOf(e.recording));
        } catch (_) {}
      }
    }
    _verified = {};
    _store.save(verifiedKey, '{}');
    for (final e in _entries) {
      e.show(Availability.notDownloaded);
      e.damagedOnce = false;
    }
    _emit();
  });

  @override
  RecordingLocation? locationFor(Recording r) {
    if (r.placeholder) return AssetLocation(r.path);
    final e = _byPath[r.path];
    if (e == null || e.availability != Availability.downloaded) return null;
    if (_base == null) return null;
    return FileLocation(_fileOf(r));
  }

  Future<void> dispose() async {
    _disposed = true;
    await _events?.cancel();
    _snapshot.dispose();
  }

  void _onEvent(DownloadEvent event) {
    if (!_ready) {
      _early.add(event);
    } else {
      unawaited(_handle(event));
    }
  }

  Future<void> _handle(DownloadEvent event) async {
    final e = _byPath[event.id];
    if (e == null || _disposed) return;
    if (event case DownloadStatusEvent(status: DownloadStatus.canceled)) {
      if (e.cancelledByStore) {
        e.cancelledByStore = false;
        return;
      }
      if (e.group == null) return;
      e.group = null;
      e.show(Availability.notDownloaded);
      _emit();
      return;
    }
    if (e.group == null) return; // no task of ours
    switch (event) {
      case DownloadProgressEvent(:final progress):
        e.progress = progress;
        e.show(Availability.downloading);
      case DownloadStatusEvent(:final status):
        switch (status) {
          case DownloadStatus.running:
            e.show(Availability.downloading);
          case DownloadStatus.enqueued ||
              DownloadStatus.waitingToRetry ||
              DownloadStatus.paused:
            e.show(Availability.waiting);
          case DownloadStatus.complete:
            final group = e.group!;
            e.group = null;
            e.verifying = true;
            try {
              await _verifyDownload(e, group, e.requiresWiFi);
            } finally {
              e.verifying = false;
            }
          case DownloadStatus.notFound:
            e.group = null;
            e.show(Availability.failed, reason: notOnServerMessage);
          case DownloadStatus.failed:
            e.group = null;
            e.show(Availability.failed, reason: connectionMessage);
          case DownloadStatus.canceled:
            break; // handled above
        }
    }
    _emit();
  }

  /// Checks a finished download by size, then content; a damaged one is
  /// deleted and fetched again once.
  Future<void> _verifyDownload(_Entry e, String group, bool wifi) async {
    final generation = _generation;
    final r = e.recording;
    final path = _fileOf(r);
    var good = false;
    try {
      good =
          await _files.sizeOf(path) == r.bytes &&
          await _files.sha256Of(path) == r.sha256;
    } catch (_) {}
    if (generation != _generation || _disposed) return;
    if (good) {
      _verified[r.path] = r.sha256;
      _saveVerified();
      e.damagedOnce = false;
      e.show(Availability.downloaded);
      return;
    }
    try {
      await _files.delete(path);
    } catch (_) {}
    if (generation != _generation || _disposed) return;
    e.show(Availability.failed, reason: damagedMessage);
    if (!e.damagedOnce) {
      e.damagedOnce = true;
      await _enqueue(e, group, wifi, showWaiting: false);
    }
  }

  /// Queues [e]'s download; it reads waiting unless [showWaiting] is false.
  Future<void> _enqueue(
    _Entry e,
    String group,
    bool wifi, {
    bool showWaiting = true,
  }) async {
    e.group = group;
    e.requiresWiFi = wifi;
    e.progress = 0;
    if (showWaiting) e.show(Availability.waiting);
    try {
      await _downloader.enqueue(_requestFor(e.recording, group, wifi));
    } catch (_) {
      e.group = null;
      e.show(Availability.failed, reason: connectionMessage);
    }
  }

  DownloadRequest _requestFor(Recording r, String group, bool wifi) {
    final slash = r.path.lastIndexOf('/');
    return DownloadRequest(
      id: r.path,
      url: _urlOf(r),
      directory: slash < 0
          ? 'recordings'
          : 'recordings/${r.path.substring(0, slash)}',
      filename: r.path.substring(slash + 1),
      group: group,
      requiresWiFi: wifi,
    );
  }

  Future<void> _cancel(String group) async {
    try {
      await _downloader.cancelGroup(group);
    } catch (_) {}
  }

  Future<void> _inTurn(Future<void> Function() work) {
    final next = _turn.then((_) => work()).onError((error, _) {
      if (kDebugMode) debugPrint('RecordingStore: $error');
    });
    _turn = next;
    return next;
  }

  bool get _wifiOnly => _autoDownload == AutoDownload.wifiOnly;

  String _fileOf(Recording r) => '$_base/${relativeFile(r)}';

  Map<String, String> _readVerified() {
    try {
      final saved = jsonDecode(_store.read(verifiedKey) ?? '{}');
      if (saved is! Map) return {};
      return {
        for (final entry in saved.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } catch (_) {
      return {};
    }
  }

  void _saveVerified() => _store.save(verifiedKey, jsonEncode(_verified));

  RecordingsSnapshot _build() => RecordingsSnapshot({
    for (final e in _entries) e.recording.readingId: e.status,
  });

  /// Publishes the statuses; the notifier stays quiet when nothing changed.
  void _emit() {
    if (_disposed) return;
    _snapshot.value = _build();
  }
}
