"""Keeps hosted/ and the Cloudflare R2 bucket in step with the recordings the content names.

Reads every audio object (path, bytes, sha256) in assets/content/*.json. --check is
offline; --plan prints the upload commands; --upload runs them with npx wrangler;
--verify sends a HEAD request per recording; --verify-full downloads and hashes each.

  python -I -X utf8 tools/sync_hosted_audio.py <project_root> --check
  python -I -X utf8 tools/sync_hosted_audio.py <project_root> --plan
  python -I -X utf8 tools/sync_hosted_audio.py <project_root> --upload
  python -I -X utf8 tools/sync_hosted_audio.py <project_root> --verify [--base-url URL]
  python -I -X utf8 tools/sync_hosted_audio.py <project_root> --verify-full [--base-url URL]
"""
from __future__ import annotations

import hashlib
import json
import pathlib
import shlex
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

BASE_URL = "https://audio.intendable.us"
BUCKET = "namo-audio"
USER_AGENT = "namo-app-build/1.0"
CONTENT_TYPE = "audio/mp4"
CACHE_CONTROL = "public, max-age=31536000, immutable"
HOSTED = pathlib.Path("hosted")
CONTENT = pathlib.Path("assets/content")
ALLOWED_EXTRA = {"README.md"}  # the only non-recording file allowed under hosted/

USAGE = ("usage: python -I -X utf8 tools/sync_hosted_audio.py <project_root> "
         "[--check | --plan | --upload | --verify [--base-url URL] | --verify-full [--base-url URL]]")
HEX = set("0123456789abcdef")


class SyncError(Exception):
    pass


def recordings(root: pathlib.Path) -> list[dict]:
    """Every recording the content names, in content-file order: path, bytes, sha256, reading id."""
    found = []
    for file in sorted((root / CONTENT).glob("*.json")):
        try:
            data = json.loads(file.read_text(encoding="utf-8"))
        except (OSError, ValueError) as e:
            raise SyncError(f"cannot read {file.name}: {e}")
        for category in data.get("categories", []):
            for reading in category.get("readings", []):
                audio = reading.get("audio")
                if audio is None:
                    continue
                where = f"{file.name}: reading {reading.get('id')!r}"
                for key in ("path", "bytes", "sha256"):
                    if key not in audio:
                        raise SyncError(f"{where}: audio has no {key}")
                sha = audio["sha256"]
                if not (isinstance(sha, str) and len(sha) == 64 and set(sha) <= HEX):
                    raise SyncError(f"{where}: sha256 is not 64 hex characters")
                found.append({"path": audio["path"], "bytes": audio["bytes"],
                              "sha256": sha, "reading": reading["id"]})
    return found


