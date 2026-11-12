"""Pack the Tripitaka book files of tipitaka.lk into the app, and check them.

Usage (from anywhere; <project> is the project folder):
  python -I -X utf8 tools/sync_tipitaka.py <project> [--from <clone>] [--fetch]
                                           [--clone <path>] [--check]
                                           [--fixtures <clone>]

  --from <clone>   Pack the in-scope files of a local clone of
                   https://github.com/pathnirvana/tipitaka.lk into
                   <project>/assets/tipitaka/ (gzip of the source bytes,
                   level 9, mtime 0, no file name) and rewrite manifest.json.
                   Re-running on the same clone changes no byte.
  --fetch          `git pull --ff-only` in the clone (default
                   <project>/source_material/tipitaka_lk/repo, or --clone),
                   then as --from. Only git is run; nothing from the clone
                   is executed.
  --check          No network, no clone needed. Prints OK and exits 0, or one
                   line per problem and exits 1.
  --fixtures <c>   Copy the source's own test vectors into
                   <project>/test/fixtures/tipitaka/.

The text is never altered: the only transformation is gzip. Standard library
only. The clone is untrusted data: it is read, never run.
"""
import argparse
import collections
import gzip
import hashlib
import json
import pathlib
import subprocess
import sys

SOURCE_URL = "https://github.com/pathnirvana/tipitaka.lk"
LICENCE = "CC BY-ND 4.0"
FILE_PREFIXES = ("vp-", "dn-", "mn-", "sn-", "an-", "kn-", "ap-")
KEY_EXCLUDED = ("atta", "anya")
ROOT_ORDER = ("vp", "sp", "ap")
BODY_TYPES = ("paragraph", "gatha", "unindented")
BEAUTIFY_COUNTS = {"pali": 400, "sinh": 40}
DEFAULT_CLONE = pathlib.Path("source_material") / "tipitaka_lk" / "repo"


def assets_dir(project):
    return pathlib.Path(project) / "assets" / "tipitaka"


def pack_bytes(data):
    return gzip.compress(data, 9, mtime=0)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def in_scope_file(stem):
    return stem.startswith(FILE_PREFIXES)


def in_scope_key(key):
    return not key.startswith(KEY_EXCLUDED)


# ---------------------------------------------------------------- spans


class Analysis:
    def __init__(self):
        self.readings = 0
        self.parents_with_text = []
        self.ranges = {}  # file -> [(key, display start, display end)]
        self.problems = []


def _child_order(key):
    tail = key.rsplit("-", 1)[-1]
    return int(tail) if tail.isdigit() else 0


def tree_order(scope):
    """In-scope keys in depth-first tree order (children by trailing number)."""
    kids = collections.defaultdict(list)
    for key, node in scope.items():
        kids[node[4]].append(key)
    roots = [k for k in scope if scope[k][4] not in scope]
    roots.sort(key=lambda k: ROOT_ORDER.index(k) if k in ROOT_ORDER else len(ROOT_ORDER))
    order = []

    def walk(key):
        order.append(key)
        for child in sorted(kids.get(key, []), key=_child_order):
            walk(child)

    for root in roots:
        walk(root)
    return order, kids


def analyse(tree, books):
    """Apply the span rule. `books` maps a file name to its parsed JSON (it may
    load lazily); only the Pali entries are read."""
    result = Analysis()
    scope = {k: v for k, v in tree.items() if in_scope_key(k)}
    order, kids = tree_order(scope)
    if len(order) != len(scope):
        missing = sorted(set(scope) - set(order))
        result.problems.append("tree: %d node(s) not reachable from a root, e.g. %s" % (len(missing), missing[0]))
    rank = {k: i for i, k in enumerate(order)}
    by_file = collections.defaultdict(list)
    for key in scope:
        by_file[scope[key][5]].append(key)
    reading_keys = set()
    for name in sorted(by_file):
        keys = [k for k in by_file[name] if k in rank]
        if name not in books:
            for k in by_file[name]:
                result.problems.append("node %s names file %s, which is not shipped" % (k, name))
            continue
        flat = []
        offsets = []
        for pg in books[name]["pages"]:
            offsets.append(len(flat))
            flat.extend(pg["pali"]["entries"])
        pages = books[name]["pages"]
        placed = []
        for k in keys:
            page_index, entry_index = scope[k][3]
            if not (0 <= page_index < len(pages) and 0 <= entry_index < len(pages[page_index]["pali"]["entries"])):
                result.problems.append("node %s points at page %s entry %s, which does not exist in %s"
                                       % (k, page_index, entry_index, name))
                continue
            placed.append((page_index, entry_index, rank[k], k))
        placed.sort()
        keys = [p[3] for p in placed]
        pos = [offsets[p[0]] + p[1] for p in placed]
        rows = []
        previous_end = 0
        for i, key in enumerate(keys):
            end = pos[i + 1] if i + 1 < len(keys) else len(flat)
            span = flat[pos[i]:end]
            is_leaf = key not in kids
            has_text = any(e["type"] in BODY_TYPES and (e.get("text") or "").strip() for e in span)
            if is_leaf or has_text:
                rows.append((key, previous_end, end))
                previous_end = end
                reading_keys.add(key)
                if not is_leaf:
                    result.parents_with_text.append(key)
        result.ranges[name] = rows
        cursor = 0
        for key, start, end in rows:
            if start != cursor:
                result.problems.append("%s: reading %s does not follow on from the one before" % (name, key))
            cursor = end
        if cursor != len(flat):
            result.problems.append("%s: %d entr%s after the last reading belong to no reading"
                                   % (name, len(flat) - cursor, "y" if len(flat) - cursor == 1 else "ies"))
    result.readings = len(reading_keys)
    result.parents_with_text.sort(key=lambda k: rank[k])
    return result


