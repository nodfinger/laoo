"""Browser checks for the isolated OCR HTML draft, never for production OCR/API."""
import json
import tempfile
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

root = Path(__file__).resolve().parents[2]
url = (root / "docs/drafts/business-card-ocr-draft.html").as_uri()
artifacts = Path(tempfile.mkdtemp(prefix="laoo-ocr-draft-"))
results = []
errors = []


def check(name, ok):
    assert ok, name
    results.append(name)


def no_overflow(page, label):
    check(label, page.evaluate("document.documentElement.scrollWidth <= innerWidth"))


def nav(page, target):
    if page.viewport_size["width"] < 900:
        page.locator("#menu").click()
    page.locator('[data-page="' + target + '"]').click()


def read_sample(page, scenario="thai"):
    page.locator("#scenario").select_option(scenario)
    page.locator("#analyze").click()
    if scenario not in ("empty", "timeout", "error"):
        expect(page.locator('#reviewForm [name="name"]')).to_be_enabled()
    else:
        expect(page.locator("#toast.error")).to_be_visible()


with sync_playwright() as p:
    browser = p.chromium.launch(channel="chrome", headless=True)
    context = browser.new_context(viewport={"width": 1440, "height": 1000})
    page = context.new_page()
    page.on("pageerror", lambda error: errors.append(str(error)))
    requests = []
    page.on("request", lambda req: requests.append(req.url))
    page.goto(url)
    page.evaluate("document.fonts.ready")
    check("Thai asset font loaded", page.evaluate("document.fonts.check('14px NotoSansThai')"))
    for width in (1440, 1024, 768, 430, 360):
        page.set_viewport_size({"width": width, "height": 1000 if width > 768 else 820})
        nav(page, "scan")
        read_sample(page)
        no_overflow(page, f"OCR review no overflow {width}")
        if width in (1440, 430):
            page.screenshot(path=str(artifacts / f"ocr-review-{width}.png"), full_page=True)
        for target in ("contacts", "customers", "visitors", "settings"):
            nav(page, target)
            no_overflow(page, f"{target} no overflow {width}")
            if target != "settings":
                expect(page.locator(".pagination")).to_be_visible()
                page.locator("#add").click()
                dialog = page.locator("#dialog")
                expect(dialog).to_be_visible()
                box = dialog.bounding_box()
                check(f"{target} popup width {width}", box["width"] <= 480 and box["x"] >= 24)
                foot = page.locator(".dialog-foot").bounding_box()
                check(f"{target} footer in viewport {width}", foot["y"] + foot["height"] <= page.viewport_size["height"])
                check(f"{target} button 48px {width}", page.locator("#save").bounding_box()["height"] == 48)
                if width == 430 and target == "contacts":
                    page.screenshot(path=str(artifacts / "contact-popup-430.png"))
                page.locator("#cancel").click()
    page.set_viewport_size({"width": 1440, "height": 1000})
    nav(page, "contacts")
    page.locator("#favorite").click()
    expect(page.locator('[data-shortcut="contacts"]')).to_be_visible()
    check("Favorite immediately in shortcuts", True)
    page.locator("#next").click()
    expect(page.locator(".pagination")).to_contain_text("4-4")
    page.locator("#search").fill("NONEXISTENT")
    page.locator("#search").press("Enter")
    expect(page.locator(".pagination")).to_contain_text("0-0")
    page.locator("#clear").click()
    page.locator("#toggleView").click()
    expect(page.locator(".records")).to_be_visible()
    check("Pagination, Enter search, empty state, card toggle", True)
    page.locator("#add").click()
    page.locator('#dialog [name="name"]').fill("OCR-DEMO-New")
    page.locator("#save").click()
    expect(page.locator("#dialog")).to_be_visible()
    expect(page.locator('#dialog [name="name"]')).to_have_value("")
    page.locator("#cancel").click()
    check("Create clears form and stays open", True)
    nav(page, "scan")
    for target in ("contacts", "customers", "visitors"):
        read_sample(page, "bilingual")
        page.locator("#target").select_option(target)
        page.locator("#apply").click()
        expect(page.locator("#toast.error")).to_be_visible()
        check(target + " requires review confirmation", not page.locator("#dialog").is_visible())
        page.locator("#reviewed").check()
        page.locator("#apply").click()
        expect(page.locator("#dialog")).to_be_visible()
        expect(page.locator('#dialog [name="name"]')).to_have_value("ธนกร ใจดี")
        if target == "visitors":
            check("Visitor only supported fields", page.locator('#dialog [name="company"]').count() == 0)
        if target == "customers":
            check("Customer unsupported LINE omitted", page.locator('#dialog [name="line"]').count() == 0)
        page.locator("#cancel").click()
    read_sample(page)
    page.locator("#target").select_option("customers")
    page.locator("#slot").select_option("2")
    page.locator('[data-link="1"]').click()
    page.locator('#reviewForm [name="name"]').fill("ผู้ติดต่อคนที่สอง")
    page.locator("#reviewed").check()
    page.locator("#apply").click()
    page.locator("#save").click()
    expect(page.locator("#dialog")).not_to_be_visible()
    nav(page, "customers")
    page.locator('[data-edit="1"]:visible').click()
    expect(page.locator('#dialog [name="name"]')).to_have_value("ธนกร ใจดี")
    page.locator("#formSlot").select_option("2")
    expect(page.locator('#dialog [name="name"]')).to_have_value("ผู้ติดต่อคนที่สอง")
    page.locator("#cancel").click()
    check("Customer slot 2 preserves slot 1", True)
    nav(page, "scan")
    for scenario in ("english", "multi", "blur", "empty", "timeout", "error"):
        read_sample(page, scenario)
        check("Scenario " + scenario, True)
    nav(page, "settings")
    page.locator('[name="alert"]').fill("1")
    page.locator('#settingsForm button[type="submit"]').click()
    expect(page.locator("#toast")).not_to_be_visible(timeout=2500)
    page.locator('[name="enabled"]').uncheck()
    page.locator('#settingsForm button[type="submit"]').click()
    nav(page, "scan")
    expect(page.locator("#analyze")).to_be_disabled()
    check("TimeAlert and disabled OCR", True)
    for theme, expected in (("blue", "#245cb6"), ("purple", "#7053a3"), ("green", "#147d64")):
        page.locator("#theme").select_option(theme)
        check("Theme " + theme, page.evaluate("getComputedStyle(document.documentElement).getPropertyValue('--primary').trim()") == expected)
    nav(page, "settings")
    page.locator('[name="enabled"]').check()
    page.locator('#settingsForm button[type="submit"]').click()
    nav(page, "scan")
    read_sample(page)
    page.locator("#target").select_option("contacts")
    page.locator('[data-link="1"]').click()
    page.locator('#reviewForm [name="position"]').fill("ตำแหน่งใหม่")
    page.locator("#reviewed").check()
    page.locator("#apply").click()
    expect(page.locator("#dialogTitle")).to_have_text("ยืนยันข้อมูลที่จะเปลี่ยน")
    page.locator("#cancel").click()
    nav(page, "contacts")
    page.locator('[data-edit="1"]:visible').click()
    expect(page.locator('#dialog [name="position"]')).to_have_value("ผู้จัดการฝ่ายขาย")
    page.locator("#cancel").click()
    check("Cancel overwrite preserves original", True)
    nav(page, "scan")
    read_sample(page)
    page.locator("#rawTarget").select_option("line")
    page.locator("#rawLines button").first.click()
    expect(page.locator('#reviewForm [name="line"]')).to_have_value("ธนกร ใจดี")
    check("Assign original text to chosen field", True)
    page.locator("#imagePicker").set_input_files({"name": "bad.txt", "mimeType": "text/plain", "buffer": b"not an image"})
    expect(page.locator("#toast.error")).to_be_visible()
    check("Unsupported upload rejected", True)
    page.locator("#imagePicker").set_input_files({"name": "big.png", "mimeType": "image/png", "buffer": b"x" * (10 * 1024 * 1024 + 1)})
    expect(page.locator("#toast.error")).to_contain_text("รูปมีขนาดเกินกำหนด")
    check("Oversized upload rejected", True)
    page.locator("#imagePicker").set_input_files({"name": "sample.png", "mimeType": "image/png", "buffer": (artifacts / "contact-popup-430.png").read_bytes()})
    expect(page.locator(".uploaded")).to_be_visible()
    expect(page.locator("#apply")).to_be_disabled()
    check("New image invalidates previous result", True)
    page.set_viewport_size({"width": 1024, "height": 820})
    nav(page, "contacts")
    expect(page.locator(".tablebox")).not_to_be_visible()
    check("Card mode based on content width", True)
    page.keyboard.press("Tab")
    check("Keyboard focus", page.evaluate("document.activeElement !== document.body"))
    check("No remote dependencies / API requests", not any(u.startswith(("http:", "https:")) for u in requests))
    check("No JavaScript errors", not errors)
    browser.close()

print(json.dumps({"passed": len(results), "checks": results, "errors": errors, "screenshots": str(artifacts)}, ensure_ascii=False, indent=2))
