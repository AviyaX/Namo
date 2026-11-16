import 'dart:async';

import 'package:background_downloader/background_downloader.dart';

import '../downloader.dart';

/// [Downloader] on the background_downloader plugin. The only file that
/// imports it.
class BackgroundDownloaderAdapter implements Downloader {
  final _events = StreamController<DownloadEvent>.broadcast();
  StreamSubscription<TaskUpdate>? _subscription;

  @override
  Stream<DownloadEvent> get events => _events.stream;

  @override
  Future<String> start() async {
    final downloader = FileDownloader();
    await downloader.configure(
      globalConfig: [(Config.checkAvailableSpace, 100)],
      iOSConfig: [(Config.excludeFromCloudBackup, true)],
    );
    await _subscription?.cancel();
    _subscription = downloader.updates.listen(_onUpdate);
    await downloader.start();
    return Task.baseDirectoryPath(BaseDirectory.applicationSupport);
  }

  void _onUpdate(TaskUpdate update) {
    switch (update) {
      case TaskStatusUpdate():
        _events.add(
          DownloadStatusEvent(
            update.task.taskId,
            DownloadStatus.values.byName(update.status.name),
          ),
        );
      case TaskProgressUpdate():
        if (update.progress >= 0 && update.progress <= 1) {
          _events.add(
            DownloadProgressEvent(update.task.taskId, update.progress),
          );
        }
    }
  }

  @override
  Future<void> enqueue(DownloadRequest request) async {
    await FileDownloader().enqueue(
      DownloadTask(
        taskId: request.id,
        url: request.url.toString(),
        directory: request.directory,
        filename: request.filename,
        baseDirectory: BaseDirectory.applicationSupport,
        group: request.group,
        updates: Updates.statusAndProgress,
        requiresWiFi: request.requiresWiFi,
        retries: 3,
        allowPause: true,
        metaData: request.id,
      ),
    );
  }

  @override
  Future<void> cancelGroup(String group) async {
    await FileDownloader().cancelAll(group: group);
  }

  @override
  Future<List<DownloadRequest>> active() async {
    final tasks = [
      ...await FileDownloader().allTasks(group: autoGroup),
      ...await FileDownloader().allTasks(group: manualGroup),
    ];
    return [
      for (final t in tasks)
        if (t is DownloadTask)
          DownloadRequest(
            id: t.taskId,
            url: Uri.parse(t.url),
            directory: t.directory,
            filename: t.filename,
            group: t.group,
            requiresWiFi: t.requiresWiFi,
          ),
    ];
  }
}
