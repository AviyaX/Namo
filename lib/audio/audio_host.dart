import 'audio_catalogue.dart';

/// The host the recordings are downloaded from.
const defaultAudioBaseUrl = 'https://namo-audio.v-g-a-induwara.workers.dev';

/// Sent with every request the app makes; no device or person detail.
const audioUserAgent = 'namo-app/1.0';

const _defined = String.fromEnvironment('NAMO_AUDIO_BASE_URL');

/// From --dart-define=NAMO_AUDIO_BASE_URL, else the default; never ends in '/'.
String get audioBaseUrl =>
    _stripTrailingSlashes(_defined.isEmpty ? defaultAudioBaseUrl : _defined);

/// The address of [r] on the host.
Uri recordingUrl(Recording r) => recordingUrlAt(audioBaseUrl, r);

/// The address of [r] under an explicit [baseUrl] (for tests and the tool).
Uri recordingUrlAt(String baseUrl, Recording r) {
  final path = r.path.replaceFirst(RegExp(r'^/+'), '');
  return Uri.parse('${_stripTrailingSlashes(baseUrl)}/$path');
}

String _stripTrailingSlashes(String s) => s.replaceFirst(RegExp(r'/+$'), '');
