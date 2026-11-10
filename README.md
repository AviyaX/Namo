# Namo

Namo is a free, offline Buddhist prayer book for Android, iOS and the web, built from one Flutter code base.
It has no ads, no payments, no analytics and makes no network requests.

## What is in it

The first reading is **Buddha Wandanawa** (බුද්ධ වන්දනාව), in Pali, Sinhala and English.

- Home shows one picture card for each category. A card for a category with one reading opens the reader straight away; otherwise it opens the Library with that category open.
- The Library lists the categories. Tapping one opens its numbered sections in place, on the same page.
- The reader remembers where you were, can scroll by itself, and keeps the screen on while it scrolls or a recording plays.

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

## Docs

- `docs/superpowers/specs/`: the owner's spec and the design.
- `docs/superpowers/plans/`: the plan for the first release.
- `docs/pictures.md`: where each picture comes from and its licence.

## Commands

- Tests: `flutter test`.
- Content check: `python -I -X utf8 tools/build_content.py . --check` (without `--check` it rebuilds the content file). Its tests: `python -I -X utf8 tools/test_build_content.py`.
- Web build: `flutter build web --no-web-resources-cdn`. This bundles the drawing engine (CanvasKit) with the app, so nothing is fetched from the internet.

The Dart package and folder are still named `buddhist_gatha`.
