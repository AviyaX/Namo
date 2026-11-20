/// The few file operations the recording store needs.
abstract interface class RecordingFiles {
  /// Size in bytes, or null when the file is missing.
  Future<int?> sizeOf(String path);

  /// Lower-case hex SHA-256, computed off the main thread.
  Future<String> sha256Of(String path);

  /// Removes the file; nothing happens when it is missing.
  Future<void> delete(String path);
}
