"""Run the DEMO market booking flow in real Chrome (credentials via environment)."""

import os
from playwright.sync_api import sync_playwright


def cancel_latest(page):
    page.get_by_text("ยกเลิก", exact=True).first.click(timeout=10000)
    page.locator("textarea").last.fill("ทดสอบ Browser flow MK_20261009")
    page.get_by_text("ยืนยันยกเลิก").click(timeout=10000)
    page.get_by_text("A04 ว่าง").wait_for(timeout=15000)


def main():
    username = os.environ["LAOO_MARKET_TEST_USER"]
    password = os.environ["LAOO_MARKET_TEST_PASSWORD"]
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path=r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        )
        page = browser.new_page(viewport={"width": 1440, "height": 900})
        page.on("pageerror", lambda error: print("BROWSER_ERROR", str(error)[:500], flush=True))
        page.goto("http://localhost:8080/", timeout=45000)
        page.locator("flt-semantics-placeholder").wait_for(timeout=30000)
        page.locator("flt-semantics-placeholder").evaluate("element => element.click()")
        page.get_by_text("เข้าสู่ระบบ").click(timeout=15000)
        page.locator("input").nth(0).fill(username)
        page.locator("input").nth(1).fill(password)
        page.wait_for_timeout(350)
        if page.locator("input").nth(1).input_value() != password:
            page.locator("input").nth(1).fill(password)
        page.locator("input").nth(1).press("Tab")
        assert page.locator("input").nth(1).input_value() == password
        page.get_by_text("เข้าสู่ระบบ").last.click()
        try:
            page.wait_for_url(lambda url: "#/company/" in url, timeout=45000)
        except Exception:
            print("LOGIN_STATE", page.url, page.locator("flt-semantics-host").inner_text()[-1200:], flush=True)
            raise
        print("LOGIN_OK", flush=True)
        page.goto("http://localhost:8080/#/company/market-stalls", timeout=45000)
        page.wait_for_timeout(3500)
        screen = page.locator("flt-semantics-host").inner_text()
        assert "A01 ว่าง" in screen and "A02 จอง" in screen
        assert "A03 มีผู้เช่า" in screen and "B01 ปิด" in screen
        assert "B02 ปรับปรุง" in screen
        print("MAP_ALL_STATUSES_OK", flush=True)
        if "A04 จอง" in screen:
            cancel_latest(page)
        page.get_by_text("A04 ว่าง").click(timeout=15000)
        page.get_by_text("ผู้ค้า *").wait_for(timeout=10000)
        page.get_by_text("ผู้ค้า *").click()
        page.wait_for_timeout(500)
        page.mouse.click(620, 380)
        page.get_by_text("ผู้ค้า * ผู้ค้าเก่า ตัวอย่างตลาด").wait_for(timeout=10000)
        page.get_by_text("จอง", exact=True).last.click(timeout=10000)
        page.get_by_text("ปิด", exact=True).first.wait_for(timeout=15000)
        page.get_by_text("ปิด", exact=True).first.click(timeout=10000)
        page.get_by_text("A04 จอง ผู้ค้าเก่า ตัวอย่างตลาด").wait_for(timeout=15000)
        print("BOOKING_UI_OK", flush=True)
        cancel_latest(page)
        print("CANCEL_UI_OK", flush=True)
        for width in (430, 360):
            page.set_viewport_size({"width": width, "height": 800})
            page.wait_for_timeout(650)
            page.get_by_text("A04 ว่าง").wait_for(timeout=10000)
            print(f"MOBILE_{width}_MAP_OK", flush=True)
        browser.close()


if __name__ == "__main__":
    main()
