import 'dart:convert';
import 'dart:io';

import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/audio/downloader.dart';
import 'package:buddhist_gatha/audio/platform/io_recording_files.dart';
import 'package:buddhist_gatha/audio/recording_location.dart';
import 'package:buddhist_gatha/audio/recording_store.dart';
import 'package:buddhist_gatha/audio/recording_store_device.dart';
import 'package:buddhist_gatha/settings/auto_download.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_downloader.dart';

String _sha(String s) => sha256.convert(utf8.encode(s)).toString();

final a = Recording(
  readingId: 'ra',
  path: 'audio/t/a.m4a',
  bytes: 6,
  sha256: _sha('abcdef'),
  label: 'A',
  placeholder: false,
);
final b = Recording(
  readingId: 'rb',
  path: 'audio/t/b.m4a',
  bytes: 3,
  sha256: _sha('xyz'),
  label: 'B',
  placeholder: false,
);

Uri _url(Recording r) => Uri.parse('https://host.test/${r.path}');

void main() {
  late Directory dir;
  late FakeDownloader fake;
  late InMemoryKeyValueStore kv;
  late int turnedOff;
  final made = <DeviceRecordingStore>[];

  setUp(() {
    dir = Directory.systemTemp.createTempSync('namo_store_');
    fake = FakeDownloader()..base = dir.path;
    kv = InMemoryKeyValueStore();
    turnedOff = 0;
  });

  tearDown(() async {
    for (final s in made) {
      await s.dispose();
    }
    made.clear();
    dir.deleteSync(recursive: true);
  });

  DeviceRecordingStore store({AutoDownload auto = AutoDownload.wifiOnly}) {
    final s = DeviceRecordingStore(
      recordings: [a, b],
      downloader: fake,
      files: IoRecordingFiles(),
      store: kv,
      autoDownload: auto,
      turnOffAutoDownload: () => turnedOff++,
      urlOf: _url,
    );
    made.add(s);
    return s;
  }

  File fileOf(Recording r) => File('${dir.path}/recordings/${r.path}');

  void write(Recording r, String content) => fileOf(r)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content);

  Map<String, dynamic> verified() =>
      jsonDecode(kv.read(verifiedKey) ?? '{}') as Map<String, dynamic>;

  RecordingStatus statusOf(DeviceRecordingStore s, Recording r) =>
      s.snapshot.value.of(r.readingId)!;

  Availability availabilityOf(DeviceRecordingStore s, Recording r) =>
      statusOf(s, r).availability;

  // Lets stream events and quick file work finish.
  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  // Waits for work that may hash on another isolate.
  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await settle();
  }

  DownloadRequest request(Recording r, String group, bool wifi) =>
      DownloadRequest(
        id: r.path,
        url: _url(r),
        directory: 'recordings/audio/t',
        filename: r.path.substring(r.path.lastIndexOf('/') + 1),
        group: group,
        requiresWiFi: wifi,
      );

  test('nothing on the device, Wi-Fi only: every recording is enqueued in '
      'auto with the Wi-Fi flag, in order', () async {
    final s = store();
    await s.start();
    expect(fake.enqueued.map((r) => r.id), ['audio/t/a.m4a', 'audio/t/b.m4a']);
    expect(fake.enqueued.every((r) => r.group == autoGroup), isTrue);
    expect(fake.enqueued.every((r) => r.requiresWiFi), isTrue);
    expect(fake.enqueued.first.directory, 'recordings/audio/t');
    expect(fake.enqueued.first.filename, 'a.m4a');
    expect(fake.enqueued.first.url, _url(a));
    expect(availabilityOf(s, a), Availability.waiting);
    expect(availabilityOf(s, b), Availability.waiting);
  });

  test('any connection enqueues without the Wi-Fi flag', () async {
    final s = store(auto: AutoDownload.any);
    await s.start();
    expect(fake.enqueued, [
      request(a, autoGroup, false),
      request(b, autoGroup, false),
    ]);
  });

  test('off enqueues nothing and reads notDownloaded', () async {
    final s = store(auto: AutoDownload.off);
    await s.start();
    expect(fake.enqueued, isEmpty);
    expect(availabilityOf(s, a), Availability.notDownloaded);
    expect(availabilityOf(s, b), Availability.notDownloaded);
    expect(s.locationFor(a), isNull);
  });

  test('a file of the right size that is not yet verified is hashed and '
      'counts as downloaded', () async {
    write(a, 'abcdef');
    final s = store();
    await s.start();
    expect(availabilityOf(s, a), Availability.downloaded);
    expect(verified(), {a.path: a.sha256});
    expect(availabilityOf(s, b), Availability.waiting);
    expect(fake.enqueued, [request(b, autoGroup, true)]);
  });

  test('off with files present still plays them', () async {
    write(a, 'abcdef');
    final s = store(auto: AutoDownload.off);
    await s.start();
    expect(s.locationFor(a), FileLocation('${dir.path}/recordings/${a.path}'));
    expect(s.locationFor(b), isNull);
    expect(fake.enqueued, isEmpty);
  });

  test('a verified file whose content hash changed is deleted and fetched '
      'again', () async {
    write(a, 'abcdeX');
    await kv.write(verifiedKey, jsonEncode({a.path: _sha('abcdeX')}));
    final s = store();
    await s.start();
    expect(fileOf(a).existsSync(), isFalse);
    expect(fake.enqueued.first, request(a, autoGroup, true));
    expect(availabilityOf(s, a), Availability.waiting);
    expect(verified().containsKey(a.path), isFalse);
  });

  test('a file of the wrong size is deleted and fetched again', () async {
    write(a, 'abc');
    final s = store();
    await s.start();
    expect(fileOf(a).existsSync(), isFalse);
    expect(fake.enqueued.first, request(a, autoGroup, true));
  });

  test('an active task found at start reads waiting and is not enqueued '
      'twice', () async {
    fake.preExisting = [request(a, manualGroup, false)];
    final s = store();
    await s.start();
    expect(availabilityOf(s, a), Availability.waiting);
    expect(fake.enqueued, [request(b, autoGroup, true)]);
  });

  test('running and progress events show downloading with progress', () async {
    final s = store();
    await s.start();
    fake.emit(DownloadStatusEvent(a.path, DownloadStatus.running));
    fake.emit(DownloadProgressEvent(a.path, 0.42));
    await settle();
    expect(availabilityOf(s, a), Availability.downloading);
    expect(statusOf(s, a).progress, 0.42);
    expect(s.snapshot.value.bytesDownloaded, 3); // 0.42 × 6 = 2.52 rounds to 3
    expect(s.snapshot.value.anyDownloading, isTrue);
  });

  test(
    'a completed download that verifies is downloaded and remembered',
    () async {
      final s = store();
      await s.start();
      write(a, 'abcdef');
      fake.finish(a.path);
      await until(() => availabilityOf(s, a) == Availability.downloaded);
      expect(availabilityOf(s, a), Availability.downloaded);
      expect(
        s.locationFor(a),
        FileLocation('${dir.path}/recordings/${a.path}'),
      );
      expect(verified(), {a.path: a.sha256});
    },
  );

  test(
    'a damaged download is deleted, marked failed and fetched again once',
    () async {
      final s = store();
      await s.start();
      write(a, 'abcdeX');
      fake.finish(a.path);
      await until(() => availabilityOf(s, a) == Availability.failed);
      expect(statusOf(s, a).reason, damagedMessage);
      expect(fileOf(a).existsSync(), isFalse);
      expect(fake.enqueued.where((r) => r.id == a.path), [
        request(a, autoGroup, true),
        request(a, autoGroup, true),
      ]);

      fake.emit(DownloadStatusEvent(a.path, DownloadStatus.running));
      await until(() => availabilityOf(s, a) == Availability.downloading);
      write(a, 'abcdeX');
      fake.finish(a.path);
      await until(() => availabilityOf(s, a) == Availability.failed);
      expect(statusOf(s, a).reason, damagedMessage);
      expect(fileOf(a).existsSync(), isFalse);
      expect(fake.enqueued.where((r) => r.id == a.path), hasLength(2));
    },
  );

  test('notFound and failed carry their messages', () async {
    final s = store();
    await s.start();
    fake.emit(DownloadStatusEvent(a.path, DownloadStatus.notFound));
    fake.emit(DownloadStatusEvent(b.path, DownloadStatus.failed));
    await settle();
    expect(availabilityOf(s, a), Availability.failed);
    expect(statusOf(s, a).reason, notOnServerMessage);
    expect(availabilityOf(s, b), Availability.failed);
    expect(statusOf(s, b).reason, connectionMessage);
  });

  test('download(r) moves an automatic task to the manual group with no '
      'Wi-Fi flag', () async {
    final s = store();
    await s.start();
    await s.download(a);
    await settle();
    expect(fake.cancelledGroups, isEmpty);
    expect(fake.cancelledIds, [a.path]);
    expect(
      fake.live,
      unorderedEquals([
        request(b, autoGroup, true),
        request(a, manualGroup, false),
      ]),
    );
    expect(availabilityOf(s, a), Availability.waiting);
    expect(availabilityOf(s, b), Availability.waiting);

    await s.download(a);
    await settle();
    expect(fake.enqueued, hasLength(3)); // already in manual: nothing more
    expect(fake.cancelledIds, [a.path]);
  });

  test(
    'download(r) on a recording already downloading leaves it alone',
    () async {
      final s = store();
      await s.start();
      fake.emit(DownloadStatusEvent(a.path, DownloadStatus.running));
      fake.emit(DownloadProgressEvent(a.path, 0.9));
      await settle();
      await s.download(a);
      await settle();
      expect(fake.cancelledIds, isEmpty);
      expect(fake.cancelledGroups, isEmpty);
      expect(fake.enqueued, hasLength(2));
      expect(availabilityOf(s, a), Availability.downloading);
      expect(statusOf(s, a).progress, 0.9);
    },
  );

  test('downloadAll moves waiting automatic tasks to manual and leaves a '
      'running one alone', () async {
    final s = store();
    await s.start();
    fake.emit(DownloadStatusEvent(a.path, DownloadStatus.running));
    fake.emit(DownloadProgressEvent(a.path, 0.5));
    await settle();
    await s.downloadAll();
    await settle();
    expect(fake.cancelledGroups, isEmpty);
    expect(fake.cancelledIds, [b.path]);
    expect(
      fake.live,
      unorderedEquals([
        request(a, autoGroup, true),
        request(b, manualGroup, false),
      ]),
    );
    expect(availabilityOf(s, a), Availability.downloading);
    expect(statusOf(s, a).progress, 0.5);
    expect(availabilityOf(s, b), Availability.waiting);
  });

  test('downloadAll enqueues every missing recording in manual', () async {
    write(b, 'xyz');
    final s = store(auto: AutoDownload.off);
    await s.start();
    await s.downloadAll();
    await settle();
    expect(fake.live, [request(a, manualGroup, false)]);
    expect(availabilityOf(s, a), Availability.waiting);
    expect(availabilityOf(s, b), Availability.downloaded);
  });

  test('changing the setting re-enqueues the automatic queue with the new '
      'flag and leaves manual alone', () async {
    final s = store();
    await s.start();
    await s.download(a);
    await settle();

    s.setAutoDownload(AutoDownload.any);
    await settle();
    expect(
      fake.live,
      unorderedEquals([
        request(a, manualGroup, false),
        request(b, autoGroup, false),
      ]),
    );
    expect(availabilityOf(s, b), Availability.waiting);

    s.setAutoDownload(AutoDownload.off);
    await settle();
    expect(fake.live, [request(a, manualGroup, false)]);
    expect(availabilityOf(s, a), Availability.waiting);
    expect(availabilityOf(s, b), Availability.notDownloaded);
  });

  test('removeAll turns the setting off first, cancels everything and deletes '
      'the files', () async {
    write(a, 'abcdef');
    final s = store();
    await s.start();
    expect(availabilityOf(s, a), Availability.downloaded);

    await s.removeAll();
    await settle();
    expect(turnedOff, 1);
    expect(fake.cancelledGroups, containsAll([autoGroup, manualGroup]));
    expect(fake.live, isEmpty);
    expect(fileOf(a).existsSync(), isFalse);
    expect(verified(), isEmpty);
    expect(availabilityOf(s, a), Availability.notDownloaded);
    expect(availabilityOf(s, b), Availability.notDownloaded);
    expect(s.locationFor(a), isNull);
  });

  test('a downloader that cannot start leaves every recording notDownloaded '
      'without throwing', () async {
    fake.failToStart = true;
    write(a, 'abcdef');
    final s = store();
    await s.start();
    expect(availabilityOf(s, a), Availability.notDownloaded);
    expect(availabilityOf(s, b), Availability.notDownloaded);
    expect(s.locationFor(a), isNull);
    expect(fake.enqueued, isEmpty);
  });

  test('an event for an unknown id is ignored', () async {
    final s = store();
    await s.start();
    final before = s.snapshot.value;
    var changes = 0;
    s.snapshot.addListener(() => changes++);
    fake.emit(
      const DownloadStatusEvent('audio/t/z.m4a', DownloadStatus.failed),
    );
    fake.emit(const DownloadProgressEvent('audio/t/z.m4a', 0.5));
    await settle();
    expect(changes, 0);
    expect(s.snapshot.value, before);
  });

  test('the snapshot emits only when something changed', () async {
    final s = store();
    await s.start();
    var changes = 0;
    s.snapshot.addListener(() => changes++);
    fake.emit(DownloadStatusEvent(a.path, DownloadStatus.enqueued));
    await settle();
    expect(changes, 0); // already waiting
    fake.emit(DownloadStatusEvent(a.path, DownloadStatus.running));
    await settle();
    expect(changes, 1);
  });

  test('the snapshot counts', () async {
    write(a, 'abcdef');
    final s = store();
    await s.start();
    final snap = s.snapshot.value;
    expect(snap.total, 2);
    expect(snap.downloaded, 1);
    expect(snap.active, 1);
    expect(snap.failed, 0);
    expect(snap.bytesTotal, 9);
    expect(snap.bytesDownloaded, 6);
    expect(snap.allDownloaded, isFalse);

    write(b, 'xyz');
    fake.finish(b.path);
    await until(() => s.snapshot.value.allDownloaded);
    expect(s.snapshot.value.allDownloaded, isTrue);
    expect(s.snapshot.value.bytesDownloaded, 9);
  });

  test('the placeholder tone is always an asset', () async {
    const tone = Recording(
      readingId: 'rz',
      path: placeholderToneAsset,
      label: placeholderToneLabel,
      placeholder: true,
    );
    final s = store(auto: AutoDownload.off);
    expect(s.locationFor(tone), const AssetLocation(placeholderToneAsset));
    await s.start();
    expect(s.locationFor(tone), const AssetLocation(placeholderToneAsset));
    expect(
      WebRecordingStore([a]).locationFor(tone),
      const AssetLocation(placeholderToneAsset),
    );
    expect(
      EmptyRecordingStore().locationFor(tone),
      const AssetLocation(placeholderToneAsset),
    );
  });

  test('WebRecordingStore gives the URL for every recording', () async {
    final s = WebRecordingStore([a, b], urlOf: _url);
    expect(s.locationFor(a), UrlLocation(_url(a)));
    expect(s.locationFor(b), UrlLocation(_url(b)));
    expect(s.snapshot.value.total, 2);
    expect(s.snapshot.value.allDownloaded, isTrue);
    expect(s.snapshot.value.of('ra')!.availability, Availability.downloaded);
    await s.download(a);
    await s.downloadAll();
    await s.removeAll();
    expect(s.snapshot.value.allDownloaded, isTrue);
  });

  test('EmptyRecordingStore has nothing', () async {
    final s = EmptyRecordingStore();
    expect(s.snapshot.value, RecordingsSnapshot.empty);
    expect(s.snapshot.value.total, 0);
    expect(s.snapshot.value.allDownloaded, isFalse);
    expect(s.locationFor(a), isNull);
    await s.download(a);
    await s.downloadAll();
    await s.removeAll();
    expect(s.snapshot.value, RecordingsSnapshot.empty);
  });
}