# ---------------------------------------------------------------- pack


def git_head(clone):
    out = subprocess.run(["git", "-C", str(clone), "log", "-1", "--format=%H|%cs"],
                         capture_output=True, text=True, check=True).stdout.strip()
    commit, date = out.split("|")
    return commit, date


def source_files(clone):
    text = pathlib.Path(clone) / "public" / "static" / "text"
    return {p.name[:-5]: p for p in sorted(text.glob("*.json")) if in_scope_file(p.name[:-5])}


def pack(project, clone):
    clone = pathlib.Path(clone)
    out = assets_dir(project)
    text_out = out / "text"
    text_out.mkdir(parents=True, exist_ok=True)
    files = {}
    wanted = set()
    for name, path in source_files(clone).items():
        data = path.read_bytes()
        (text_out / (name + ".json.gz")).write_bytes(pack_bytes(data))
        wanted.add(name + ".json.gz")
        files["text/" + name] = {"sha256": sha256(data), "bytes": len(data)}
    for stale in text_out.iterdir():
        if stale.name not in wanted:
            stale.unlink()
    tree_bytes = (clone / "public" / "static" / "data" / "tree.json").read_bytes()
    (out / "tree.json.gz").write_bytes(pack_bytes(tree_bytes))
    files["tree"] = {"sha256": sha256(tree_bytes), "bytes": len(tree_bytes)}
    (out / "LICENSE.md").write_bytes((clone / "LICENSE.md").read_bytes())

    tree = json.loads(tree_bytes.decode("utf8"))
    books = _Books({n: ("src", p) for n, p in source_files(clone).items()})
    analysis = analyse(tree, books)
    if analysis.problems:
        for line in analysis.problems:
            print(line)
        raise SystemExit("the source does not satisfy the span rule; nothing adjusted")
    commit, date = git_head(clone)
    manifest = {
        "schema": 1,
        "source": SOURCE_URL,
        "commit": commit,
        "commitDate": date,
        "licence": LICENCE,
        "readings": analysis.readings,
        "parentsWithText": analysis.parents_with_text,
        "files": {k: files[k] for k in sorted(files)},
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n", encoding="utf8")
    print("packed %d book files, %d readings, %d parents with text (commit %s)"
          % (len(wanted), analysis.readings, len(analysis.parents_with_text), commit[:7]))


class _Books:
    """Mapping name -> parsed book, loading one file at a time (no cache)."""

    def __init__(self, sources):
        self._sources = sources

    def __contains__(self, name):
        return name in self._sources

    def __getitem__(self, name):
        kind, path = self._sources[name]
        data = path.read_bytes()
        if kind == "gz":
            data = gzip.decompress(data)
        return json.loads(data.decode("utf8"))


# ---------------------------------------------------------------- check


def check(project):
    problems = []
    out = assets_dir(project)
    try:
        manifest = json.loads((out / "manifest.json").read_text(encoding="utf8"))
        listed = manifest["files"]
    except (OSError, ValueError, KeyError) as exc:
        return ["manifest.json: cannot be read (%s)" % exc]

    shipped = {}
    text_dir = out / "text"
    if text_dir.is_dir():
        for p in sorted(text_dir.iterdir()):
            if p.name.endswith(".json.gz"):
                shipped["text/" + p.name[:-8]] = p
            else:
                problems.append("text/%s: unexpected file" % p.name)
    if (out / "tree.json.gz").is_file():
        shipped["tree"] = out / "tree.json.gz"
    for name in sorted(set(shipped) - set(listed)):
        problems.append("%s: shipped but not in the manifest" % name)
    for name in sorted(set(listed) - set(shipped)):
        problems.append("%s: in the manifest but not shipped" % name)
    if not (out / "LICENSE.md").is_file():
        problems.append("LICENSE.md: missing")

    for name in sorted(set(shipped) & set(listed)):
        try:
            data = gzip.decompress(shipped[name].read_bytes())
        except (OSError, EOFError) as exc:
            problems.append("%s: cannot be unpacked (%s)" % (name, exc))
            continue
        want = listed[name]
        if sha256(data) != want.get("sha256") or len(data) != want.get("bytes"):
            problems.append("%s: unpacked bytes differ from the manifest (sha256 or byte count)" % name)

    if "tree" in shipped:
        try:
            tree = json.loads(gzip.decompress(shipped["tree"].read_bytes()).decode("utf8"))
            books = _Books({n[5:]: ("gz", p) for n, p in shipped.items() if n.startswith("text/")})
            analysis = analyse(tree, books)
        except (OSError, EOFError, ValueError, KeyError, TypeError, IndexError) as exc:
            problems.append("analysis stopped: %s" % exc)
        else:
            problems.extend(analysis.problems)
            if analysis.readings != manifest.get("readings"):
                problems.append("readings: computed %d, manifest says %s" % (analysis.readings, manifest.get("readings")))
            if analysis.parents_with_text != manifest.get("parentsWithText"):
                problems.append("parentsWithText: computed list (%d) differs from the manifest's"
                                % len(analysis.parents_with_text))
            in_tree = {v[5] for k, v in tree.items() if in_scope_key(k)}
            for name in sorted(n[5:] for n in shipped if n.startswith("text/")):
                if name not in in_tree:
                    problems.append("text/%s: no tree node uses this file" % name)
    return problems


# ---------------------------------------------------------------- fixtures


def fixtures(project, clone):
    clone = pathlib.Path(clone)
    dest = pathlib.Path(project) / "test" / "fixtures" / "tipitaka"
    dest.mkdir(parents=True, exist_ok=True)
    (dest / "markup_cases.json").write_bytes((clone / "shared" / "markup-cases.json").read_bytes())
    items = json.loads((clone / "e2e" / "legacy" / "goldens" / "beautify.json").read_text(encoding="utf8"))
    chosen = []
    for lang, count in BEAUTIFY_COUNTS.items():
        chosen += [{"lang": lang, "text": i["text"], "out": i["out"]["00"]}
                   for i in [i for i in items if i.get("lang") == lang][:count]]
    (dest / "beautify_cases.json").write_text(json.dumps(chosen, indent=1, ensure_ascii=False) + "\n", encoding="utf8")
    commit, date = git_head(clone)
    (dest / "README.md").write_text(
        "# Tripitaka test vectors\n\n"
        "Copied from %s at commit %s (%s), licence %s.\n\n"
        "- `markup_cases.json`: `shared/markup-cases.json`, copied unchanged.\n"
        "- `beautify_cases.json`: from `e2e/legacy/goldens/beautify.json`: the first %d items with\n"
        "  `lang` pali and the first %d with `lang` sinh, as `{lang, text, out}` where `out` is the\n"
        "  item's `out[\"00\"]` (the source's output with both optional letter settings off).\n\n"
        "Regenerate with `python -I -X utf8 tools/sync_tipitaka.py . --fixtures <clone>`.\n"
        % (SOURCE_URL, commit, date, LICENCE, BEAUTIFY_COUNTS["pali"], BEAUTIFY_COUNTS["sinh"]),
        encoding="utf8")
    print("fixtures written to %s" % dest)


# ---------------------------------------------------------------- main


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("project")
    ap.add_argument("--from", dest="from_clone")
    ap.add_argument("--fetch", action="store_true")
    ap.add_argument("--clone", help="clone location for --fetch (default source_material/tipitaka_lk/repo)")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--fixtures", dest="fixtures_clone")
    args = ap.parse_args(argv)
    if not (args.from_clone or args.fetch or args.check or args.fixtures_clone):
        ap.error("give at least one of --from, --fetch, --check, --fixtures")
    project = pathlib.Path(args.project)
    source = args.from_clone
    if args.fetch:
        source = args.clone or str(project / DEFAULT_CLONE)
        subprocess.run(["git", "-C", source, "pull", "--ff-only"], check=True)
    if source:
        pack(project, source)
    if args.fixtures_clone:
        fixtures(project, args.fixtures_clone)
    if args.check:
        problems = check(project)
        if problems:
            for line in problems:
                print(line)
            return 1
        print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
