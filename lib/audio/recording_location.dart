/// Where the player finds a recording's sound.
sealed class RecordingLocation {
  const RecordingLocation();
}

/// A file bundled with the app.
class AssetLocation extends RecordingLocation {
  const AssetLocation(this.asset);
  final String asset;

  @override
  bool operator ==(Object other) =>
      other is AssetLocation && other.asset == asset;

  @override
  int get hashCode => Object.hash(AssetLocation, asset);

  @override
  String toString() => 'AssetLocation($asset)';
}

/// A downloaded file on the device.
class FileLocation extends RecordingLocation {
  const FileLocation(this.path);
  final String path;

  @override
  bool operator ==(Object other) => other is FileLocation && other.path == path;

  @override
  int get hashCode => Object.hash(FileLocation, path);

  @override
  String toString() => 'FileLocation($path)';
}

/// A recording streamed from the host.
class UrlLocation extends RecordingLocation {
  const UrlLocation(this.url);
  final Uri url;

  @override
  bool operator ==(Object other) => other is UrlLocation && other.url == url;

  @override
  int get hashCode => Object.hash(UrlLocation, url);

  @override
  String toString() => 'UrlLocation($url)';
}
