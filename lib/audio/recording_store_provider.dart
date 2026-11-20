import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content_repository.dart';
import '../settings/auto_download.dart';
import '../settings/settings.dart';
import '../storage/key_value_store.dart';
import 'audio_catalogue.dart';
import 'platform/platform.dart';
import 'recording_store.dart';
import 'recording_store_device.dart';

/// The app's recordings: none until the library is loaded, streamed in the
/// browser, kept on the device elsewhere. Started when first read.
final recordingStoreProvider = Provider<RecordingStore>((ref) {
  final library = ref.watch(libraryProvider).value;
  if (library == null) return EmptyRecordingStore();
  final recordings = ContentAudioCatalogue(library).recordings;
  if (kIsWeb) return WebRecordingStore(recordings);
  final store = DeviceRecordingStore(
    recordings: recordings,
    downloader: createDownloader(),
    files: createRecordingFiles(),
    store: ref.read(keyValueStoreProvider),
    autoDownload: ref.read(settingsProvider).autoDownload,
    turnOffAutoDownload: () =>
        ref.read(settingsProvider.notifier).setAutoDownload(AutoDownload.off),
  );
  ref.listen(
    settingsProvider.select((s) => s.autoDownload),
    (_, v) => store.setAutoDownload(v),
  );
  ref.onDispose(store.dispose);
  unawaited(store.start());
  return store;
});
