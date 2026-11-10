"""Show which characters follow (and precede) given legacy characters in the PDF.

Usage: python -I fm_followers.py <pdf_path> <hex code points...>

Used to decide whether a ligature key such as J stands for a whole conjunct
(න්ද) or only its first half (න්, with the ද typed separately).
"""
import collections
import sys

import fitz


def main() -> None:
    doc = fitz.open(sys.argv[1])
    wanted = [chr(int(a, 16)) for a in sys.argv[2:]]
    after = {c: collections.Counter() for c in wanted}
    before = {c: collections.Counter() for c in wanted}
    samples = {c: [] for c in wanted}
    for page in doc:
        for block in page.get_text("rawdict")["blocks"]:
            if block.get("type") != 0:
                continue
            for line in block["lines"]:
                text = "".join(ch["c"] for span in line["spans"] if "FM" in span["font"] for ch in span["chars"])
                for i, c in enumerate(text):
                    if c in after:
                        after[c][text[i + 1] if i + 1 < len(text) else "<end>"] += 1
                        before[c][text[i - 1] if i > 0 else "<start>"] += 1
                        if len(samples[c]) < 6:
                            samples[c].append(text[max(0, i - 8):i + 9])
    for c in wanted:
        print(f"U+{ord(c):04X}:")
        print("  followed by:", {f"U+{ord(k):04X}" if len(k) == 1 else k: v for k, v in after[c].most_common(12)})
        print("  preceded by:", {f"U+{ord(k):04X}" if len(k) == 1 else k: v for k, v in before[c].most_common(8)})
        print("  samples:", [s.encode("unicode_escape").decode("ascii") for s in samples[c]])


if __name__ == "__main__":
    main()
