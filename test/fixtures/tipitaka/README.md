# Tripitaka test vectors

Copied from https://github.com/pathnirvana/tipitaka.lk at commit 974bd904457d27d427264aa777717057145c15f8 (2026-11-10), licence CC BY-ND 4.0.

- `markup_cases.json`: `shared/markup-cases.json`, copied unchanged.
- `beautify_cases.json`: from `e2e/legacy/goldens/beautify.json`: the first 400 items with
  `lang` pali and the first 40 with `lang` sinh, as `{lang, text, out}` where `out` is the
  item's `out["00"]` (the source's output with both optional letter settings off).

Regenerate with `python -I -X utf8 tools/sync_tipitaka.py . --fixtures <clone>`.
