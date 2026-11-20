# Hosted Recordings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the 40 chant recordings (102.5 MB) out of the app bundle onto the owner's Cloudflare R2 bucket, download them quietly after install, verify each by size and SHA-256, and play them from the device exactly as today.

**Architecture:** The content JSON names each recording by a host-relative `path` with `bytes` and `sha256`; the files move to a repo folder `hosted/` that mirrors the bucket, with a Python sync tool to check, upload and verify it. In the app a `RecordingStore` (device: `background_downloader` behind a thin `Downloader` interface, verification through a `RecordingFiles` interface; web: everything streams from its URL) tells the player where a recording is and tells the reader and Settings what has arrived. A new `autoDownload` setting (Wi-Fi only / Any connection / Off) drives the automatic queue.

**Tech Stack:** Flutter 3.47.9 / Dart 3.13.7, Riverpod 3, `just_audio` ^0.10.6 (asset, file and URL sources), `background_downloader` ^9.6.6, `crypto` ^3.0.8, Python 3 standard library for the tools.

**Spec:** `docs/superpowers/specs/2026-11-15-hosted-recordings-design.md`

## Global Constraints

- Android, iOS and web from one code base; nothing may break the web build (`flutter build web --no-web-resources-cdn`). iOS is not built here; say so in reports.
- Recordings are never re-encoded, renamed or replaced under the same name; `git mv` only, byte for byte. Pirith licence CC BY-ND 4.0; Samantha Pattana permission pending. The bucket going public is the owner's step (release checklist), not the build's.
- Host: base URL `https://audio.intendable.us`, bucket `namo-audio`, object keys `audio/pirith/<id>.m4a` (39) and `audio/samantha_patthana/hYXyO3o7Iac.m4a` (1). Override for development: `--dart-define=NAMO_AUDIO_BASE_URL=<url>`.
- Upload headers: `Content-Type: audio/mp4`, `Cache-Control: public, max-age=31536000, immutable`. Tool User-Agent: `namo-app-build/1.0`. No personal detail in any request.
- Content reaches the app only through `tools/`; every `--check` keeps passing: `python -I -X utf8 tools/build_content.py . --check`, `tools/build_pirith.py . --check`, `tools/build_samantha_patthana.py . --check`, `tools/sync_tipitaka.py . --check`, and the new `tools/sync_hosted_audio.py . --check`. `python -I -X utf8 tools/check_ui_glyphs.py .` exits 0.
- Design rules (`test/quality/design_rules_test.dart`): no raw colours outside `lib/design/tokens.dart`; `textMuted` only inside `lib/design/`; no Material default widgets (`Card(`, `ElevatedButton`, `ListTile(`, …); type via `NamoType`; any new `Duration(milliseconds:` outside `tokens.dart` needs the allow-list, so use `NamoMotion` or none.
- Existing keys stay: `reader-autoscroll`, `chant-play`, `chant-restart`, `chant-slider`, `chant-speed`, `reader-prev`, `reader-next`, `audio-play`, `audio-restart`.
- The Tripitaka (`lib/tipitaka/`) is untouched. No ads, payments, analytics, telemetry or identifiers.
- Test suite: `flutter test` (2467 passing at the base), `flutter analyze` clean. Flutter is at `C:\Users\Dell\develop\flutter\bin\flutter` (Git Bash: `/c/Users/Dell/develop/flutter/bin/flutter`), not on PATH. Python tool tests: `python -I -X utf8 tools/test_<name>.py`.
- Git: never `git add -A`; name the files. Commit author is the project identity already configured in the worktree. Commit trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Sizes shown to people are decimal megabytes: `formatSize(bytes)` gives one decimal under 10 MB ("1.0 MB") and a whole number from 10 MB ("46 MB"); the full set is 102,523,878 bytes → "103 MB".
- Copy (verbatim, from the spec): see each task. Characters `…`, `·`, `–`, `×` are already used in `lib/` and pass the glyph check.

## Review Focus

1. **The downloader cannot start** (plugin missing, no permission, broken platform channel): the texts and the reader must still work; every recording simply reads *not downloaded* with no reason, and nothing throws into the widget tree. Test in Task 5 (`start() throws → statuses notDownloaded, no exception`).
2. **Setting Off with files already on the device**: they must still play (*downloaded*) and nothing is enqueued. Test in Task 5.
3. **A base URL with a trailing slash or an empty dart-define**: `recordingUrl` must give exactly one slash between host and path, and an empty value falls back to the default host. Test in Task 4.
4. **The content's `sha256` for a path changes** (the forbidden "new file, same name" case, or a corrected checksum): a file verified under the old hash is deleted and fetched afresh, never played. Test in Task 5.
5. **Play tapped while waiting, then the reader is left** before the file arrives: when the download completes nothing plays, nothing throws (the reader is disposed). Test in Task 7.

---

### Task 1: Recordings leave the bundle (content, tools, model)

The files move to `hosted/`, both build tools write `path`/`bytes`/`sha256`, both content files are regenerated, `pubspec.yaml` stops bundling them, and the Dart model reads the new keys. After this task the real app cannot play a recording until Task 6; tests use fakes and stay green.

**Files:**
- Move (git mv): `assets/audio/pirith/` → `hosted/audio/pirith/`; `assets/audio/samantha_patthana/` → `hosted/audio/samantha_patthana/`
- Modify: `tools/build_pirith.py` (lines 5, 8-9, 22, 84, 92, 160-181), `tools/test_build_pirith.py` (34-54, 96-104, 135-144, 198-203)
- Modify: `tools/build_samantha_patthana.py` (7, 25, 221-233, 311-323), `tools/test_build_samantha_patthana.py` (256-270, 328-422)
- Regenerate: `assets/content/pirith.json`, `assets/content/samantha_patthana.json`
- Modify: `pubspec.yaml` (remove lines 113 and 115), `.gitignore` (comments on lines 50 and 53)
- Modify: `lib/content/model.dart` (`RecordingInfo`, 204-248), `lib/audio/audio_catalogue.dart` (`Recording`, 8-40; `ContentAudioCatalogue`, 49-70; `DevPlaceholderCatalogue`, 77-91), `lib/audio/chant_player.dart:132`
- Modify tests: `test/content/model_test.dart`, `test/content/pirith_content_test.dart:87`, `test/content/samantha_patthana_content_test.dart:133`, `test/quality/pirith_assets_test.dart`, `test/quality/samantha_patthana_assets_test.dart` (`_known['audio']`, 51-59; bundle test 97-111), `test/audio/audio_catalogue_test.dart`, `test/audio/reader_audio_test.dart`, `test/design/icons_test.dart`, `test/reader/reader_awake_test.dart`, `test/reader/reader_items_test.dart`, `test/flows/flow_reading_test.dart`, `test/quality/quality_support.dart:132`

**Interfaces:**
- Produces (Dart):
  ```dart
  // lib/content/model.dart
  class RecordingInfo {
    const RecordingInfo({required this.path, this.bytes = 0, this.sha256 = '', required this.label,
        this.sectionCues = const {}, this.blockTimes = const [], this.lineTimes = const [], this.duration});
    final String path;    // host-relative, e.g. 'audio/pirith/08-mahamangala.m4a'
    final int bytes;      // 0 when the content does not say
    final String sha256;  // lower-case hex, '' when the content does not say
    // label, sectionCues, blockTimes, lineTimes, duration unchanged
  }
  // lib/audio/audio_catalogue.dart
  class Recording {
    const Recording({required this.readingId, required this.path, this.bytes = 0, this.sha256 = '',
        required this.label, required this.placeholder,
        this.sectionCues = const {}, this.blockTimes = const [], this.lineTimes = const []});
    final String path;    // host-relative for real recordings; the asset path for the placeholder tone
    final int bytes;
    final String sha256;
  }
  ```
- Produces (JSON): each `audio` object has `path` (string, starts `audio/`), `bytes` (int), `sha256` (64 hex), `label`, `duration_ms`, `block_times`, and for Samantha Pattana `line_times`. No `asset` key anywhere.
- Produces (tools): `build_pirith.AUDIO_DIR == pathlib.Path("hosted/audio/pirith")`, `build_samantha_patthana.AUDIO_DIR == pathlib.Path("hosted/audio/samantha_patthana")`; both `_check`s hash `root / "hosted" / audio["path"]`.

- [ ] **Step 1: Move the files**

```bash
mkdir -p hosted/audio
git mv assets/audio/pirith hosted/audio/pirith
git mv assets/audio/samantha_patthana hosted/audio/samantha_patthana
ls hosted/audio/pirith | wc -l   # 39
ls assets/audio                  # nothing left (assets/audio_dev/ is untouched)
```

