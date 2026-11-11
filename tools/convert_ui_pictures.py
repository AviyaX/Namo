"""Convert the owner's UI pictures (PNG) to the bundled JPEGs.

Usage: python -I -X utf8 tools/convert_ui_pictures.py SRC_DIR DEST_DIR
"""
import hashlib
import sys
from pathlib import Path

from PIL import Image

NAMES = [
    "hero_dark",
    "hero_light",
    "header_dark",
    "header_light",
    "buddha_wandanawa",
    "pirith",
]
MAX_SIDE = 1600


def main(argv):
    if len(argv) != 3:
        print("usage: convert_ui_pictures.py SRC_DIR DEST_DIR", file=sys.stderr)
        return 2
    src, dest = Path(argv[1]), Path(argv[2])
    missing = [n + ".png" for n in NAMES if not (src / (n + ".png")).is_file()]
    if missing:
        print("missing source file: " + ", ".join(missing), file=sys.stderr)
        return 1
    dest.mkdir(parents=True, exist_ok=True)
    for name in NAMES:
        with Image.open(src / (name + ".png")) as im:
            im = im.convert("RGB")
            longest = max(im.size)
            if longest > MAX_SIDE:
                scale = MAX_SIDE / longest
                im = im.resize(
                    (max(1, round(im.width * scale)), max(1, round(im.height * scale))),
                    Image.LANCZOS,
                )
            out = dest / (name + ".jpg")
            im.save(out, "JPEG", quality=85, progressive=True)
            data = out.read_bytes()
            print(
                f"{name}.jpg {im.width} x {im.height} {len(data)} bytes "
                f"SHA-1 {hashlib.sha1(data).hexdigest()}"
            )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
