"""Download every text page namo.lk publishes, politely, and store the raw data.

Usage: python -I fetch_namo_lk.py <out_dir>

namo.lk is a WordPress site, so its public REST API returns each article as
clean JSON (title, date, link, rendered HTML). This script:
  - reads robots.txt first and skips anything it disallows
  - makes one request at a time with a pause between requests
  - saves what the site returned, unmodified, with the fetch date and URL

Output layout in <out_dir>:
  robots.txt
  resources_page.html         the https://namo.lk/resources/ page as served
  categories.json
  posts/<slug>.json           one file per article (raw API record)
  pages/<slug>.json           one file per WordPress page
  index.json                  list of everything fetched, with URLs and dates
"""
import datetime
import json
import os
import sys
import time
import urllib.error
import urllib.request
import urllib.robotparser

BASE = "https://namo.lk"
UA = "Mozilla/5.0 (compatible; gatha-content-research/1.0; one-off polite fetch)"
PAUSE_SECONDS = 1.5


def get(url: str, robots, retries: int = 4) -> bytes | None:
    if robots is not None and not robots.can_fetch(UA, url):
        print(f"SKIP (robots.txt disallows): {url}")
        return None
    last_err = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
            with urllib.request.urlopen(req, timeout=90) as resp:
                data = resp.read()
            time.sleep(PAUSE_SECONDS)
            return data
        except urllib.error.HTTPError as err:
            if err.code in (400, 404):
                return None  # past the last page, or not present
            last_err = err
        except Exception as err:  # network drop, timeout
            last_err = err
        time.sleep(3 + attempt * 4)
    print(f"FAILED after {retries} tries: {url} -> {last_err}")
    return None


def fetch_collection(kind: str, out_dir: str, robots, index: list) -> int:
    os.makedirs(os.path.join(out_dir, kind), exist_ok=True)
    total = 0
    page = 1
    while True:
        url = f"{BASE}/wp-json/wp/v2/{kind}?per_page=50&page={page}&orderby=date&order=asc"
        data = get(url, robots)
        if not data:
            break
        records = json.loads(data.decode("utf-8"))
        if not isinstance(records, list) or not records:
            break
        for rec in records:
            slug = rec.get("slug") or str(rec.get("id"))
            path = os.path.join(out_dir, kind, f"{slug}.json")
            with open(path, "w", encoding="utf-8") as fh:
                json.dump(rec, fh, ensure_ascii=False, indent=1)
            index.append({
                "kind": kind,
                "id": rec.get("id"),
                "slug": slug,
                "title": (rec.get("title") or {}).get("rendered"),
                "link": rec.get("link"),
                "date": rec.get("date"),
                "modified": rec.get("modified"),
                "categories": rec.get("categories"),
                "content_chars": len(((rec.get("content") or {}).get("rendered")) or ""),
                "file": f"{kind}/{slug}.json",
            })
            total += 1
        print(f"{kind}: page {page} -> {len(records)} records")
        if len(records) < 50:
            break
        page += 1
    return total


def main() -> None:
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)

    robots_bytes = get(f"{BASE}/robots.txt", None)
    robots = urllib.robotparser.RobotFileParser()
    if robots_bytes:
        with open(os.path.join(out_dir, "robots.txt"), "wb") as fh:
            fh.write(robots_bytes)
        robots.parse(robots_bytes.decode("utf-8", "replace").splitlines())
        print("robots.txt saved")
    else:
        robots = None
        print("no robots.txt returned")

    res = get(f"{BASE}/resources/", robots)
    if res:
        with open(os.path.join(out_dir, "resources_page.html"), "wb") as fh:
            fh.write(res)
        print(f"resources page saved ({len(res)} bytes)")

    cats = get(f"{BASE}/wp-json/wp/v2/categories?per_page=100", robots)
    if cats:
        with open(os.path.join(out_dir, "categories.json"), "wb") as fh:
            fh.write(cats)

    index: list = []
    n_posts = fetch_collection("posts", out_dir, robots, index)
    n_pages = fetch_collection("pages", out_dir, robots, index)

    with open(os.path.join(out_dir, "index.json"), "w", encoding="utf-8") as fh:
        json.dump({
            "source": BASE,
            "fetched_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
            "method": "WordPress REST API (wp-json/wp/v2), unmodified records",
            "reuse_terms_on_site": "none stated (no copyright, licence or terms page found on 2026-11-09)",
            "items": index,
        }, fh, ensure_ascii=False, indent=1)
    print(f"DONE posts={n_posts} pages={n_pages}")


if __name__ == "__main__":
    main()
