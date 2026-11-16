# Hosted recordings — design

Date: 2026-11-15. Status: reviewed by a builder check; parked on 2026-11-15; the owner
said to build it on 2026-11-16 ("Implement that reducing app size thing").
The items under "Open with the owner" are settled by the designer's defaults
until the owner says otherwise; none of them blocks the build. Plan:
`docs/superpowers/plans/2026-11-16-hosted-recordings.md`.

## Intent

The owner wants a much smaller install. Of the 148 MB Android package, 98 MB
is the 40 chant recordings (39 pirith, 171 KB–7.4 MB each, and the 46 MB
Samantha Pattana recording). The recordings leave the app and live on the
owner's Cloudflare account instead. After install the app fetches them by
itself, quietly, keeps them on the device, and from then on plays them
offline exactly as today. The texts, timings and highlighting stay inside
the app and never need a connection.

The owner chose this over "fetch each recording when play is pressed"
(approach 1 below) on 2026-11-15 ("2").

## Goals

- Android arm64 install about 50 MB instead of 148; the web deployment and
  the iOS build smaller by the same 98 MB.
- Recordings download by themselves after install, without dialogs, and are
  kept until the person removes them.
- Once downloaded, every recording plays offline with the same controls,
  timing and highlighting as now.
- Pressing play on a recording that has not arrived yet fetches that one
  straight away.
- Settings shows what has been downloaded and lets the person choose
  Wi-Fi only / any connection / off, download everything now, or remove
  everything.
- Every downloaded file is checked against the size and SHA-256 that the
  content files already carry; a damaged file is never played.
- The web app keeps today's behaviour (a recording is fetched when play is
  pressed), now from the host.
- The hosting can be rebuilt from the repository: a mirror folder, a sync
  script, an offline check and an online verification.

## Non-goals (this version)

- Playing a recording on a phone while it is still downloading.
- System notifications about download progress (Settings shows it).
- Moving the Tripitaka text (16 MB) or the fonts (5.8 MB) out of the app.
  They could follow the same pattern later.
- Changing, re-encoding or renaming any recording (the pirith licence is
  CC BY-ND 4.0; files stay byte-identical).
- Google Play Asset Delivery or iOS On-Demand Resources.
- Any account, analytics or telemetry. The host sees plain file requests
  and nothing else.

## Anti-goals

- The app, or any text in it, failing without a connection.
- Spending someone's mobile data without their say.
- A first-launch dialog or nag about downloads.
- Anything that identifies the person or the device in a request.
- Playing a partial or damaged file.
- Presenting the recordings as served by pitaka.lk, tipitaka.lk or
  namo.lk. The host is the owner's own domain.

## Constraints

- Android, iOS and web from one code base, all three kept working. iOS
  cannot be built on the owner's Windows machine; say so when reporting.
- Licences are unchanged by where the bytes live. Pirith recordings:
  CC BY-ND 4.0, credited to pitaka.lk and Ven. Nauyane Ariyadhamma Thero.
  Samantha Pattana recording: permission from the channel Samata Dharmaya
  still pending. A public bucket is publication: the release checklist
  gets the same "not before permission is confirmed" line for the bucket
  as it has for the app and the repository.
- No personal details leave the machine. The sync tool identifies itself
  as `namo-app-build/1.0`.
- Package fit, checked 2026-11-15: `background_downloader` 9.6.6 needs
  Flutter ≥ 3.47.0 (we have 3.47.9), Dart ≥ 3.13.0 (3.13.7), Kotlin
  ≥ 2.1.0 (2.4.0), iOS ≥ 14 (we target 15), Android API ≥ 21 (24). It
  downloads with iOS `URLSession` and Android `WorkManager`, so transfers
  continue with the app in the background. It has no web downloader; it
  compiles on web through a stub, and the app never asks it to download
  there.
- `just_audio` ^0.10.6 stays and plays all three source kinds: a bundled
  asset (the development tone), a file (downloaded recording), a URL (web).
- Today the Android manifest has no `INTERNET` permission; it is added.
  iOS needs nothing: HTTPS, and the package needs no AppDelegate change.
- Cloudflare Pages refuses files over 25 MiB, so the 46 MB recording rules
  it out; R2 object storage is used. R2 free tier: 10 GB stored, 10 million
  reads a month, no download charge. A custom domain needs the zone
  (`intendable.us`) on the same Cloudflare account; the owner hosts it
  there. The `r2.dev` address is rate-limited and for development only.
