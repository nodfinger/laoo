"""Offline page-by-page PDF text extraction; scanned pages use local Tesseract."""
import io
import json
import os
import subprocess
import sys
import unicodedata

import pypdfium2 as pdfium


def remove_standalone_symbols(text):
    def keep(line):
        visible = line.strip().strip("\u200b\ufeff").strip()
        return not (len(visible) == 1 and unicodedata.category(visible).startswith(("P", "S")))

    return "\n".join(line for line in text.splitlines() if keep(line)).strip()


def main():
    tess_exe, tessdata = sys.argv[1:3]
    requested_page = int(sys.argv[3]) if len(sys.argv) > 3 else None
    data = sys.stdin.buffer.read(20 * 1024 * 1024 + 1)
    if not data or len(data) > 20 * 1024 * 1024:
        raise ValueError("invalid PDF size")
    pages = []
    with pdfium.PdfDocument(data) as document:
        if len(document) > 100:
            raise ValueError("PDF exceeds 100 pages")
        total_pages = len(document)
        if requested_page is not None and not 1 <= requested_page <= total_pages:
            raise ValueError("invalid page")
        indices = [requested_page - 1] if requested_page is not None else range(total_pages)
        for index in indices:
            page = document[index]
            try:
                textpage = page.get_textpage()
                try:
                    text = textpage.get_text_range().strip()
                finally:
                    textpage.close()
                used_ocr = len("".join(text.split())) < 10
                if used_ocr:
                    if not os.path.isfile(tess_exe):
                        raise RuntimeError("OCR engine unavailable")
                    width, height = page.get_size()
                    scale = min(1.5, (20_000_000 / max(1, width * height)) ** 0.5)
                    bitmap = page.render(scale=scale)
                    try:
                        image = bitmap.to_pil()
                        try:
                            buffer = io.BytesIO()
                            image.save(buffer, format="PNG")
                        finally:
                            image.close()
                    finally:
                        bitmap.close()
                    output = subprocess.run(
                        [tess_exe, "stdin", "stdout", "--tessdata-dir", tessdata,
                         "-l", "tha+eng", "--psm", "3"],
                        input=buffer.getvalue(), stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE, timeout=20, check=True,
                        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
                    )
                    text = output.stdout.decode("utf-8").strip()
                pages.append({"page": index + 1, "text": remove_standalone_symbols(text), "ocr": used_ocr})
            finally:
                page.close()
    sys.stdout.buffer.write(json.dumps({"pages": pages, "totalPages": total_pages}, ensure_ascii=False).encode("utf-8"))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        sys.stderr.write("PDF extraction failed: " + type(error).__name__)
        sys.exit(1)
