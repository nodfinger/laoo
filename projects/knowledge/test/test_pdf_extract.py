import io
import json
import os
import pathlib
import subprocess
import sys
import unittest

from PIL import Image, ImageDraw
import pypdfium2 as pdfium

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "packages/dotnet/Laoo.Knowledge.Module/knowledge_pdf_extract.py"
sys.path.insert(0, str(SCRIPT.parent))
from knowledge_pdf_extract import remove_standalone_symbols
TESSERACT = pathlib.Path(os.environ.get("KM_TESSERACT", r"C:\Program Files\Tesseract-OCR\tesseract.exe"))
TESSDATA = pathlib.Path(os.environ.get("KM_TESSDATA", r"C:\RYPIT\laoo_api\App_Data\tessdata"))


def text_pdf(content=None):
    if content is None:
        content = b"BT /F1 18 Tf 40 700 Td (Knowledge source text for testing.) Tj ET"
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        b"<< /Length %d >>\nstream\n" % len(content) + content + b"\nendstream",
    ]
    result = bytearray(b"%PDF-1.4\n")
    offsets = [0]
    for index, obj in enumerate(objects, 1):
        offsets.append(len(result))
        result.extend(b"%d 0 obj\n" % index + obj + b"\nendobj\n")
    start = len(result)
    result.extend(b"xref\n0 6\n0000000000 65535 f \n")
    for offset in offsets[1:]:
        result.extend(b"%010d 00000 n \n" % offset)
    result.extend(b"trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF" % start)
    return bytes(result)


class PdfExtractionTest(unittest.TestCase):
    def test_remove_only_standalone_symbols(self):
        source = "ข้อความ\n•\n  .  \n* ข้อความ\n1\nA\n§\n-42\n\u200b•\u200b\n!!"
        self.assertEqual(remove_standalone_symbols(source), "ข้อความ\n* ข้อความ\n1\nA\n-42\n!!")

    def read_pdf(self, data):
        result = subprocess.run([sys.executable, "-I", str(SCRIPT), str(TESSERACT), str(TESSDATA)], input=data, capture_output=True, timeout=90)
        self.assertEqual(result.returncode, 0, result.stderr.decode("utf-8", "replace"))
        return json.loads(result.stdout)

    def test_text_page_does_not_use_ocr(self):
        page = self.read_pdf(text_pdf())["pages"][0]
        self.assertFalse(page["ocr"])
        self.assertIn("Knowledge source text", page["text"])

    def test_pdf_text_drops_only_symbol_line(self):
        content = b"BT /F1 18 Tf 40 700 Td 24 TL (First line with text) Tj T* (.) Tj T* (2. Keep this item) Tj ET"
        page = self.read_pdf(text_pdf(content))["pages"][0]
        self.assertEqual(page["text"].splitlines(), ["First line with text", "2. Keep this item"])

    @unittest.skipUnless(TESSERACT.exists() and (TESSDATA / "eng.traineddata").exists(), "local OCR unavailable")
    def test_scanned_page_uses_ocr(self):
        image = Image.new("RGB", (1000, 500), "white")
        draw = ImageDraw.Draw(image)
        draw.text((60, 100), "DOCUMENT REFERENCE NUMBER 12345", fill="black", font_size=38)
        output = io.BytesIO()
        image.save(output, "PDF", resolution=150)
        page = self.read_pdf(output.getvalue())["pages"][0]
        self.assertTrue(page["ocr"])
        self.assertIn("DOCUMENT", page["text"].upper())

    def test_invalid_pdf_fails_without_output(self):
        result = subprocess.run([sys.executable, "-I", str(SCRIPT), str(TESSERACT), str(TESSDATA)], input=b"bad pdf", capture_output=True, timeout=30)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(result.stdout)

    @unittest.skipUnless(TESSERACT.exists() and (TESSDATA / "eng.traineddata").exists(), "local OCR unavailable")
    def test_mixed_pdf_uses_ocr_only_for_scanned_page(self):
        image = Image.new("RGB", (1000, 500), "white")
        ImageDraw.Draw(image).text((60, 100), "SCANNED DOCUMENT 12345", fill="black", font_size=38)
        scanned = io.BytesIO()
        image.save(scanned, "PDF", resolution=150)
        with pdfium.PdfDocument(text_pdf()) as text_doc, pdfium.PdfDocument(scanned.getvalue()) as scan_doc, pdfium.PdfDocument.new() as mixed:
            mixed.import_pages(text_doc)
            mixed.import_pages(scan_doc)
            output = io.BytesIO()
            mixed.save(output)
        pages = self.read_pdf(output.getvalue())["pages"]
        self.assertEqual([page["ocr"] for page in pages], [False, True])
        self.assertIn("Knowledge source text", pages[0]["text"])
        self.assertIn("SCANNED", pages[1]["text"].upper())
        result = subprocess.run([sys.executable, "-I", str(SCRIPT), str(TESSERACT), str(TESSDATA), "2"], input=output.getvalue(), capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr.decode("utf-8", "replace"))
        selected = json.loads(result.stdout)
        self.assertEqual(selected["totalPages"], 2)
        self.assertEqual([page["page"] for page in selected["pages"]], [2])
        self.assertTrue(selected["pages"][0]["ocr"])


if __name__ == "__main__":
    unittest.main()