- Repository rules stay: content reaches the app only through the tools in
  `tools/`; every `--check` keeps passing; no `git add -A`; downloaded
  files are untrusted and never executed.

## Approaches considered

1. **Download when play is pressed, then keep.** Smallest change; nothing
   is fetched unasked; a first play of a long recording waits.
2. **Download everything quietly after install** (chosen). Feels like
   today once done; needs the OS background-transfer machinery; data use
   is controlled by a Wi-Fi-only default.
3. **Stream, never store.** Rejected: breaks offline use, re-downloads on
   every play.
4. **Play Asset Delivery / On-Demand Resources.** Rejected: Android-only
   or iOS-only, bypasses the owner's Cloudflare, nothing for web or a
   side-loaded APK.

Approach 2 is built on the same per-recording store approach 1 would use,
so "download this one now" exists too. Two readings of "quietly" were
possible; the design takes: no dialog, starts by itself, but on Wi-Fi only
unless the person changes the setting. That default is the designer's call.

## How it works

### Hosting (Cloudflare, the owner's account)

- One R2 bucket, `namo-audio`, with the custom domain
  `audio.intendable.us` (designer's proposed name). The `r2.dev` public
  address stays off.
- Object keys mirror a new repository folder `hosted/`:
  `audio/pirith/<id>.m4a` (39 files) and
  `audio/samantha_patthana/hYXyO3o7Iac.m4a`. The files move there from
  `assets/audio/` with `git mv`, byte for byte, and stay tracked in git
  (designer's call: the repository history already holds them; the
  alternative, untracked originals, would stop anyone else rebuilding the
  bucket).
- Rule: a file is never replaced under the same name. A different
  recording gets a different file name. So every object is uploaded with
  `Cache-Control: public, max-age=31536000, immutable` and
  `Content-Type: audio/mp4`.
- CORS policy on the bucket: `GET` and `HEAD` from any origin (`*`). The
  content is public; this only lets the web app's own origin play it.
- Until the custom domain is live, a development build can point at the
  bucket's `r2.dev` address with `--dart-define=NAMO_AUDIO_BASE_URL=`, and
  `--verify` / `--verify-full` take `--base-url` for the same reason.
  Switching `r2.dev` on makes the bucket public just as the custom domain
  does. A bucket that holds only some of the recordings is a designed
  state: a missing one shows "This recording is not on the server yet.",
  so the pirith files can go up before the Samantha Pattana one.
- Tool `tools/sync_hosted_audio.py <root>`:
  - `--check` (offline): every recording named in `assets/content/*.json`
    exists under `hosted/` with the listed `bytes` and `sha256`; nothing
    else is under `hosted/`. Joins the project's check list.
  - `--plan`: prints the `npx wrangler r2 object put` command for every
    file, with the headers above. `--upload`: runs them (the owner first
    runs `npx wrangler login` once).
  - `--verify`: a `HEAD` request to every public URL; `Content-Length` and
    `Content-Type` must match. `--verify-full`: downloads each file into a
    fresh temporary directory and checks its SHA-256. Both use a generic
    User-Agent and the standard library only.
  - Tests in `tools/test_sync_hosted_audio.py`, on a made-up folder, no
    network.
- `tools/build_pirith.py` and `tools/build_samantha_patthana.py` keep
  verifying their recordings (`--check`, `--import-audio`), now under
  `hosted/audio/...`.

### Content files

- In both content files each recording's `audio` object gets `path`
  (e.g. `audio/pirith/08-mahamangala.m4a`) in place of `asset`, and keeps
  `label`, `duration_ms`, `bytes`, `sha256`, `block_times`, `line_times`.
  The app now reads `bytes` and `sha256`.
- `pubspec.yaml` lists no audio assets except the development tone
  `assets/audio_dev/placeholder_tone_not_a_chant.wav`.

### Inside the app

**Where a recording comes from.** `Recording` gets `path`, `bytes`,
`sha256` (the placeholder tone keeps its asset path and `placeholder:
true`). A sealed `RecordingLocation` has three kinds: a bundled asset, a
file on the device, a URL. One constant `audioBaseUrl =
'https://audio.intendable.us'` (overridable with
`--dart-define=NAMO_AUDIO_BASE_URL=` for trying an `r2.dev` address) and
`Uri recordingUrl(Recording)` live in `lib/audio/audio_host.dart`.

**The store.** `RecordingStore` (in `lib/audio/recording_store.dart`)
knows, for every recording in the library, one of: *downloaded*,
*downloading* (with progress 0–1), *waiting* (queued, including held back
by the Wi-Fi rule), *failed* (with a reason), *not downloaded*. It exposes
the whole picture as a stream, plus:

- `locationFor(Recording)` → the location to play, or null when the file
  is not on the device yet. On web it is always the URL; for the
  placeholder tone always the asset.
- `download(Recording)`: fetch this one now, on whatever connection
  (explicit request, so the Wi-Fi rule does not apply).
- `downloadAll()`: fetch everything missing now, on whatever connection.
- `removeAll()`: delete every downloaded file, cancel every transfer, and
  set the automatic download setting to **Off** (otherwise they would come
  straight back).
- Reacts to the setting (below). Automatic tasks carry the task's own
  `requiresWiFi` flag: true under Wi-Fi only, false under any connection.
  A change of setting cancels the automatic queue and enqueues it again
  with the new flag. Off cancels the automatic queue and enqueues nothing
  by itself. The package's global Wi-Fi rule stays at its default
  (`asSetByTask`), so an explicit download can always go ahead on the
  current connection. The app never reads the network state itself: it
  does not know whether the phone is on Wi-Fi, only what the setting says
  and whether bytes are moving.

Implementation on phones: `background_downloader`, one task per missing
recording in library order (so the 46 MB Samantha Pattana file comes
last). Automatic tasks are in group `auto`, explicit ones in group
`manual`, so Off cancels only the automatic queue. Each task: base
directory *application support*, directory `recordings/<topic folder>`,
file name as in `path`, `allowPause: true` (resumes across Android's
9-minute work cycles), `retries: 3`, `updates: statusAndProgress`, the
reading id in `metaData`. Configuration: exclude the files from iCloud
backup; fail a download that would leave under 100 MB free. The downloader
is reached through a thin interface of the few calls used, so the store's
logic is tested with a fake and the plugin is touched only in that one
adapter. On web the store is a trivial one: every recording is "available
at its URL".

**Start-up and reconciliation.** When the library has loaded, the store
starts the downloader, then for each recording: file present with the
listed size and recorded as verified → *downloaded*; an active task →
*downloading* or *waiting*; otherwise, if the setting is not Off, enqueue
it. The set of verified files, keyed by `path` and `sha256`, is kept in
the app's key-value store (key `namo.recordings.verified.v1`); a
right-sized file that is not in it is hashed again before it counts, and a
file whose `sha256` in the content has changed is fetched afresh. A person
who swipes the app away on iOS cancels its background transfers; the next
launch re-enqueues what is missing.

**Verification.** On a task's *complete*: size must equal `bytes`, then
SHA-256 (the `crypto` package, off the main thread) must equal `sha256`.
A mismatch deletes the file and marks the recording *failed* ("The
downloaded recording was damaged. It will be fetched again." — and it is
re-enqueued once automatically; a second failure stays failed until the
person tries again). A 404 is *failed* with "This recording is not on the
server yet."; other failures "Could not download the recording. Check your
connection."

**The player.** `ChantPlayer.load(Recording)` keeps its signature. The
`just_audio` player is given a locator (the store's `locationFor`) and
opens an asset, a file or a URL accordingly; a null location ends in
*failed* as a file that cannot be opened does today. Nothing else in the
reader's audio path changes.

### Reader (bottom bar, a reading with a recording)

- *Downloaded*, or on web: exactly today.
- *Downloading* (bytes moving): where the time or the position slider
  sits, a line "Downloading recording… 42%"; the play button shows its
  spinner and does nothing.
- *Waiting* (queued, nothing moving yet, whether for its turn or for
  Wi-Fi) or *not downloaded* (setting Off): a line "Waiting to download ·
  1.0 MB" or "Recording not downloaded · 1.0 MB" with a **Download**
  button. The button, and the play button, start an explicit download on
  the current connection and then play when the file arrives (the existing
  "play was wanted" logic). Sizes come from `bytes`: one decimal under
  10 MB ("1.0 MB"), whole above ("46 MB").
- *Failed*: the reason line and a **Try again** button.
- The reader itself, auto-scroll, previous/next and the text are untouched.

### Settings: a new "Recordings" group

Between Audio and Auto-scroll, icon `download_rounded`:

- Caption: "Recordings are fetched from the internet once and kept on this
  device. Texts never need a connection."
- Chooser "Download automatically": **Wi-Fi only** (default) · **Any
  connection** · **Off**. Stored in `AppSettings` as `autoDownload`
  (values `wifiOnly`, `any`, `off`), saved and read like the other
  settings, with the same fallback-to-default rule.
- Status line: "12 of 40 downloaded · 23 MB of 98 MB", with a thin
  progress bar while anything is downloading; "All 40 recordings
  downloaded · 98 MB" when complete; "3 could not be downloaded" appended
  when there are failures.
- Buttons: **Download all now** (shown until everything is downloaded;
  downloads on the current connection) and **Remove downloaded
  recordings** (confirmation: "Remove 98 MB of recordings from this
  device? They can be downloaded again." — removal also sets the chooser
  to Off).
- On web the group shows only "In the browser, recordings play from the
  internet when you press play." and no controls.
- About Namo: "Free. No ads. Texts work offline; recordings are downloaded
  once."

### Words elsewhere

- README: the second line becomes "It has no ads, no payments and no
  analytics; its only network use is fetching the chant recordings, once
  each, from the app's own host." Tooling sections point at `hosted/` and
  the sync tool; the web-build note stays true (CanvasKit bundled).
- Sources page, with the recording credits: "The recordings are fetched
  from the app's own storage (audio.intendable.us), not from the sources'
  sites."
- Release checklist: create bucket and custom domain; set CORS; keep the
  bucket private until the recording permissions are confirmed; run
  `--upload` then `--verify-full`; on a phone over Wi-Fi: fresh install,
  Settings shows progress; turn Wi-Fi off mid-way and on again, it
  resumes; airplane mode: texts open, an undownloaded recording shows the
  Download row, a downloaded one plays; web: play streams.

### Platform configuration

- Android: `<uses-permission android:name="android.permission.INTERNET" />`.
  No notification permission (no notifications).
- iOS: no change (HTTPS; the package handles background sessions).
- Web: no change in the app; the CORS policy is on the bucket.

### Tests

- Store logic with a fake downloader: reconciliation (present / active /
  missing), the three settings and their transitions, verification pass
  and fail on real temporary files, the one automatic retry, `removeAll`
  turning the setting Off, library order of the queue.
- Widget tests: the Settings group in each state and on web; the reader's
  download row, progress, failure, play-after-download, and today's
  behaviour for a downloaded recording, driven by a fake store.
- Quality tests: the bundle has no file under `assets/audio/` and still
  has the development tone; every recording in the real content has
  `path` starting `audio/`, `bytes` and a 64-hex `sha256`; the two
  existing bundle-count tests become these.
- Tool tests: `tools/test_sync_hosted_audio.py`; the existing build-tool
  tests updated for `path` and `hosted/`.
- The project's whole check list keeps passing (`flutter test`, `flutter
  analyze`, every `--check`, the glyph checks, the web build).

### Size, for the record

Android arm64 package about 148 → about 50 MB; universal APK 184 → about
86 MB; web deployment 98 MB smaller. Measured after the build.

## Left to the builder

- The exact shape of the thin downloader interface and its fake.
- How hashing is moved off the main thread (`compute` or an isolate).
- Reusing the existing chooser and progress widgets for the new group.
- Whether to cap concurrent transfers (the package's holding queue) or
  leave the platform defaults.
- The sync tool's exact `wrangler` arguments and its handling of a
  missing `npx`.

## Open with the owner

Defaults taken on 2026-11-16 so the build could start: the names below are
used as proposed (`audioBaseUrl` and the sync tool's constants are the only
places to change them); the bucket stays private until the owner confirms
the recording permissions; creating the bucket and uploading are the owner's
steps in the release checklist.

- When the bucket may go public: now (the same 40 files are already in
  the public GitHub repository) or only once the recording permissions
  are confirmed; and whether the 39 pirith files may go up before the
  Samantha Pattana one. Until the bucket is reachable, no phone build of
  this branch can play a recording; the web build streams from the same
  address.
- The host name `audio.intendable.us` and the bucket name `namo-audio`.
- Creating the bucket, custom domain and CORS policy in the Cloudflare
  dashboard, and running the upload; the app build does not depend on it,
  but playback on phones does.
