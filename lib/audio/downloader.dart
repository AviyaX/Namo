/// Where a download is, in the plugin's own words.
enum DownloadStatus {
  enqueued,
  running,
  complete,
  notFound,
  failed,
  canceled,
  waitingToRetry,
  paused,
}

/// One file to download.
class DownloadRequest {
  const DownloadRequest({
    required this.id,
    required this.url,
    required this.directory,
    required this.filename,
    required this.group,
    required this.requiresWiFi,
  });

  final String id;
  final Uri url;

  /// Folder under the base directory returned by [Downloader.start].
  final String directory;
  final String filename;
  final String group;
  final bool requiresWiFi;

  @override
  bool operator ==(Object other) =>
      other is DownloadRequest &&
      other.id == id &&
      other.url == url &&
      other.directory == directory &&
      other.filename == filename &&
      other.group == group &&
      other.requiresWiFi == requiresWiFi;

  @override
  int get hashCode =>
      Object.hash(id, url, directory, filename, group, requiresWiFi);

  @override
  String toString() =>
      'DownloadRequest($id, $url, $directory/$filename, $group, wifi: $requiresWiFi)';
}

/// News about one download.
sealed class DownloadEvent {
  const DownloadEvent(this.id);
  final String id;
}

class DownloadStatusEvent extends DownloadEvent {
  const DownloadStatusEvent(super.id, this.status);
  final DownloadStatus status;

  @override
  bool operator ==(Object other) =>
      other is DownloadStatusEvent && other.id == id && other.status == status;

  @override
  int get hashCode => Object.hash(DownloadStatusEvent, id, status);

  @override
  String toString() => 'DownloadStatusEvent($id, $status)';
}

class DownloadProgressEvent extends DownloadEvent {
  const DownloadProgressEvent(super.id, this.progress);

  /// From 0 to 1 only; negative plugin values are never forwarded.
  final double progress;

  @override
  bool operator ==(Object other) =>
      other is DownloadProgressEvent &&
      other.id == id &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(DownloadProgressEvent, id, progress);

  @override
  String toString() => 'DownloadProgressEvent($id, $progress)';
}

/// Downloads the app starts on its own.
const autoGroup = 'auto';

/// Downloads the reader asks for.
const manualGroup = 'manual';

/// A thin view of the platform's background downloader.
abstract interface class Downloader {
  /// Configures and starts the platform downloader; returns the base directory
  /// (application support) under which [DownloadRequest.directory] lives.
  /// Throws when the platform cannot download.
  Future<String> start();

  Future<void> enqueue(DownloadRequest request);

  Future<void> cancelGroup(String group);

  /// Every task of [autoGroup] and [manualGroup] still known to the platform.
  Future<List<DownloadRequest>> active();

  Stream<DownloadEvent> get events;
}
