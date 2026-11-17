# Namo

Namo is a free Buddhist prayer book for Android, iOS and the web, built from one Flutter code base; the texts work offline.
It has no ads, no payments and no analytics; its only network use is fetching the chant recordings, once each, from the app's own host.

## What is in it

The first reading is **Buddha Wandanawa** (බුද්ධ වන්දනාව), 33 sections in Pali, Sinhala and English; Roman Pali is stored for search.

- Home shows one picture card for each category. A card for a category with one reading opens the reader straight away; otherwise it opens the Library with that category open.
- The Library lists the categories. Tapping one opens its numbered sections in place, on the same page.
- The reader remembers where you were, can scroll by itself, and keeps the screen on while it scrolls or a recording plays.

### My flows

A flow is your own chanting order: sections chosen from the readings, in the order you chant them, under a name you give it. You make and edit flows under "My flows" in the Library; they also show on Home under "Your flows", and open in the reader like any reading.
A flow keeps only which sections it holds (a reading id and a section id for each), never the text, so the readings themselves never change. Flows are saved on the device only, under the key `namo.flows.v1`, next to the settings, bookmarks and reading places.

## Sources

The Sources page in the app credits each of these:

- namo.lk: the first verses of sections 2–7 and sections 9–19.
- The paritha.org booklet, compiled by Devapriya and Shyamali from the Piruwana Poth Wahanse: sections 20 and 22, and the Sinhala of three verses in 8 and one in 23.
- Shanthi Vihara, Nottingham, "Evening Puja and Chanting" booklet (supplied by the owner): the Pali, Roman Pali and English of sections 1, 8, 21 and 23–33, verses 2–5 of sections 5–7, three English lines in 19 and 22, and the Roman Pali of the other sections.
- The "Vandana" booklet of Mahamevnawa Bhavana Asapuwa, Markham, Ontario: part of the English.
- "Daily Buddha Vandana", prepared by Cynthia Gunawardana, Yasodhara Dhamma School, Sri Lankarama Maha Viharaya, Ellen Grove, Brisbane: the rest of the English.
- pitaka.lk (pathnirvana): the Unicode text of the 23 books of Ven. Rerukane Chandawimala Maha Nahimi. The books and their covers are published by the Sri Chandawimala Dhamma Treatises Preservation Board, Pokunuwita (rerukanemahanahimi.lk).
- The Home card picture: made for this app by its owner with an AI image tool (a generated picture, not a photograph). Every picture is recorded in `docs/pictures.md`.

Namo is not made by, or connected with, namo.lk, pitaka.lk, Shanthi Vihara or the Sri Chandawimala Dhamma Treatises Preservation Board.

The verse text reaches the app only through `tools/build_content.py`, which reads `content/extracted/*.json` and writes `assets/content/namaskaraya_to_pin_dima.json`.
The English for sections 2–7 is prose from a narrow-column PDF, so the build re-sets it as sentences (line breaks and joining spaces only; it fails if any other character would change). The Nottingham booklet's English on its printed pages 17–34 is re-set the same way where a line breaks mid-sentence. English that is verse keeps the translator's line breaks.

## Pirith content

The Pirith topic (39 readings with recordings) reaches the app only through `tools/build_pirith.py`, which reads `content/extracted/pitaka_lk_pirith.json` and writes `assets/content/pirith.json` and `content/pirith_names.md`.

- Rebuild: `python -I -X utf8 tools/build_pirith.py .`
- Check it is up to date (also checks each recording under `hosted/audio/pirith/` is the downloaded original): `python -I -X utf8 tools/build_pirith.py . --check`
- Import the recordings: `python -I -X utf8 tools/build_pirith.py . --import-audio <audio_dir>`, where `<audio_dir>` is the folder of downloaded originals; it copies them into `hosted/audio/pirith/`.
- The downloaded originals are not in git. They live only in the main checkout's `source_material/pitaka_lk_pirith/audio`; the 39 recordings that ship are the ones in `hosted/audio/pirith/`.
- Tests: `python -I -X utf8 tools/test_build_pirith.py`. The glyph check (`python -I -X utf8 tools/check_ui_glyphs.py .`) also covers every pirith name.
- Before publishing, read `docs/release-checklist.md`.