def _sha256_of(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def check(root: pathlib.Path) -> str | None:
    """None when hosted/ holds exactly the named recordings, else the first problem."""
    items = recordings(root)
    for item in items:
        file = root / HOSTED / item["path"]
        if not file.is_file():
            return f"missing: hosted/{item['path']}"
        size = file.stat().st_size
        if size != item["bytes"]:
            return f"{item['path']} is {size} bytes, expected {item['bytes']}"
        actual = _sha256_of(file)
        if actual != item["sha256"]:
            return f"{item['path']} has checksum {actual}, expected {item['sha256']}"
    known = {item["path"] for item in items}
    base = root / HOSTED
    if base.is_dir():
        for rel in sorted(p.relative_to(base).as_posix() for p in base.rglob("*") if p.is_file()):
            if rel not in known and rel not in ALLOWED_EXTRA:
                return f"unexpected file in hosted/: {rel}"
    return None


def plan(root: pathlib.Path) -> list[list[str]]:
    return [["npx", "wrangler", "r2", "object", "put", f"{BUCKET}/{item['path']}",
             "--file", f"hosted/{item['path']}", "--content-type", CONTENT_TYPE,
             "--cache-control", CACHE_CONTROL, "--remote"] for item in recordings(root)]


def upload(root: pathlib.Path, run=subprocess.run) -> None:
    npx = shutil.which("npx")
    if npx is None:
        raise SyncError('npx was not found; install Node.js and run "npx wrangler login" once')
    for argv in plan(root):
        run([npx] + argv[1:], check=True, cwd=root)


def _request(url: str, method: str) -> urllib.request.Request:
    return urllib.request.Request(url, method=method, headers={"User-Agent": USER_AGENT})


def _url(base_url: str, item: dict) -> str:
    return base_url.rstrip("/") + "/" + item["path"]


def verify(root: pathlib.Path, base_url: str, opener=urllib.request.urlopen) -> list[str]:
    problems = []
    for item in recordings(root):
        url = _url(base_url, item)
        try:
            with opener(_request(url, "HEAD"), timeout=60) as response:
                status, headers = response.status, response.headers
        except urllib.error.HTTPError as e:
            problems.append(f"{url}: HTTP {e.code}")
            continue
        except OSError as e:
            problems.append(f"{url}: {e}")
            continue
        if not 200 <= status < 300:
            problems.append(f"{url}: HTTP {status}")
            continue
        length = headers.get("Content-Length")
        if length is None or str(length) != str(item["bytes"]):
            problems.append(f"{url}: Content-Length {length}, expected {item['bytes']}")
        ctype = headers.get("Content-Type")
        if ctype != CONTENT_TYPE:
            problems.append(f"{url}: Content-Type {ctype}, expected {CONTENT_TYPE}")
    return problems


def verify_full(root: pathlib.Path, base_url: str, opener=urllib.request.urlopen) -> list[str]:
    problems = []
    work = pathlib.Path(tempfile.mkdtemp())
    try:
        for n, item in enumerate(recordings(root)):
            url = _url(base_url, item)
            target = work / f"{n}.m4a"
            digest = hashlib.sha256()
            try:
                with opener(_request(url, "GET"), timeout=60) as response, target.open("wb") as out:
                    status = response.status
                    if 200 <= status < 300:
                        while True:
                            chunk = response.read(65536)
                            if not chunk:
                                break
                            digest.update(chunk)
                            out.write(chunk)
            except urllib.error.HTTPError as e:
                problems.append(f"{url}: HTTP {e.code}")
                continue
            except OSError as e:
                problems.append(f"{url}: {e}")
                continue
            if not 200 <= status < 300:
                problems.append(f"{url}: HTTP {status}")
            elif digest.hexdigest() != item["sha256"]:
                problems.append(f"{url}: checksum {digest.hexdigest()}, expected {item['sha256']}")
    finally:
        shutil.rmtree(work, ignore_errors=True)
    return problems


def main(argv: list[str]) -> int:
    args = list(argv)
    base_url = BASE_URL
    if "--base-url" in args:
        k = args.index("--base-url")
        if k + 1 >= len(args):
            print(USAGE, file=sys.stderr)
            return 2
        base_url = args[k + 1]
        del args[k:k + 2]
    modes = {"--check", "--plan", "--upload", "--verify", "--verify-full"}
    given = [a for a in args[1:] if a in modes]
    if len(args) != 2 or len(given) != 1:
        print(USAGE, file=sys.stderr)
        return 2
    root, mode = pathlib.Path(args[0]), given[0]
    try:
        if mode == "--check":
            problem = check(root)
            if problem:
                print(f"sync_hosted_audio: {problem}", file=sys.stderr)
                return 1
            print("hosted audio is up to date")
        elif mode == "--plan":
            for command in plan(root):
                print(shlex.join(command))
        elif mode == "--upload":
            upload(root)
        else:
            problems = (verify_full if mode == "--verify-full" else verify)(root, base_url)
            if problems:
                for p in problems:
                    print(p, file=sys.stderr)
                print(f"sync_hosted_audio: {len(problems)} problem(s) at {base_url}", file=sys.stderr)
                return 1
            print(f"all {len(recordings(root))} recordings verified at {base_url}")
    except (SyncError, subprocess.CalledProcessError) as e:
        print(f"sync_hosted_audio: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
