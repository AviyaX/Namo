"""Look at how the downloaded namo.lk articles are structured (before parsing them).

Usage: python -I namo_inspect.py <raw_dir> <out_txt> [slug]
"""
import collections
import json
import os
import re
import sys


def main() -> None:
    root, out_path = sys.argv[1], sys.argv[2]
    slug = sys.argv[3] if len(sys.argv) > 3 else "buddha-puja"
    idx = json.load(open(os.path.join(root, "index.json"), encoding="utf-8"))
    out = []
    for it in idx["items"]:
        out.append(f"{it['kind']:5s} {it['slug']:45s} | {it['title']} | chars={it['content_chars']} | cats={it['categories']}")
    all_classes = collections.Counter()
    for it in idx["items"]:
        rec = json.load(open(os.path.join(root, it["file"]), encoding="utf-8"))
        html = rec["content"]["rendered"]
        all_classes.update(re.findall(r'class="([^"]+)"', html))
    out.append("\n--- classes across all items ---")
    for k, v in all_classes.most_common(40):
        out.append(f"{v:6d}  {k}")
    rec = json.load(open(os.path.join(root, "posts", f"{slug}.json"), encoding="utf-8"))
    html = rec["content"]["rendered"]
    out.append(f"\n--- tags in {slug} ---")
    out.append(str(collections.Counter(re.findall(r"<([a-zA-Z0-9]+)", html)).most_common(20)))
    out.append(f"\n--- first 3500 chars of {slug} ---")
    out.append(html[:3500])
    out.append(f"\n--- chars 9000-10500 of {slug} ---")
    out.append(html[9000:10500])
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out))
    print("written", out_path)


if __name__ == "__main__":
    main()