- [ ] **Step 2: Update the pirith tool tests to the new layout and key**

In `tools/test_build_pirith.py`: `tree()` writes the fake recordings under `root / "hosted" / "audio" / "pirith"`; `test_block_times` asserts `audio["path"] == "audio/pirith/05-a.m4a"` (the id the helper uses) and that `"asset" not in audio`, keeping the `bytes`/`sha256` assertions; `test_check_names_changed_recording` edits `hosted/audio/pirith/05-a.m4a`; `RealDataTest.test_recordings_are_the_originals` reads `ROOT / "hosted" / a["path"]` and asserts `a["path"].startswith("audio/pirith/")`.

- [ ] **Step 3: Run them to see them fail**

Run: `python -I -X utf8 tools/test_build_pirith.py`
Expected: FAIL (KeyError `'path'` / files not found under `hosted/`).

- [ ] **Step 4: Change `tools/build_pirith.py`**

`AUDIO_DIR = pathlib.Path("hosted/audio/pirith")`; in `_reading()` the audio object gets `"path": f"audio/pirith/{item['id']}.m4a"` in place of `"asset"`; `_check` hashes `root / "hosted" / a["path"]`; docstring line 5 and the usage say `hosted/audio/pirith/`. Nothing else changes (sizes and hashes are still computed from the local file).

- [ ] **Step 5: Run the pirith tool tests**

Run: `python -I -X utf8 tools/test_build_pirith.py`
Expected: PASS.

- [ ] **Step 6: Same for Samantha Pattana**

`tools/test_build_samantha_patthana.py`: `test_audio_times` asserts `audio["path"] == "audio/samantha_patthana/hYXyO3o7Iac.m4a"` and `"asset" not in audio`; `CheckAndImportTest` builds its fake tree under `hosted/audio/samantha_patthana/` (follow the existing helper). Run → FAIL. Then `tools/build_samantha_patthana.py`: `AUDIO_DIR = pathlib.Path("hosted/audio/samantha_patthana")`, `_audio()` returns `"path": f"audio/samantha_patthana/{RECORDING}"` in place of `"asset"`, `_check` keeps hashing `root / AUDIO_DIR / RECORDING` (the directory moved with the constant), docstring line 7 updated. Run → PASS.

- [ ] **Step 7: Regenerate the content and check it**

```bash
python -I -X utf8 tools/build_pirith.py .
python -I -X utf8 tools/build_samantha_patthana.py .
python -I -X utf8 tools/build_pirith.py . --check
python -I -X utf8 tools/build_samantha_patthana.py . --check
python -I -X utf8 tools/build_content.py . --check
grep -c '"asset"' assets/content/*.json   # 0 for every file
grep -c '"path"' assets/content/pirith.json   # 39
```

- [ ] **Step 8: Stop bundling the recordings**

`pubspec.yaml`: delete the two lines `- assets/audio/pirith/` and `- assets/audio/samantha_patthana/`; keep `- assets/audio_dev/placeholder_tone_not_a_chant.wav`. `.gitignore`: the two comments now say the copies that ship live in `hosted/audio/pirith/` and `hosted/audio/samantha_patthana/`.

- [ ] **Step 9: Write the failing Dart tests**

`test/content/model_test.dart`: in `'Reading.fromJson with audio'` the JSON uses `'path': 'a.m4a', 'bytes': 6, 'sha256': 'abc'` and asserts `a.path == 'a.m4a'`, `a.bytes == 6`, `a.sha256 == 'abc'`; add `'a recording without bytes or sha256 reads 0 and empty'`.

`test/quality/pirith_assets_test.dart` becomes three tests over the real library and `AssetManifest`: `'nothing under assets/audio/ is bundled'` (no manifest key starts with `assets/audio/`), `'the development tone is still bundled'` (`assets/audio_dev/placeholder_tone_not_a_chant.wav` is in the manifest), `'every pirith recording names a hosted file with its size and checksum'` (39 readings; each `audio!.path` starts `audio/pirith/` and ends `.m4a`, `bytes > 0`, `sha256` matches `RegExp(r'^[0-9a-f]{64}$')`, the 39 paths are distinct).

`test/quality/samantha_patthana_assets_test.dart`: `_known['audio']` lists `path` instead of `asset`; the bundle test asserts no manifest key starts with `assets/audio/samantha_patthana/` and `vandana.audio!.path == 'audio/samantha_patthana/hYXyO3o7Iac.m4a'` with `bytes == 46219957`.

`test/content/pirith_content_test.dart:87`: `rec.path == 'audio/pirith/08-mahamangala.m4a'`. `test/content/samantha_patthana_content_test.dart:133`: `audio.path == 'audio/samantha_patthana/hYXyO3o7Iac.m4a'`.

Every other `asset:` named argument in the test files listed above becomes `path:` (same string values; the placeholder test at `audio_catalogue_test.dart:128` expects `rec.path == placeholderToneAsset`).

- [ ] **Step 10: Run them to see them fail**

Run: `flutter test test/content test/quality/pirith_assets_test.dart test/quality/samantha_patthana_assets_test.dart test/audio`
Expected: compile errors (`path` undefined) — that counts as failing.

- [ ] **Step 11: Change the model and the catalogue**

`RecordingInfo` as in Interfaces; `fromJson`: `path: json['path'] as String`, `bytes: (json['bytes'] as num?)?.toInt() ?? 0`, `sha256: json['sha256'] as String? ?? ''`. `Recording` as in Interfaces; doc comment on `path`: "Where the recording lives on the host (`audio/...`), or the asset path of the placeholder tone." `ContentAudioCatalogue` passes `path`, `bytes`, `sha256` from `reading.audio!`; `DevPlaceholderCatalogue` builds `Recording(path: placeholderToneAsset, placeholder: true, ...)`. `chant_player.dart:132`: `_player.setAsset(r.path)` (a stop-gap; Task 6 replaces it). `quality_support.dart:132` `PlaceholderCatalogue` likewise.

- [ ] **Step 12: Run the whole suite and the analyzer**

Run: `flutter test` and `flutter analyze`
Expected: all pass (count unchanged or higher), no issues.

- [ ] **Step 13: Commit**

```bash
git add hosted assets/audio assets/content/pirith.json assets/content/samantha_patthana.json pubspec.yaml .gitignore tools/build_pirith.py tools/test_build_pirith.py tools/build_samantha_patthana.py tools/test_build_samantha_patthana.py lib/content/model.dart lib/audio/audio_catalogue.dart lib/audio/chant_player.dart test/content test/quality/pirith_assets_test.dart test/quality/samantha_patthana_assets_test.dart test/quality/quality_support.dart test/audio test/design/icons_test.dart test/reader/reader_awake_test.dart test/reader/reader_items_test.dart test/flows/flow_reading_test.dart
git commit -m "Recordings move to hosted/: content names a path, size and checksum"
```

---

### Task 2: The `autoDownload` setting

**Files:**
- Create: `lib/settings/auto_download.dart`
- Modify: `lib/settings/settings.dart` (constructor 14-23, fields 50-57, `copyWith` 66-85, `toJson` 87-96, `fromJson` 100-123, controller 126-184)
- Test: `test/settings/settings_test.dart`

**Interfaces:**
- Produces:
  ```dart
  // lib/settings/auto_download.dart
  enum AutoDownload {
    wifiOnly('Wi-Fi only'),
    any('Any connection'),
    off('Off');
    const AutoDownload(this.label);
    final String label;
  }
  // lib/settings/settings.dart
  final AutoDownload autoDownload;                 // default AutoDownload.wifiOnly, JSON key 'autoDownload' (.name)
  void setAutoDownload(AutoDownload v);            // on SettingsController
  ```

- [ ] **Step 1: Write the failing tests**

In `test/settings/settings_test.dart`, following `'defaults'`, `'settings survive a round trip through the store'` and `'an unknown layout or theme name falls back alone'`:

```dart
test('auto download defaults to Wi-Fi only', () {
  expect(const AppSettings().autoDownload, AutoDownload.wifiOnly);
});
test('auto download is saved by name and read back', () {
  final store = InMemoryKeyValueStore();
  final c = containerOn(store);
  c.read(settingsProvider.notifier).setAutoDownload(AutoDownload.off);
  expect((jsonDecode(store.read(settingsKey)!) as Map)['autoDownload'], 'off');
  expect(containerOn(store).read(settingsProvider).autoDownload, AutoDownload.off);
});
test('an unknown auto download value falls back alone', () {
  final s = AppSettings.fromJson({'autoDownload': 'sometimes', 'fontScale': 1.2});
  expect(s.autoDownload, AutoDownload.wifiOnly);
  expect(s.fontScale, 1.2);
});
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/settings/settings_test.dart`
Expected: compile error (`autoDownload` undefined).

