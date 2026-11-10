"""Inspect a source PDF: metadata, fonts, and raw extracted text per page.

Usage: python -I inspect_pdf.py <pdf_path> <out_txt_path>

Writes a UTF-8 report so Sinhala text is not mangled by the console.
Nothing here alters the text: it is a faithful dump of what the PDF contains.
"""
import sys

import fitz  # PyMuPDF


def main() -> None:
    pdf_path, out_path = sys.argv[1], sys.argv[2]
    doc = fitz.open(pdf_path)
    lines = []
    lines.append(f"FILE: {pdf_path}")
    lines.append(f"PAGES: {doc.page_count}")
    lines.append(f"METADATA: {doc.metadata}")
    lines.append(f"ENCRYPTED: {doc.is_encrypted}")

    fonts_seen = {}
    for pno in range(doc.page_count):
        for f in doc.get_page_fonts(pno):
            # (xref, ext, type, basefont, name, encoding)
            key = (f[3], f[2], f[5])
            fonts_seen.setdefault(key, []).append(pno + 1)
    lines.append("")
    lines.append("FONTS (basefont, type, encoding) -> pages")
    for key, pages in sorted(fonts_seen.items()):
        lines.append(f"  {key} -> {pages[0]}..{pages[-1]} ({len(pages)} pages)")

    lines.append("")
    for pno in range(doc.page_count):
        page = doc[pno]
        text = page.get_text("text")
        images = page.get_images(full=True)
        lines.append("=" * 70)
        lines.append(
            f"PAGE {pno + 1}  chars={len(text)}  images={len(images)}  "
            f"size={page.rect.width:.0f}x{page.rect.height:.0f}"
        )
        lines.append("=" * 70)
        lines.append(text.rstrip())
        lines.append("")

    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print(f"wrote {out_path}: {doc.page_count} pages")


if __name__ == "__main__":
    main()
