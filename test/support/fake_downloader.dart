import 'dart:async';

import 'package:buddhist_gatha/audio/downloader.dart';

/// A downloader that downloads nothing: tests write the files themselves and
/// call [finish] or [emit].
class FakeDownloader implements Downloader {
  /// What [start] returns; tests pass a real temp directory.
  String base = '/tmp/fake';

  /// Makes [start] throw.
  bool failToStart = false;

  /// Everything ever enqueued, in order.
  final enqueued = <DownloadRequest>[];

  /// Every group passed to [cancelGroup], in order.
  final cancelledGroups = <String>[];

  /// Every id passed to [cancel], in order.
  final cancelledIds = <String>[];

  /// Tasks the platform already knew before this run; returned by [active].
  List<DownloadRequest> preExisting = [];

  final _live = <DownloadRequest>[];
  final _controller = StreamController<DownloadEvent>.broadcast();

  /// Enqueued, not yet cancelled or finished.
  List<DownloadRequest> get live => List.unmodifiable(_live);

  @override
  Future<String> start() async {
    if (failToStart) throw StateError('cannot download here');
    return base;
  }

  @override
  Future<void> enqueue(DownloadRequest request) async {
    enqueued.add(request);
    _live.add(request);
  }

  @override
  Future<void> cancelGroup(String group) async {
    cancelledGroups.add(group);
    final gone = _live.where((r) => r.group == group).toList();
    _live.removeWhere((r) => r.group == group);
    for (final r in gone) {
      emit(DownloadStatusEvent(r.id, DownloadStatus.canceled));
    }
  }

  @override
  Future<void> cancel(String id) async {
    cancelledIds.add(id);
    final gone = _live.where((r) => r.id == id).toList();
    _live.removeWhere((r) => r.id == id);
    for (final r in gone) {
      emit(DownloadStatusEvent(r.id, DownloadStatus.canceled));
    }
  }

  @override
  Future<List<DownloadRequest>> active() async => [...preExisting, ..._live];

  @override
  Stream<DownloadEvent> get events => _controller.stream;

  void emit(DownloadEvent e) => _controller.add(e);

  /// Ends the task [id] as complete.
  void finish(String id) {
    _live.removeWhere((r) => r.id == id);
    emit(DownloadStatusEvent(id, DownloadStatus.complete));
  }
}
