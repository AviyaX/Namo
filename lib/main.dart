import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

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

void main() {
  _registerFontLicences();
  runApp(const ProviderScope(child: NamoApp()));
}