## Samantha Pattana content

The Samantha Pattana Dharma Wandanawa topic (an Introduction and the Vandana, with one recording) reaches the app in three steps, each with a tracked file in `content/extracted/`.

- Extract the text from the converted PDF pages: `python -I -X utf8 tools/build_samantha_patthana.py . --extract <source_folder>` writes `content/extracted/samantha_patthana.json`.
- Time every Pali line in the recording from its automatic captions (timing data only, never bundled): `python -I -X utf8 tools/time_samantha_patthana.py . <captions.json3>` writes `content/extracted/samantha_patthana_times.json` and `content/samantha_patthana_timing_report.md`.
- Build: `python -I -X utf8 tools/build_samantha_patthana.py .` writes `assets/content/samantha_patthana.json` from those two files.
- Check it is up to date (also checks the bundled recording's size and SHA-256 and that no other file is in `hosted/audio/samantha_patthana/`): `python -I -X utf8 tools/build_samantha_patthana.py . --check`
- Import the recording: `python -I -X utf8 tools/build_samantha_patthana.py . --import-audio <audio_dir>`, where `<audio_dir>` holds `hYXyO3o7Iac.m4a`; it refuses a file of the wrong size or checksum and copies it byte for byte into `hosted/audio/samantha_patthana/`.
- The originals (PDF, conversion, recording, captions) are not in git. They live only in the main checkout's `source_material/samantha_patthana/`; the card picture `assets/pictures/samantha_patthana.jpg` is a copy of `design/card_images/stupa_dusk.jpg`.
- Tests: `python -I -X utf8 tools/test_build_samantha_patthana.py` and `python -I -X utf8 tools/test_time_samantha_patthana.py`. The glyph check (`python -I -X utf8 tools/check_ui_glyphs.py .`) also covers this topic's names.

## Tripitaka

- Where it comes from: the Buddha Jayanti Tripitaka Pali text and its Sinhala translation, as published by tipitaka.lk (github.com/pathnirvana/tipitaka.lk).
- Licence: Creative Commons Attribution-NoDerivatives 4.0 International, so the text is included unchanged.
- Namo is not connected to tipitaka.lk; errors in the text are reported to path.nirvana@gmail.com so they can be corrected at the source.
- One-time setup of the source clone (needs the network; `source_material/` is never committed):
  `git clone --filter=blob:none --sparse https://github.com/pathnirvana/tipitaka.lk.git source_material/tipitaka_lk/repo` then
  `git -C source_material/tipitaka_lk/repo sparse-checkout set public/static/text public/static/data shared e2e/legacy/goldens`.
  `--fetch` only pulls in an existing clone; with none it prints these commands and stops.
- Update from the source: `python -I -X utf8 tools/sync_tipitaka.py . --fetch`. Verify that the bundled text matches it: `python -I -X utf8 tools/sync_tipitaka.py . --check`.
- Glyph report: `python -I -X utf8 tools/check_tipitaka_glyphs.py .`
- Tool tests: `python -I -X utf8 tools/test_sync_tipitaka.py` and `python -I -X utf8 tools/test_check_tipitaka_glyphs.py`.
- The text is never edited here. Joining Pali letters happens only while drawing.
- The only display change besides joining: U+05F4 (used in an-4 as a closing quote; no font draws it) is shown as a plain quote mark. The stored text is unchanged, and the slip has been reported to tipitaka.lk.

## Books

- Where it comes from: the 23 books of Ven. Rerukane Chandawimala Maha Nahimi as Unicode text published by pitaka.lk (pathnirvana), with the publisher's covers from rerukanemahanahimi.lk. The books and their covers are published by the Sri Chandawimala Dhamma Treatises Preservation Board, Pokunuwita.
- Licence: none is stated by pitaka.lk or the Board, so the terms are kept: the text is included unchanged, the Sources page credits both, Namo is not connected with either, and errors are to be reported to the publisher or to pitaka.lk. Do not publish the app or push the repository to a public place until permission is confirmed (see `docs/release-checklist.md`).
- The cache: `--fetch` keeps every downloaded page in `source_material/pitaka_lk_books/<book>/` (never committed) and downloads only what is missing (User-Agent `namo-app-build/1.0`, a pause between requests). Delete a book's folder to fetch it again.
- Update from the source: `python -I -X utf8 tools/sync_books.py . --fetch` writes `assets/books/<book>.json.gz` and `assets/books/index.json`, then runs the check. `--survey` (no network) counts every tag and class in the cached pages. Check the bundled books: `python -I -X utf8 tools/sync_books.py . --check`. Verify that their text matches the cache, character for character with white space removed: `python -I -X utf8 tools/sync_books.py . --verify-cache` (no network; it reads the cached pages with a collector of its own, not the parser that made the books, prints one line per page that differs and a summary, and exits 1 on any difference).
- Covers and pictures: `python -I -X utf8 tools/sync_books.py . --covers` downloads the covers into `assets/books/covers/`; `--pictures` downloads the pictures inside the books and bundles them into `assets/books/pictures/` when they are small enough. Pillow (PIL) is needed only when a cover is a JPEG or wider than 400 px, or a picture is wider than 800 px; otherwise the files are copied as served.
- Glyph checks: `python -I -X utf8 tools/check_ui_glyphs.py .` and `python -I -X utf8 tools/check_tipitaka_glyphs.py .`.
- Tool tests: `python -I -X utf8 tools/test_sync_books.py`.
- The text is never edited here. No-break spaces in the source are kept as text. The one deliberate omission is the footnote back-link arrow at the end of each footnote.
- Size: the books gzipped are 3,342,287 bytes (22,262,879 unpacked); the whole `assets/books/` folder is 5,525,562 bytes, of which the pictures are 744,808. The arm64 split APK went from 53,975,660 bytes to 59,570,823 bytes (5,595,163 more).

## Docs

- `docs/superpowers/specs/`: the owner's spec and the design.
- `docs/superpowers/plans/`: the plan for the first release.
- `docs/release-checklist.md`: what must be true before the app is published.
- `docs/pictures.md`: where each picture comes from and its licence, including the book covers and the pictures inside the books.

## Hosting the recordings

The recordings are not in the app. They are uploaded to the owner's Cloudflare R2 bucket and served by a small Worker (`cloudflare/audio-worker/`), and after install the app fetches them by itself (on Wi-Fi unless the person changes the setting) and keeps them on the device; a recording that has not arrived yet can be fetched from its reader. The folder `hosted/` mirrors the bucket; see `hosted/README.md`.

- Check, offline: `python -I -X utf8 tools/sync_hosted_audio.py . --check`
- Print the upload commands: `python -I -X utf8 tools/sync_hosted_audio.py . --plan`
- Upload (after `npx wrangler login`): `python -I -X utf8 tools/sync_hosted_audio.py . --upload`
- Verify headers: `python -I -X utf8 tools/sync_hosted_audio.py . --verify [--base-url URL]`
- Verify by download and checksum: `python -I -X utf8 tools/sync_hosted_audio.py . --verify-full [--base-url URL]`

## Commands

- Tests: `flutter test`.
- Content check: `python -I -X utf8 tools/build_content.py . --check` (without `--check` it rebuilds the content file). Its tests: `python -I -X utf8 tools/test_build_content.py`.
- Nottingham booklet extractor (only if the booklet PDF changes): `python -I -X utf8 tools/extract_nottingham_booklet.py source_material/evening_puja_nottingham/evening_puja_and_chanting.pdf content/extracted/nottingham_booklet.json content/review/05_evening_puja_nottingham.md`. Its tests: `python -I -X utf8 tools/test_extract_nottingham_booklet.py`.
- Books check: `python -I -X utf8 tools/sync_books.py . --check`. Its tests: `python -I -X utf8 tools/test_sync_books.py`.
- Hosted audio check: `python -I -X utf8 tools/sync_hosted_audio.py . --check`. Its tests: `python -I -X utf8 tools/test_sync_hosted_audio.py`.
- Web build: `flutter build web --no-web-resources-cdn`. This bundles the drawing engine (CanvasKit) with the app, so the engine itself is never fetched from the internet; only the recordings are.

The Dart package and folder are still named `buddhist_gatha`.