- [ ] **Step 3: Implement**

Create the enum file. In `AppSettings`: constructor default `this.autoDownload = AutoDownload.wifiOnly`, field, `copyWith` parameter, `toJson` entry `'autoDownload': autoDownload.name`, `fromJson` entry `autoDownload: AutoDownload.values.asNameMap()[json['autoDownload']] ?? d.autoDownload` (the `layout` pattern). Controller: `void setAutoDownload(AutoDownload v) => _set(state.copyWith(autoDownload: v));`.

- [ ] **Step 4: Run the settings tests**

Run: `flutter test test/settings`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/settings/auto_download.dart lib/settings/settings.dart test/settings/settings_test.dart
git commit -m "Settings: autoDownload (Wi-Fi only, any connection, off)"
```

---

### Task 3: The sync tool, `hosted/README.md` and the README

**Files:**
- Create: `tools/sync_hosted_audio.py`, `tools/test_sync_hosted_audio.py`, `hosted/README.md`
- Modify: `README.md` (lines 3-4, 36-43, 47-55, 79-83)

**Interfaces:**
- Produces (Python, `tools/sync_hosted_audio.py`, standard library only, no argparse — the other tools read `sys.argv` by hand):
  ```python
  BASE_URL = "https://audio.intendable.us"
  BUCKET = "namo-audio"
  USER_AGENT = "namo-app-build/1.0"
  CONTENT_TYPE = "audio/mp4"
  CACHE_CONTROL = "public, max-age=31536000, immutable"
  HOSTED = pathlib.Path("hosted")
  CONTENT = pathlib.Path("assets/content")
  ALLOWED_EXTRA = {"README.md"}          # the only non-recording file allowed under hosted/

  class SyncError(Exception): ...
  def recordings(root: pathlib.Path) -> list[dict]      # [{"path", "bytes", "sha256", "reading"}] in content-file order; SyncError when a key is missing or sha256 is not 64 hex
  def check(root) -> str | None                          # None when everything is right, else the first problem
  def plan(root) -> list[list[str]]                      # one argv list per recording
  def upload(root, run=subprocess.run) -> None           # runs plan(); SyncError when npx is missing
  def verify(root, base_url, opener=urllib.request.urlopen) -> list[str]        # HEAD each URL
  def verify_full(root, base_url, opener=urllib.request.urlopen) -> list[str]   # GET each into a fresh temp dir, hash
  def main(argv: list[str]) -> int
  ```
  CLI: `python -I -X utf8 tools/sync_hosted_audio.py <project_root> [--check | --plan | --upload | --verify [--base-url URL] | --verify-full [--base-url URL]]`. Exit 0 on success, 1 on a problem, 2 on bad usage.
  Messages: check success `hosted audio is up to date`; problems `missing: hosted/<path>`, `<path> is <n> bytes, expected <bytes>`, `<path> has checksum <sha>, expected <sha256>`, `unexpected file in hosted/: <relative path>`; verify success `all <N> recordings verified at <base_url>`; verify problems `<url>: HTTP <code>`, `<url>: Content-Length <n>, expected <bytes>`, `<url>: Content-Type <ct>, expected audio/mp4`, `<url>: checksum <sha>, expected <sha256>`; missing npx `npx was not found; install Node.js and run "npx wrangler login" once`.
  Plan command per file: `["npx", "wrangler", "r2", "object", "put", f"{BUCKET}/{path}", "--file", f"hosted/{path}", "--content-type", CONTENT_TYPE, "--cache-control", CACHE_CONTROL, "--remote"]`; `--plan` prints each as one shell-quoted line (`shlex.join`). `upload` resolves `npx` with `shutil.which` (on Windows that is `npx.cmd`) and runs each command with `check=True`.
  HTTP: every request carries `User-Agent: namo-app-build/1.0`; `verify_full` writes into `tempfile.mkdtemp()` and hashes while streaming (64 KiB chunks), deleting the directory afterwards; both verifiers go on past a failing file and return every problem.

- [ ] **Step 1: Write the failing tests**

`tools/test_sync_hosted_audio.py` (unittest, no network). Build a made-up root in `tempfile.TemporaryDirectory()` with `assets/content/x.json` holding `{"schema": 1, "categories": [{"id": "c", "readings": [{"id": "r1", "audio": {"path": "audio/t/a.m4a", "bytes": 6, "sha256": sha256(b"abcdef")}}, {"id": "r2", "audio": None}]}]}` and the file `hosted/audio/t/a.m4a` = `b"abcdef"`. Tests:

- `test_recordings_lists_in_order` (one entry, reading `r1`), `test_recordings_rejects_bad_sha` (`SyncError`).
- `test_check_passes`, `test_check_missing_file`, `test_check_wrong_size`, `test_check_wrong_checksum`, `test_check_extra_file` (`hosted/stray.txt` → problem names it), `test_check_allows_readme` (`hosted/README.md` is fine).
- `test_plan_command_has_headers`: the single argv list equals the exact list above with `audio/t/a.m4a`.
- `test_upload_runs_each_command`: a fake `run` records calls; one call, first element ends with `npx` or `npx.cmd`; `test_upload_without_npx` patches `shutil.which` to return `None` → `SyncError`.
- `test_verify_head_ok` and `test_verify_reports_length_type_and_status`: a fake opener returns an object with `.headers` (a `dict`-like with `get`) and `.status`; check the three problem texts. Assert the request passed to the opener is a `urllib.request.Request` with `method == "HEAD"` and header `User-agent` == `namo-app-build/1.0` (urllib capitalises).
- `test_verify_full_hashes_the_download`: the fake opener yields a body of `b"abcdef"` through `.read(n)`; good body → no problems; body `b"abcdeX"` → checksum problem.
- `test_cli`: `main([root, "--check"])` returns 0 and prints the success line; `main([root])` returns 2 with the usage on stderr.

- [ ] **Step 2: Run them to see them fail**

Run: `python -I -X utf8 tools/test_sync_hosted_audio.py`
Expected: FAIL (module not found).

- [ ] **Step 3: Implement `tools/sync_hosted_audio.py`**

Module docstring in the style of `build_pirith.py` (what it does, usage lines). Read every `assets/content/*.json` with `encoding="utf-8"`; walk `categories[].readings[].audio`, skipping `None`. `check` returns the first problem in this order: missing file, size, checksum (hash only when the size matches), extra files (`hosted.rglob("*")`, files only, relative POSIX paths, sorted). Usage errors print the usage to stderr and return 2; `SyncError` prints `sync_hosted_audio: <message>` to stderr and returns 1.

- [ ] **Step 4: Run the tests and the real check**

Run: `python -I -X utf8 tools/test_sync_hosted_audio.py` → PASS. Then `python -I -X utf8 tools/sync_hosted_audio.py . --check` → `hosted audio is up to date`, exit 0. Then `python -I -X utf8 tools/sync_hosted_audio.py . --plan | head -3` shows three `npx wrangler r2 object put namo-audio/audio/pirith/...` lines. Do not run `--upload`, `--verify` or `--verify-full` (no network, no account).

- [ ] **Step 5: Write `hosted/README.md`**

About 25 lines: this folder mirrors the R2 bucket `namo-audio` served at `https://audio.intendable.us`; object key = path under `hosted/`; the rule that a file is never replaced under the same name (clients cache for a year); the upload headers; the commands (`--check`, `--plan`, `--upload` after `npx wrangler login`, `--verify`, `--verify-full`, `--base-url` for an `r2.dev` address while the custom domain is not live); the CORS policy to set on the bucket (`[{"AllowedOrigins": ["*"], "AllowedMethods": ["GET", "HEAD"], "AllowedHeaders": ["Range"], "MaxAgeSeconds": 86400}]`); the licence note (pirith CC BY-ND 4.0 from pitaka.lk; Samantha Pattana from Samata Dharmaya, permission pending; the bucket stays private until the owner confirms the permissions). Run the sync check again: `hosted/README.md` is allowed.

- [ ] **Step 6: Update `README.md`**

Line 4 becomes exactly: `It has no ads, no payments and no analytics; its only network use is fetching the chant recordings, once each, from the app's own host.` Line 3 drops the word "offline" in favour of: `Namo is a free Buddhist prayer book for Android, iOS and the web, built from one Flutter code base; the texts work offline.` In the Pirith section: `--check` "also checks each recording under hosted/audio/pirith/ is the downloaded original"; `--import-audio` "copies them into hosted/audio/pirith/"; line 41 "the 39 recordings that ship are the ones in hosted/audio/pirith/". Same for Samantha Pattana (`hosted/audio/samantha_patthana/`). New section `## Hosting the recordings` before `## Commands`: two short paragraphs (the recordings are not in the app; they are uploaded to the owner's Cloudflare R2 bucket and fetched once by the app; see `hosted/README.md`) and the five tool commands. `## Commands` gains `Hosted audio check: python -I -X utf8 tools/sync_hosted_audio.py . --check. Its tests: python -I -X utf8 tools/test_sync_hosted_audio.py.`

- [ ] **Step 7: Commit**

```bash
git add tools/sync_hosted_audio.py tools/test_sync_hosted_audio.py hosted/README.md README.md
git commit -m "Tools: sync_hosted_audio checks, plans, uploads and verifies the hosted recordings"
```

---

### Task 4: Audio foundation: host URL, locations, the thin downloader and file interfaces, platform adapters

**Files:**
- Create: `lib/audio/audio_host.dart`, `lib/audio/recording_location.dart`, `lib/audio/downloader.dart`, `lib/audio/recording_files.dart`, `lib/audio/platform/platform.dart`, `lib/audio/platform/platform_io.dart`, `lib/audio/platform/platform_web.dart`, `lib/audio/platform/background_downloader_adapter.dart`, `lib/audio/platform/io_recording_files.dart`
- Modify: `pubspec.yaml` (dependencies), `android/app/src/main/AndroidManifest.xml`
- Test: `test/audio/audio_host_test.dart`, `test/audio/io_recording_files_test.dart`

**Interfaces:**
- Consumes: `Recording` (Task 1).
- Produces:
  ```dart
  // lib/audio/audio_host.dart
  const defaultAudioBaseUrl = 'https://audio.intendable.us';
  /// From --dart-define=NAMO_AUDIO_BASE_URL, else the default; never ends in '/'.
  String get audioBaseUrl;
  Uri recordingUrl(Recording r);             // '$audioBaseUrl/${r.path}'
  Uri recordingUrlAt(String baseUrl, Recording r);   // the same with an explicit base (for tests and the tool)

  // lib/audio/recording_location.dart
  sealed class RecordingLocation { const RecordingLocation(); }
  class AssetLocation extends RecordingLocation { const AssetLocation(this.asset); final String asset; }
  class FileLocation extends RecordingLocation { const FileLocation(this.path); final String path; }
  class UrlLocation extends RecordingLocation { const UrlLocation(this.url); final Uri url; }
  // all three have value equality and toString

  // lib/audio/downloader.dart
  enum DownloadStatus { enqueued, running, complete, notFound, failed, canceled, waitingToRetry, paused }
  class DownloadRequest {
    const DownloadRequest({required this.id, required this.url, required this.directory, required this.filename,
        required this.group, required this.requiresWiFi});
    final String id; final Uri url; final String directory; final String filename; final String group; final bool requiresWiFi;
  }
  sealed class DownloadEvent { const DownloadEvent(this.id); final String id; }
  class DownloadStatusEvent extends DownloadEvent { const DownloadStatusEvent(super.id, this.status); final DownloadStatus status; }
  class DownloadProgressEvent extends DownloadEvent { const DownloadProgressEvent(super.id, this.progress); final double progress; }  // 0–1 only; negative plugin values are never forwarded
  const autoGroup = 'auto';
  const manualGroup = 'manual';
  abstract interface class Downloader {
    /// Configures and starts the platform downloader; returns the base directory
    /// (application support) under which [DownloadRequest.directory] lives. Throws when the platform cannot download.
    Future<String> start();
    Future<void> enqueue(DownloadRequest request);
    Future<void> cancelGroup(String group);
    /// Every task of [autoGroup] and [manualGroup] still known to the platform.
    Future<List<DownloadRequest>> active();
    Stream<DownloadEvent> get events;
  }

  // lib/audio/recording_files.dart
  abstract interface class RecordingFiles {
    Future<int?> sizeOf(String path);        // null when the file is missing
    Future<String> sha256Of(String path);    // lower-case hex, computed off the main thread
    Future<void> delete(String path);        // nothing happens when the file is missing
  }

  // lib/audio/platform/platform.dart  (conditional export)
  export 'platform_web.dart' if (dart.library.io) 'platform_io.dart';
  // both files define:
  Downloader createDownloader();
  RecordingFiles createRecordingFiles();
  // platform_web.dart throws UnsupportedError('no downloads on the web') from both; platform_io.dart returns
  // BackgroundDownloaderAdapter() and IoRecordingFiles().
  ```
  `BackgroundDownloaderAdapter implements Downloader` (the only file that imports `package:background_downloader`): `start()` calls `FileDownloader().configure(globalConfig: [(Config.checkAvailableSpace, 100)], iOSConfig: [(Config.excludeFromCloudBackup, true)])`, subscribes to `FileDownloader().updates` mapping `TaskStatusUpdate` → `DownloadStatusEvent(update.task.taskId, <same-named DownloadStatus>)` and `TaskProgressUpdate` with `0 <= progress <= 1` → `DownloadProgressEvent`, then `await FileDownloader().start()` and returns `await Task.baseDirectoryPath(BaseDirectory.applicationSupport)`. `enqueue` builds `DownloadTask(taskId: r.id, url: r.url.toString(), directory: r.directory, filename: r.filename, baseDirectory: BaseDirectory.applicationSupport, group: r.group, updates: Updates.statusAndProgress, requiresWiFi: r.requiresWiFi, retries: 3, allowPause: true, metaData: r.id)` and calls `FileDownloader().enqueue`. `cancelGroup(g)` → `FileDownloader().cancelAll(group: g)`. `active()` → `allTasks(group: autoGroup)` + `allTasks(group: manualGroup)`, mapped back (`Uri.parse(task.url)`). `IoRecordingFiles({this.inBackground = true}) implements RecordingFiles` uses `dart:io` and `package:crypto`: `sha256Of` runs `compute(_hashFile, path)` when `inBackground`, else `_hashFile(path)` directly (the `tipitaka_repository.dart` pattern), where `_hashFile` is a top-level function that streams `File(path).openRead()` through `sha256` and returns `digest.toString()`.

- [ ] **Step 1: Add the dependencies and the permission**

`pubspec.yaml` dependencies: `background_downloader: ^9.6.6` and `crypto: ^3.0.8`. Run `flutter pub get`; expected: resolves (Flutter ≥ 3.47, Dart ≥ 3.13 satisfied). `android/app/src/main/AndroidManifest.xml`: add `<uses-permission android:name="android.permission.INTERNET" />` as the first child of `<manifest>`, before `<application>`.

- [ ] **Step 2: Write the failing tests**

`test/audio/audio_host_test.dart`:
```dart
const r = Recording(readingId: 'x', path: 'audio/pirith/08-mahamangala.m4a', label: '', placeholder: false);
test('the default host and path make one URL', () {
  expect(recordingUrlAt('https://audio.intendable.us', r).toString(),
      'https://audio.intendable.us/audio/pirith/08-mahamangala.m4a');
});
test('a trailing slash on the base is not doubled', () {
  expect(recordingUrlAt('https://x.example/', r).toString(), 'https://x.example/audio/pirith/08-mahamangala.m4a');
});
test('without a dart-define the base is the default host', () {
  expect(audioBaseUrl, defaultAudioBaseUrl);
  expect(recordingUrl(r).host, 'audio.intendable.us');
});
test('locations compare by value', () {
  expect(const FileLocation('/a'), const FileLocation('/a'));
  expect(const FileLocation('/a'), isNot(const AssetLocation('/a')));
});
```
`test/audio/io_recording_files_test.dart` (plain `test()`s; a `dart:io` temp dir from `Directory.systemTemp.createTempSync('namo_files_')`, deleted in `tearDown`): `sizeOf` of a 6-byte file is 6 and of a missing file is null; `sha256Of` of a file holding `abcdef` equals `sha256.convert(utf8.encode('abcdef')).toString()` from `package:crypto` (computed in the test, not a literal), with the default `inBackground: true`; `delete` removes the file and does not throw for a missing one.

- [ ] **Step 3: Run them to see them fail**

Run: `flutter test test/audio/audio_host_test.dart test/audio/io_recording_files_test.dart`
Expected: compile errors.

- [ ] **Step 4: Implement the files in Interfaces**

`audioBaseUrl`: `const _defined = String.fromEnvironment('NAMO_AUDIO_BASE_URL');` → `(_defined.isEmpty ? defaultAudioBaseUrl : _defined)` with trailing slashes stripped. `recordingUrlAt` strips trailing slashes from `baseUrl` and leading slashes from `r.path`.

- [ ] **Step 5: Run the tests, the analyzer and the web build**

Run: `flutter test test/audio` → PASS. `flutter analyze` → no issues. `flutter build web --no-web-resources-cdn` → builds (the adapter is reached only through the conditional export, so the web build never compiles it; this step proves that).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml lib/audio/audio_host.dart lib/audio/recording_location.dart lib/audio/downloader.dart lib/audio/recording_files.dart lib/audio/platform test/audio/audio_host_test.dart test/audio/io_recording_files_test.dart
git commit -m "Audio: host URL, recording locations, downloader and file interfaces with platform adapters"
```

---

### Task 5: The recording store

**Files:**
- Create: `lib/audio/recording_store.dart`, `lib/audio/recording_store_device.dart`, `test/support/fake_downloader.dart`, `test/audio/recording_store_test.dart`, `test/audio/recording_size_test.dart`

**Interfaces:**
- Consumes: Task 4 (`Downloader`, `DownloadRequest`, `DownloadEvent`, `RecordingFiles`, `RecordingLocation`, `recordingUrl`), Task 2 (`AutoDownload`), `KeyValueStore` (`lib/storage/key_value_store.dart`: `read`, `save`), `Recording`.
- Produces:
  ```dart
  // lib/audio/recording_store.dart
  enum Availability { downloaded, downloading, waiting, failed, notDownloaded }
  class RecordingStatus {
    const RecordingStatus({required this.availability, this.progress = 0, this.reason, required this.bytes});
    final Availability availability; final double progress; final String? reason; final int bytes;
    // value equality
  }
  class RecordingsSnapshot {
    const RecordingsSnapshot(this.statuses);          // Map<String readingId, RecordingStatus>, library order
    static const empty = RecordingsSnapshot({});
    final Map<String, RecordingStatus> statuses;
    RecordingStatus? of(String readingId);
    int get total; int get downloaded; int get failed;
    int get active;                                    // downloading + waiting
    int get bytesTotal; int get bytesDownloaded;       // downloaded bytes plus progress × bytes of each downloading one
    bool get anyDownloading;                           // any status downloading
    bool get allDownloaded;                            // total > 0 && downloaded == total
  }
  const damagedMessage = 'The downloaded recording was damaged. It will be fetched again.';
  const notOnServerMessage = 'This recording is not on the server yet.';
  const connectionMessage = 'Could not download the recording. Check your connection.';
  String formatSize(int bytes);                        // see Global Constraints
  const verifiedKey = 'namo.recordings.verified.v1';   // JSON object: path → sha256

  abstract interface class RecordingStore {
    ValueListenable<RecordingsSnapshot> get snapshot;
    RecordingLocation? locationFor(Recording r);      // null = not on the device yet
    Future<void> download(Recording r);                // this one, now, any connection
    Future<void> downloadAll();                        // every missing one, now, any connection
    Future<void> removeAll();
  }
  class EmptyRecordingStore implements RecordingStore { EmptyRecordingStore(); }   // snapshot always RecordingsSnapshot.empty, locationFor: placeholder → AssetLocation, else null; the rest no-ops
  class WebRecordingStore implements RecordingStore {
    WebRecordingStore(List<Recording> recordings, {Uri Function(Recording) urlOf = recordingUrl});
    // every recording downloaded; locationFor → UrlLocation(urlOf(r)), placeholder → AssetLocation; download/removeAll no-ops
  }

  // lib/audio/recording_store_device.dart   (no dart:io import; everything goes through the interfaces)
  class DeviceRecordingStore implements RecordingStore {
    DeviceRecordingStore({
      required List<Recording> recordings,          // library order, no placeholder
      required Downloader downloader,
      required RecordingFiles files,
      required KeyValueStore store,
      required AutoDownload autoDownload,
      required VoidCallback turnOffAutoDownload,
      Uri Function(Recording) urlOf = recordingUrl,
    });
    Future<void> start();                              // never throws
    void setAutoDownload(AutoDownload v);
    String relativeFile(Recording r) => 'recordings/${r.path}';   // under the downloader's base directory
    Future<void> dispose();
  }
  ```
- Behaviour of `DeviceRecordingStore` (the algorithm the signatures do not determine):
  - Every status starts `notDownloaded` with the recording's `bytes`. `start()`: `base = await downloader.start()` inside try/catch — on an error every status stays `notDownloaded`, `locationFor` stays null, and nothing else runs. Then it reads the verified map from `store.read(verifiedKey)` (invalid JSON → empty), lists `downloader.active()`, and for each recording in order: file size (`files.sizeOf('$base/${relativeFile(r)}')`) equal to `r.bytes` and `verified[r.path] == r.sha256` → `downloaded`; size equal but not verified (or verified under another hash) → hash it; equal → record and `downloaded`, else delete and treat as missing; size present but wrong → delete, missing; an active task with id `r.path` → `waiting`; otherwise missing. Every missing recording is enqueued in `autoGroup` when the setting is not `off`, with `requiresWiFi: autoDownload == AutoDownload.wifiOnly`; one `DownloadRequest` per recording: `id: r.path`, `url: urlOf(r)`, `directory: 'recordings/<dirname of r.path>'`, `filename: <basename of r.path>`.
  - Events by id (`r.path`); unknown ids are ignored. `running` → `downloading` (progress kept from progress events); `enqueued`, `waitingToRetry`, `paused` → `waiting`; `complete` → verify: size must equal `bytes`, then `sha256Of` must equal `sha256`; pass → save to the verified map, `downloaded`; fail → delete the file, `failed` with `damagedMessage`, and re-enqueue once (same group as before) — a second damage stays `failed`; `notFound` → `failed` with `notOnServerMessage`; `failed` → `failed` with `connectionMessage`; `canceled` → `notDownloaded` unless the store itself cancelled it to re-enqueue (then whatever the re-enqueue sets).
  - `setAutoDownload(v)`: cancel `autoGroup`; the recordings that were in it become `notDownloaded`; when `v != off` enqueue every recording that is neither downloaded nor in `manualGroup` with the new flag → `waiting`.
  - `download(r)`: already downloaded → nothing; otherwise cancel its auto task if it has one, enqueue in `manualGroup` with `requiresWiFi: false` → `waiting`. `downloadAll()`: `download` for every one not downloaded, in library order.
  - `removeAll()`: `turnOffAutoDownload()` first, then cancel both groups, delete every recording's file, clear the verified map, every status `notDownloaded`.
  - `locationFor(r)`: placeholder → `AssetLocation(r.path)`; status downloaded → `FileLocation('$base/${relativeFile(r)}')`; else null.
  - The snapshot notifier emits only when something changed.

- [ ] **Step 1: Write the fake downloader**

`test/support/fake_downloader.dart`: `class FakeDownloader implements Downloader` with `String base = '/tmp/fake'` (settable; tests pass a real temp directory), `bool failToStart = false` (then `start()` throws `StateError`), `final enqueued = <DownloadRequest>[]` (everything ever enqueued), `List<DownloadRequest> get live` (enqueued minus cancelled or finished), `final cancelledGroups = <String>[]`, `List<DownloadRequest> preExisting = []` (returned by `active()` before any enqueue), a `StreamController<DownloadEvent>.broadcast()` behind `events`, and helpers `void emit(DownloadEvent e)` and `void finish(String id)` (removes from live, emits `complete`). `cancelGroup(g)` removes the group's live requests and emits `canceled` for each.

- [ ] **Step 2: Write the failing store tests**

`test/audio/recording_size_test.dart`: `formatSize(1046598) == '1.0 MB'`, `formatSize(171439) == '0.2 MB'`, `formatSize(46219957) == '46 MB'`, `formatSize(102523878) == '103 MB'`, `formatSize(7420182) == '7.4 MB'`.

`test/audio/recording_store_test.dart` (plain `test()`s, no widgets, so `compute` may spawn a real isolate) uses a real temp directory (`Directory.systemTemp.createTempSync`) as `fake.base`, `IoRecordingFiles()`, `InMemoryKeyValueStore()`, and two recordings `a` (`audio/t/a.m4a`, bytes 6, sha of `abcdef`) and `b` (`audio/t/b.m4a`, bytes 3, sha of `xyz`). A helper `store(…)` builds a `DeviceRecordingStore` with a recording `turnedOff` counter. Tests, each named for its rule:

- `'nothing on the device, Wi-Fi only: every recording is enqueued in auto with the Wi-Fi flag, in order'` → two requests, ids `audio/t/a.m4a` then `audio/t/b.m4a`, group auto, `requiresWiFi` true, statuses waiting, `directory == 'recordings/audio/t'`, `filename == 'a.m4a'`.
- `'any connection enqueues without the Wi-Fi flag'`; `'off enqueues nothing and reads notDownloaded'`.
- `'a file of the right size that is not yet verified is hashed and counts as downloaded'` (write `abcdef` to `$base/recordings/audio/t/a.m4a` before start; after start `a` downloaded, verified map saved under `verifiedKey`, `b` waiting, only one request).
- `'off with files present still plays them'` (Review Focus 2).
- `'a verified file whose content hash changed is deleted and fetched again'` (verified map holds the old hash, file matches the old hash; after start the file is gone and `a` is enqueued) (Review Focus 4).
- `'a file of the wrong size is deleted and fetched again'`.
- `'an active task found at start reads waiting and is not enqueued twice'` (`preExisting`).
- `'running and progress events show downloading with progress'` (`DownloadStatusEvent(running)` then `DownloadProgressEvent(0.42)` → downloading, 0.42, `bytesDownloaded` rounds to 2 for a 6-byte file).
- `'a completed download that verifies is downloaded and remembered'` (write `abcdef` then `fake.finish(a.path)`; status downloaded, `locationFor(a) == FileLocation('$base/recordings/audio/t/a.m4a')`, verified map saved).
- `'a damaged download is deleted, marked failed and fetched again once'` (write `abcdeX`, finish → failed with `damagedMessage`, file gone, `enqueued` has a second request for `a`; write `abcdeX` again, finish → failed, no third request).
- `'notFound and failed carry their messages'`.
- `'download(r) moves an automatic task to the manual group with no Wi-Fi flag'` (cancelledGroups is empty — only that task is cancelled, so assert `live` holds `a` in manual and `b` in auto).
- `'downloadAll enqueues every missing recording in manual'`.
- `'changing the setting re-enqueues the automatic queue with the new flag and leaves manual alone'`.
- `'removeAll turns the setting off first, cancels everything and deletes the files'` (`turnedOff == 1`, both groups cancelled, files gone, verified map empty, statuses notDownloaded).
- `'a downloader that cannot start leaves every recording notDownloaded without throwing'` (Review Focus 1).
- `'an event for an unknown id is ignored'`.
- `'the snapshot counts'` (total 2, downloaded 1, active 1, bytesTotal 9, allDownloaded false; then both → allDownloaded true).
- `'the placeholder tone is always an asset'`; `'WebRecordingStore gives the URL for every recording'`; `'EmptyRecordingStore has nothing'`.

- [ ] **Step 3: Run them to see them fail**

Run: `flutter test test/audio/recording_store_test.dart test/audio/recording_size_test.dart`
Expected: compile errors.

- [ ] **Step 4: Implement `recording_store.dart` and `recording_store_device.dart`**

Follow Interfaces and Behaviour. Keep the device store free of `dart:io`; hashing and file checks go through `RecordingFiles`. Use `path`-style helpers from `dart:core` only (`lastIndexOf('/')`) for dirname/basename; no new package.

- [ ] **Step 5: Run the tests and the analyzer**

Run: `flutter test test/audio` and `flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/audio/recording_store.dart lib/audio/recording_store_device.dart test/support/fake_downloader.dart test/audio/recording_store_test.dart test/audio/recording_size_test.dart
git commit -m "Audio: RecordingStore keeps, verifies and reports the downloaded recordings"
```

---

### Task 6: Wiring: the store provider, the player opens a location, tests get a fake store

**Files:**
- Create: `lib/audio/recording_store_provider.dart`, `test/support/fake_recording_store.dart`, `test/audio/recording_store_provider_test.dart`
- Modify: `lib/audio/audio_catalogue.dart` (`ContentAudioCatalogue` gains `recordings`), `lib/audio/chant_player.dart` (`JustAudioChantPlayer`, `load`, `chantPlayerProvider`), `lib/app.dart` (`NamoApp.build`), `test/support/pump_app.dart`, `test/quality/quality_support.dart` (`openReal`)

**Interfaces:**
- Consumes: Task 5 (`RecordingStore`, `DeviceRecordingStore`, `WebRecordingStore`, `EmptyRecordingStore`), Task 4 (`createDownloader`, `createRecordingFiles`, `RecordingLocation`), Task 2 (`AutoDownload`, `setAutoDownload`), `libraryProvider`, `keyValueStoreProvider`, `settingsProvider`.
- Produces:
  ```dart
  // lib/audio/audio_catalogue.dart
  class ContentAudioCatalogue { List<Recording> get recordings; }   // library order, every reading with audio

  // lib/audio/recording_store_provider.dart
  final recordingStoreProvider = Provider<RecordingStore>(...);
  // library not loaded → EmptyRecordingStore(); kIsWeb → WebRecordingStore(recordings);
  // else DeviceRecordingStore(recordings, downloader: createDownloader(), files: createRecordingFiles(),
  //   store: ref.read(keyValueStoreProvider), autoDownload: ref.read(settingsProvider).autoDownload,
  //   turnOffAutoDownload: () => ref.read(settingsProvider.notifier).setAutoDownload(AutoDownload.off)),
  //   then ref.listen(settingsProvider.select((s) => s.autoDownload), (_, v) => store.setAutoDownload(v)),
  //   ref.onDispose(store.dispose), unawaited(store.start()).

  // lib/audio/chant_player.dart
  typedef Locate = RecordingLocation? Function(Recording r);
  class JustAudioChantPlayer implements ChantPlayer { JustAudioChantPlayer({required Locate locate}); }
  // load(): switch (locate(r)) { AssetLocation a → _player.setAsset(a.asset); FileLocation f → _player.setFilePath(f.path);
  //   UrlLocation u → _player.setUrl(u.url.toString()); null → _failed = true; } — same generation and try/catch as today
  // chantPlayerProvider passes locate: (r) => ref.read(recordingStoreProvider).locationFor(r)

  // test/support/fake_recording_store.dart
  class FakeRecordingStore implements RecordingStore {
    FakeRecordingStore({Availability everything = Availability.downloaded});
    final snapshot = ValueNotifier<RecordingsSnapshot>(RecordingsSnapshot.empty);
    void set(String readingId, RecordingStatus status);          // updates the snapshot (notifies listeners)
    final downloads = <String>[];   // Recording.path of every recording passed to download, in order
    int downloadAllCalls = 0;  int removeAllCalls = 0;
    // locationFor: placeholder → AssetLocation; status downloaded (or unknown id, when everything == downloaded) → FileLocation('/fake/${r.path}'); else null
  }
  ```
  `pumpApp` and `openReal` gain `RecordingStore? recordingStore` and always override `recordingStoreProvider` with `recordingStore ?? FakeRecordingStore()` (added to their own override list, so callers never pass it through `overrides`). `NamoApp.build` adds `ref.watch(recordingStoreProvider);` before the `MaterialApp.router` so the store starts with the app.

- [ ] **Step 1: Write the failing tests**

`test/audio/recording_store_provider_test.dart` (plain `test()`s on a `ProviderContainer`): `'while the library loads the store is empty'` (override `contentRepositoryProvider` with a repository whose `load()` never completes → the store is an `EmptyRecordingStore`); `'ContentAudioCatalogue.recordings lists every reading with audio in library order'` (a library built from `testLibrary()`'s category plus a second category with two readings that have audio; expect the two paths in order); `'the fake store gives a file for a downloaded recording, nothing for a waiting one and the asset for the placeholder'` (`FakeRecordingStore.locationFor` after `set`). The web and device branches of the provider are not unit-tested (`kIsWeb` is a constant and the device branch needs the plugin); the device store itself is covered by Task 5. `JustAudioChantPlayer` needs the platform and stays untested, as today.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/audio/recording_store_provider_test.dart`
Expected: compile errors.

- [ ] **Step 3: Implement**

As in Interfaces. In `chant_player.dart` keep `_loadGen`, `_failed`, the speed re-application and the try/catch exactly as today; only the source call changes.

- [ ] **Step 4: Run the whole suite**

Run: `flutter test` and `flutter analyze`
Expected: PASS (every widget test still runs because `pumpApp` supplies the fake store), no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/audio/recording_store_provider.dart lib/audio/audio_catalogue.dart lib/audio/chant_player.dart lib/app.dart test/support/fake_recording_store.dart test/support/pump_app.dart test/quality/quality_support.dart test/audio/recording_store_provider_test.dart test/audio/reader_audio_test.dart
git commit -m "Audio: the store provider; the player opens an asset, a file or a URL"
```

---

### Task 7: The reader downloads on request and plays when the file arrives

**Files:**
- Modify: `lib/reader/chant_bar.dart`, `lib/reader/reader_bottom_bar.dart` (constructor 23-74, `_chantRows` 82-176, `_ChantPlayButton` 331-383), `lib/reader/reader_screen.dart` (`_bindAudio` 210-250, `_chantPlayOrPause` 382-402, `dispose` 435-457, bottom bar 967-997)
- Test: `test/reader/recording_download_test.dart` (new), `test/reader/chant_bar_test.dart`

**Interfaces:**
- Consumes: Task 6 (`recordingStoreProvider`, `FakeRecordingStore`), Task 5 (`RecordingStatus`, `Availability`, `formatSize`, messages).
- Produces:
  ```dart
  // lib/reader/chant_bar.dart
  String recordingLine(RecordingStatus s);
  // downloading → 'Downloading recording… 42%' ((progress*100).floor()); waiting → 'Waiting to download · 1.0 MB';
  // notDownloaded → 'Recording not downloaded · 1.0 MB'; failed → s.reason ?? connectionMessage; downloaded → ''
  class RecordingRow extends StatelessWidget {
    const RecordingRow({super.key = const ValueKey('recording-row'), required this.status, required this.onDownload});
    final RecordingStatus status; final VoidCallback? onDownload;
  }
  // a Row: Expanded(Text(recordingLine(status), NamoType.caption(p.textSecondary), live region)) and, for waiting/notDownloaded
  // a TextAction(key: ValueKey('recording-download'), label: 'Download'), for failed TextAction(key: ValueKey('recording-download'),
  // label: 'Try again'); nothing for downloading

  // lib/reader/reader_bottom_bar.dart
  ReaderBottomBar({..., this.recording, this.onDownload});   // RecordingStatus? recording; VoidCallback? onDownload
  // in _chantRows: recording == null || recording.availability == downloaded → today's rows;
  // otherwise the Expanded(_ChantPosition) slot holds RecordingRow(status: recording, onDownload: onDownload);
  // downloading → _ChantPlayButton shows its spinner with onTap null (new parameter `busy`); restart disabled; speed button unchanged
  ```
  Reader logic: `_chantPlayOrPause` reads `ref.read(recordingStoreProvider).snapshot.value.of(recording.readingId)?.availability ?? Availability.downloaded`; when it is not `downloaded`: `_chantWanted = true; _autoScroll.pause(); if (availability != Availability.downloading) unawaited(store.download(recording)); return;`. A listener `_onRecordings()` on `store.snapshot` (added in `_bindAudio`, removed in `dispose` and before re-binding) calls `_chantPlayOrPause()` when `_chantWanted && !_chantLoaded` and the status has become `downloaded`. `onDownload` for the bar is `() => unawaited(ref.read(recordingStoreProvider).download(recording))` without setting `_chantWanted`. The bottom bar's `ListenableBuilder` merges `store.snapshot` with `_autoScroll` and `_chant`, and passes `recording: store.snapshot.value.of(recording.readingId)` (null when the id is unknown).

- [ ] **Step 1: Write the failing tests**

`test/reader/chant_bar_test.dart`: `recordingLine` for each availability with the strings above (a 1,046,598-byte waiting recording → `'Waiting to download · 1.0 MB'`; downloading 0.426 → `'Downloading recording… 42%'`; failed with `notOnServerMessage` → that message).

`test/reader/recording_download_test.dart`, opening the Mahamangala pirith like `pirith_chanting_test.dart`'s `_open` (`openReal(t, Routes.reader(mangalaReadingId), library: await realLibrary(t), player: player, recordingStore: store)` with a `FakeRecordingStore` whose status for `mangalaReadingId` the test sets):
- `'a downloaded recording shows the slider and plays'` (status downloaded: `chant-slider` present, no `recording-row`; tap `chant-play` → `player.loaded` has one entry).
- `'a waiting recording shows the line and a Download button'` (`recording-row` text `'Waiting to download · 1.0 MB'`, `recording-download` present, no slider).
- `'Download asks the store for this recording'` (tap `recording-download` → `store.downloads == [mangalaReadingId's path]`... assert on the `Recording.path` the store received).
- `'play on a waiting recording downloads it and plays when it arrives'` (tap `chant-play` → `store.downloads` has it and `player.loaded` is empty; `store.set(id, downloaded)` + pump → `player.loaded` has one entry and the state is playing).
- `'while downloading the play button is busy and the row shows the percentage'` (`chant-play` tooltip's tappable is disabled; text contains `'42%'`; `CircularProgressIndicator` present).
- `'a failed recording shows its reason and Try again'` (reason `notOnServerMessage`; tapping `recording-download` calls `store.download`).
- `'leaving the reader before the file arrives plays nothing'` (tap play on waiting; then `ProviderScope.containerOf(t.element(find.byType(Scaffold).first)).read(routerProvider).go(Routes.settings)` and `pumpAndSettle`; then `store.set(id, <downloaded status>)` and pump; `player.loaded` stays empty and `t.takeException()` is null) (Review Focus 5).
- `'the bar of a reading without a recording is unchanged'` (open the Namaskaraya reading: `reader-play` present, no `recording-row`).
- In `test/quality/overflow_test.dart` add one `testWidgets('the pirith reader with a failed recording does not overflow')`: `openReal` on the Mahamangala reader at 320×568 with device text 2.0, a `FakeRecordingStore` whose status for it is `failed` with `damagedMessage` (the longest line), the same no-overflow assertion the file already uses.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/reader/chant_bar_test.dart test/reader/recording_download_test.dart`
Expected: compile errors / no `recording-row`.

- [ ] **Step 3: Implement**

As in Interfaces. `RecordingRow`'s text uses `Semantics(liveRegion: true)` like `ChantFailed`. `_ChantPlayButton` gains `this.busy = false`: busy or loading → spinner and `onTap: null`.

- [ ] **Step 4: Run the reader suite, the whole suite, the analyzer and the glyph check**

Run: `flutter test test/reader test/quality`, then `flutter test`, `flutter analyze`, `python -I -X utf8 tools/check_ui_glyphs.py .`
Expected: PASS, no issues, exit 0.

- [ ] **Step 5: Commit**

```bash
git add lib/reader/chant_bar.dart lib/reader/reader_bottom_bar.dart lib/reader/reader_screen.dart test/reader/chant_bar_test.dart test/reader/recording_download_test.dart test/quality/overflow_test.dart
git commit -m "Reader: a recording that has not arrived shows its state and downloads on request"
```

---

### Task 8: Settings: the Recordings group, About and Sources copy

**Files:**
- Create: `lib/settings/recordings_group.dart`, `test/settings/recordings_group_test.dart`
- Modify: `lib/settings/choosers.dart` (add `AutoDownloadChooser`), `lib/settings/settings_screen.dart` (insert the group between Audio and Auto-scroll, lines 121-123; About text line 143), `lib/settings/sources_screen.dart` (recording line near 205-211), `test/settings/settings_screen_test.dart` (`groupLabels`, `findsNWidgets(6)`, the About text, the drag count), `test/settings/choosers_test.dart`, `test/settings/sources_screen_test.dart`, `test/quality/overflow_test.dart` (Settings variants)

**Interfaces:**
- Consumes: Task 2 (`AutoDownload`, `setAutoDownload`), Task 6 (`recordingStoreProvider`, `FakeRecordingStore`), Task 5 (`RecordingsSnapshot`, `formatSize`), design widgets `SettingsGroup`, `SegmentedSelector`, `Segment`, `ProgressLine`, `PrimaryButton`, `QuietButton`, `SettingLabel`.
- Produces:
  ```dart
  // lib/settings/choosers.dart
  class AutoDownloadChooser extends ConsumerWidget { const AutoDownloadChooser({super.key}); }
  // ThemeChooser pattern: semanticLabel 'Download automatically', segments from AutoDownload.values with their labels,
  // selected {settings.autoDownload}, onPressed controller.setAutoDownload

  // lib/settings/recordings_group.dart
  String recordingsSummary(RecordingsSnapshot s);
  // allDownloaded → 'All 40 recordings downloaded · 103 MB'
  // else '12 of 40 downloaded · 23 MB of 103 MB' + (failed > 0 ? ' · 3 could not be downloaded' : '')
  // (numbers from the snapshot; total == 0 → '')
  class RecordingsGroup extends ConsumerWidget { const RecordingsGroup({super.key, this.web = kIsWeb}); final bool web; }
  ```
  `RecordingsGroup` builds `SettingsGroup(icon: Symbols.download_rounded, label: 'Recordings', children: [...])`. Web: one child, the caption `'In the browser, recordings play from the internet when you press play.'`. Otherwise children: (1) a Column with the caption `'Recordings are fetched from the internet once and kept on this device. Texts never need a connection.'` (same padding and style as the Audio group's caption), `SettingLabel('Download automatically')` and `AutoDownloadChooser()`; (2) a `ValueListenableBuilder` on `store.snapshot` giving a Column: `Text(recordingsSummary(s), key: ValueKey('recordings-summary'), style: NamoType.body(p.text))`, below it `ProgressLine(value: s.bytesDownloaded / s.bytesTotal, semanticsLabel: 'Download progress', height: 2)` only while `s.anyDownloading`, then a Wrap of buttons: `PrimaryButton(key: ValueKey('recordings-download-all'), label: 'Download all now', onPressed: store.downloadAll)` while `!s.allDownloaded && s.total > 0`, and `QuietButton(key: ValueKey('recordings-remove'), label: 'Remove downloaded recordings', onPressed: …)` while `s.downloaded + s.active > 0`. Remove opens an `AlertDialog` like `flow_editor_screen.dart:91-118`: `Text('Remove ${formatSize(s.bytesDownloaded)} of recordings from this device? They can be downloaded again.', style: NamoType.body(p.text))`, `QuietButton(key: ValueKey('recordings-remove-keep'), label: 'Keep')`, `PrimaryButton(key: ValueKey('recordings-remove-confirm'), label: 'Remove')`; on confirm `store.removeAll()`. Horizontal padding `NamoSpace.lg`, `NamoSpace.sm` between summary, bar and buttons.
  `settings_screen.dart`: insert `const SizedBox(height: NamoSpace.lg), const RecordingsGroup(),` between the Audio and Auto-scroll groups; About text becomes `'Free. No ads. Texts work offline; recordings are downloaded once.'`. `sources_screen.dart`: after the line `'Namo is not made by, or connected with, namo.lk or pitaka.lk.'` add a paragraph in the same style: `"The recordings are fetched from the app's own storage (audio.intendable.us), not from the sources' sites."`.

- [ ] **Step 1: Write the failing tests**

`test/settings/recordings_group_test.dart` pumps `RecordingsGroup` the way `choosers_test.dart`'s `_pump` does, adding `recordingStoreProvider.overrideWithValue(store)` to the container; a helper `snapshot({int downloaded, int downloading, int waiting, int failed})` builds statuses for 40 recordings of 2,563,097 bytes each (total 102,523,880 → "103 MB"):
- `recordingsSummary` unit tests: 12 downloaded of 40 (no progress) → `'12 of 40 downloaded · 31 MB of 103 MB'`; all → `'All 40 recordings downloaded · 103 MB'`; 3 failed appended; empty → `''`.
- `'the chooser saves the setting'` (tap `Any connection` → stored JSON `autoDownload == 'any'`).
- `'Download all now calls the store and disappears when everything is downloaded'`.
- `'the progress bar shows only while downloading'` (`ProgressLine` absent, then present after `store.set` with a downloading status).
- `'Remove asks first and then removes'` (tap `recordings-remove` → dialog text contains `'of recordings from this device?'`; tap `recordings-remove-keep` → `removeAllCalls == 0`; tap again, `recordings-remove-confirm` → 1).
- `'on the web the group has only the sentence'` (`RecordingsGroup(web: true)`: the sentence is there, no chooser, no buttons).
- `'with no recordings known there is no summary and no buttons'`.

`test/settings/settings_screen_test.dart`: `groupLabels` gains `'Recordings'` after `'Audio'`; `findsNWidgets(7)`; the About text assertion updated; the overflow drag loop gets one more 400 px step if the page is taller. `test/settings/choosers_test.dart`: an `AutoDownloadChooser` test like the `ThemeChooser` one. `test/settings/sources_screen_test.dart`: the new sentence is found. `test/quality/overflow_test.dart`: add one `testWidgets('Settings while recordings download does not overflow')` opening `Routes.settings` through `openReal` at 320×568 with device text 2.0 and a `FakeRecordingStore` whose snapshot has 40 recordings: 12 downloaded, 1 downloading at 0.42, 3 failed, the rest waiting; the same no-overflow assertion the file uses.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/settings`
Expected: compile errors / 6 groups found.

- [ ] **Step 3: Implement**

As in Interfaces. No new colour, no `textMuted`, no `Duration(milliseconds:`.

- [ ] **Step 4: Run the settings suite, the whole suite, the analyzer and the glyph check**

Run: `flutter test test/settings test/quality`, `flutter test`, `flutter analyze`, `python -I -X utf8 tools/check_ui_glyphs.py .`
Expected: PASS, no issues, exit 0.

- [ ] **Step 5: Commit**

```bash
git add lib/settings/recordings_group.dart lib/settings/choosers.dart lib/settings/settings_screen.dart lib/settings/sources_screen.dart test/settings/recordings_group_test.dart test/settings/settings_screen_test.dart test/settings/choosers_test.dart test/settings/sources_screen_test.dart test/quality/overflow_test.dart
git commit -m "Settings: Recordings group with automatic download choice, status and buttons"
```

---

### Task 9: Release checklist, the whole check list, and the sizes for the record

**Files:**
- Modify: `docs/release-checklist.md` (new block after "Reader improvements"), `docs/superpowers/specs/2026-11-15-hosted-recordings-design.md` ("Size, for the record")

- [ ] **Step 1: Add the owner's block to `docs/release-checklist.md`**

A block `Hosted recordings (Cloudflare R2), owner steps:` with one line each: create the bucket `namo-audio` and the custom domain `audio.intendable.us` on the account that holds the zone; set the CORS policy from `hosted/README.md`; keep the bucket private (no public access, no r2.dev) until the pirith and Samantha Pattana recording permissions are confirmed — a public bucket is publication; `npx wrangler login` once, then `python -I -X utf8 tools/sync_hosted_audio.py . --upload` and `--verify-full`; on a phone over Wi-Fi: fresh install, Settings → Recordings shows progress and ends at "All 40 recordings downloaded"; turn Wi-Fi off half way and on again, it resumes; airplane mode: a text opens, an undownloaded recording shows "Recording not downloaded · … MB" with Download, a downloaded one plays; set "Any connection" on mobile data and watch one download; "Remove downloaded recordings" empties the device and sets Off; web: play streams from the host; iOS: build and run once (never built here).

- [ ] **Step 2: Run the whole check list on the branch**

```bash
flutter test
flutter analyze
python -I -X utf8 tools/build_content.py . --check
python -I -X utf8 tools/build_pirith.py . --check
python -I -X utf8 tools/build_samantha_patthana.py . --check
python -I -X utf8 tools/sync_tipitaka.py . --check
python -I -X utf8 tools/sync_hosted_audio.py . --check
python -I -X utf8 tools/check_ui_glyphs.py .
python -I -X utf8 tools/test_build_pirith.py
python -I -X utf8 tools/test_build_samantha_patthana.py
python -I -X utf8 tools/test_sync_hosted_audio.py
flutter build web --no-web-resources-cdn
du -sh build/web
```
Expected: everything passes; the web output is about 98 MB smaller than before (no `assets/audio/` under `build/web/assets/`).

- [ ] **Step 3: Measure the Android packages**

Run: `flutter build apk --release --split-per-abi` (several minutes), then list `build/app/outputs/flutter-apk/*.apk` with sizes. Expected: `app-arm64-v8a-release.apk` about 50 MB (was about 148 MB). If the release signing is not configured the build still produces debug-signed APKs; that is fine for a size reading.

- [ ] **Step 4: Record the sizes**

In the design doc's "Size, for the record", replace the estimates with the measured numbers (arm64 APK, web output) and the date.

- [ ] **Step 5: Commit**

```bash
git add docs/release-checklist.md docs/superpowers/specs/2026-11-15-hosted-recordings-design.md
git commit -m "Docs: hosted recordings owner steps and measured sizes"
```

---

## Rulings taken while planning (for the executor's ledger)

- Untimed recordings (`AudioControls`, no `block_times`): none exists in the content, both build tools always write block times; the untimed path is left as it is — a recording that is not on the device fails to load there with today's message. Flagged in the report.
- Sizes are decimal megabytes (phones show them that way); the spec's "98 MB" was the APK figure, the content totals 102,523,878 bytes → "103 MB".
- `Remove downloaded recordings` shows while anything is downloaded or in flight; `Download all now` while anything is missing.
- The task id of a download is the recording's host path; moving a task from the automatic to the manual group cancels and re-enqueues it under the same id.
- `--remote` is passed to `wrangler r2 object put` so the upload goes to the account's bucket, not Wrangler's local simulator.
