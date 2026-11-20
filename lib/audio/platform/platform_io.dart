import '../downloader.dart';
import '../recording_files.dart';
import 'background_downloader_adapter.dart';
import 'io_recording_files.dart';

Downloader createDownloader() => BackgroundDownloaderAdapter();

RecordingFiles createRecordingFiles() => IoRecordingFiles();
