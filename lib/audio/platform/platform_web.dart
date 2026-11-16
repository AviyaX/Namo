import '../downloader.dart';
import '../recording_files.dart';

/// The web cannot download recordings to disk.
Downloader createDownloader() =>
    throw UnsupportedError('no downloads on the web');

RecordingFiles createRecordingFiles() =>
    throw UnsupportedError('no downloads on the web');
