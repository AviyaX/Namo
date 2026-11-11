# Namo

Namo is a free, offline Buddhist prayer book for Android, iOS and the web, built from one Flutter code base.
It has no ads, no payments, no analytics and makes no network requests.

## What is in it

The first reading is **Buddha Wandanawa** (බුද්ධ වන්දනාව), in Pali, Sinhala and English.

- Home shows one picture card for each category. A card for a category with one reading opens the reader straight away; otherwise it opens the Library with that category open.
- The Library lists the categories. Tapping one opens its numbered sections in place, on the same page.
- The reader remembers where you were, can scroll by itself, and keeps the screen on while it scrolls or a recording plays.

### My flows

A flow is your own chanting order: sections chosen from the readings, in the order you chant them, under a name you give it. You make and edit flows under "My flows" in the Library; they also show on Home under "Your flows", and open in the reader like any reading.
A flow keeps only which sections it holds (a reading id and a section id for each), never the text, so the readings themselves never change. Flows are saved on the device only, under the key `namo.flows.v1`, next to the settings, bookmarks and reading places.

## Sources

The Sources page in the app credits each of these:

- namo.lk: sections 1–17.
- The paritha.org booklet, compiled by Devapriya and Shyamali from the Piruwana Poth Wahanse: sections 18–19.
- The "Vandana" booklet of Mahamevnawa Bhavana Asapuwa, Markham, Ontario: part of the English.
- "Daily Buddha Vandana", prepared by Cynthia Gunawardana, Yasodhara Dhamma School, Sri Lankarama Maha Viharaya, Ellen Grove, Brisbane: the rest of the English.
- The Home card picture: made for this app by its owner with an AI image tool (a generated picture, not a photograph). Every picture is recorded in `docs/pictures.md`.

Namo is not made by, or connected with, namo.lk.

The verse text reaches the app only through `tools/build_content.py`, which reads `content/extracted/*.json` and writes `assets/content/namaskaraya_to_pin_dima.json`.
The English for sections 1–6 is prose from a narrow-column PDF, so the build re-sets it as sentences (line breaks and joining spaces only; it fails if any other character would change). English that is verse keeps the translator's line breaks.

## Pirith content

The Pirith topic (39 readings with recordings) reaches the app only through `tools/build_pirith.py`, which reads `content/extracted/pitaka_lk_pirith.json` and writes `assets/content/pirith.json` and `content/pirith_names.md`.

- Rebuild: `python -I -X utf8 tools/build_pirith.py .`
- Check it is up to date (also checks each bundled recording is the downloaded original): `python -I -X utf8 tools/build_pirith.py . --check`
- Import the recordings: `python -I -X utf8 tools/build_pirith.py . --import-audio <audio_dir>`, where `<audio_dir>` is the folder of downloaded originals; it copies them into `assets/audio/pirith/`.
- The downloaded originals are not in git. They live only in the main checkout's `source_material/pitaka_lk_pirith/audio`; the 39 recordings that ship are the ones in `assets/audio/pirith/`.
- Tests: `python -I -X utf8 tools/test_build_pirith.py`. The glyph check (`python -I -X utf8 tools/check_ui_glyphs.py .`) also covers every pirith name.
- Before publishing, read `docs/release-checklist.md`.

## Samantha Pattana content

The Samantha Pattana Dharma Wandanawa topic (an Introduction and the Vandana, with one recording) reaches the app in three steps, each with a tracked file in `content/extracted/`.

- Extract the text from the converted PDF pages: `python -I -X utf8 tools/build_samantha_patthana.py . --extract <source_folder>` writes `content/extracted/samantha_patthana.json`.
- Time every Pali line in the recording from its automatic captions (timing data only, never bundled): `python -I -X utf8 tools/time_samantha_patthana.py . <captions.json3>` writes `content/extracted/samantha_patthana_times.json` and `content/samantha_patthana_timing_report.md`.
- Build: `python -I -X utf8 tools/build_samantha_patthana.py .` writes `assets/content/samantha_patthana.json` from those two files.
- Check it is up to date (also checks the bundled recording's size and SHA-256 and that no other file is in `assets/audio/samantha_patthana/`): `python -I -X utf8 tools/build_samantha_patthana.py . --check`
- Import the recording: `python -I -X utf8 tools/build_samantha_patthana.py . --import-audio <audio_dir>`, where `<audio_dir>` holds `hYXyO3o7Iac.m4a`; it refuses a file of the wrong size or checksum and copies it byte for byte into `assets/audio/samantha_patthana/`.
- The originals (PDF, conversion, recording, captions) are not in git. They live only in the main checkout's `source_material/samantha_patthana/`; the card picture `assets/pictures/samantha_patthana.jpg` is a copy of `design/card_images/stupa_dusk.jpg`.
- Tests: `python -I -X utf8 tools/test_build_samantha_patthana.py` and `python -I -X utf8 tools/test_time_samantha_patthana.py`. The glyph check (`python -I -X utf8 tools/check_ui_glyphs.py .`) also covers this topic's names.

## Docs

- `docs/superpowers/specs/`: the owner's spec and the design.
- `docs/superpowers/plans/`: the plan for the first release.
- `docs/release-checklist.md`: what must be true before the app is published.
- `docs/pictures.md`: where each picture comes from and its licence.

## Commands

- Tests: `flutter test`.
- Content check: `python -I -X utf8 tools/build_content.py . --check` (without `--check` it rebuilds the content file). Its tests: `python -I -X utf8 tools/test_build_content.py`.
- Web build: `flutter build web --no-web-resources-cdn`. This bundles the drawing engine (CanvasKit) with the app, so nothing is fetched from the internet.

The Dart package and folder are still named `buddhist_gatha`.
