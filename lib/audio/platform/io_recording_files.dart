import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../recording_files.dart';

/// [RecordingFiles] on real files.
class IoRecordingFiles implements RecordingFiles {
  IoRecordingFiles({this.inBackground = true});

  /// Hash on a background isolate; tests may turn this off.
  final bool inBackground;

  @override
  Future<int?> sizeOf(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    return file.length();
  }

  @override
  Future<String> sha256Of(String path) =>
      inBackground ? compute(_hashFile, path) : _hashFile(path);

  @override
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}

Future<String> _hashFile(String path) async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
}
