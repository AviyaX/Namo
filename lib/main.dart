import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';
import 'storage/key_value_store.dart';

void _registerFontLicences() {
  const files = {
    'Noto Sans Sinhala': 'assets/fonts/OFL-NotoSansSinhala.txt',
    'Noto Serif': 'assets/fonts/OFL-NotoSerif.txt',
    'Lora': 'assets/fonts/OFL-Lora.txt',
  };
  LicenseRegistry.addLicense(() async* {
    for (final e in files.entries) {
      final text = await rootBundle.loadString(e.value);
      yield LicenseEntryWithLineBreaks([e.key], text);
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicences();
  // Chanting keeps playing with the app in the background or the screen
  // locked, with play/pause in the notification and on the lock screen.
  if (!kIsWeb) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'lk.namo.app.chanting',
      androidNotificationChannelName: 'Chanting',
      androidNotificationOngoing: true,
    );
  }
  final store = await openKeyValueStore();
  runApp(
    ProviderScope(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
      child: const NamoApp(),
    ),
  );
}
