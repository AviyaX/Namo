# Namo

Namo is a free, offline Buddhist prayer book for Android, iOS and the web.
It has no ads, no payments, no analytics and makes no network requests.
The verses come from content prepared by the owner from namo.lk, read only
through `tools/build_content.py` from `content/extracted/*.json`.
The design and plan live in `.superpowers/` and `design/`.
Run the tests with `flutter test`.
Run the content check with `python -I -X utf8 tools/build_content.py . --check` (without `--check` it rebuilds `assets/content/namaskaraya_to_pin_dima.json`); its tests run with `python -I -X utf8 tools/test_build_content.py`.
Build the web app with `flutter build web --no-web-resources-cdn`. This bundles the drawing engine (CanvasKit) with the app, so nothing is fetched from the internet.
The Dart package and folder are still named `buddhist_gatha`.
