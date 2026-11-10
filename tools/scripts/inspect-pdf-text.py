"""Extract page-numbered PDF text locally for a manual quality check.

Install the local dependency into tools/local-python/pdf before running.
This script never invokes a model or makes a network request.
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "local-python" / "pdf"))

from pypdf import PdfReader  # noqa: E402


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("pdf", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    reader = PdfReader(str(args.pdf))
    pages = []
    for number, page in enumerate(reader.pages, 1):
        text = (page.extract_text() or "").strip()
        pages.append({"page": number, "text": text, "characters": len(text)})

    result = {
        "source_name": args.pdf.name,
        "sha256": hashlib.sha256(args.pdf.read_bytes()).hexdigest(),
        "page_count": len(pages),
        "pages": pages,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"pages={len(pages)}")
    for page in pages:
        thai = sum('\u0e00' <= char <= '\u0e7f' for char in page['text'])
        print(f"page={page['page']} characters={page['characters']} thai_characters={thai}")
    print(f"output={args.output}")


if __name__ == "__main__":
    main()
