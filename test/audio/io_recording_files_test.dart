import 'dart:convert';
import 'dart:io';

import 'package:buddhist_gatha/audio/platform/io_recording_files.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late IoRecordingFiles files;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('namo_files_');
    files = IoRecordingFiles();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('sizeOf gives the byte count, or null for a missing file', () async {
    final f = File('${dir.path}/a.bin')..writeAsStringSync('abcdef');
    expect(await files.sizeOf(f.path), 6);
    expect(await files.sizeOf('${dir.path}/missing.bin'), isNull);
  });

  test('sha256Of matches the crypto package', () async {
    final f = File('${dir.path}/a.bin')..writeAsStringSync('abcdef');
    expect(
      await files.sha256Of(f.path),
      sha256.convert(utf8.encode('abcdef')).toString(),
    );
  });

  test('delete removes a file and ignores a missing one', () async {
    final f = File('${dir.path}/a.bin')..writeAsStringSync('abcdef');
    await files.delete(f.path);
    expect(f.existsSync(), isFalse);
    await files.delete(f.path);
  });
}
