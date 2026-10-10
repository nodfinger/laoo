"""Smoke test all Booking routes on the local Center host.

Set LAOO_BOOKING_TEST_PASSWORD before running. Screenshots are local test artifacts.
"""

import os
from pathlib import Path

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "test-artifacts"
ROUTES = (
    "settings", "services", "providers", "resources", "members",
    "promotions", "calendar", "usage", "member-history", "dashboard",
)
BASE_URL = os.environ.get("LAOO_BOOKING_TEST_BASE_URL", "http://127.0.0.1:8080")


def main() -> None:
    password = os.environ["LAOO_BOOKING_TEST_PASSWORD"]
    ARTIFACTS.mkdir(exist_ok=True)
    errors: list[str] = []
    overflows: list[str] = []
    api_failures: list[str] = []
    nav_events: list[str] = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            executable_path=r"C:\Program Files\Google\Chrome\Application\chrome.exe",
            headless=True,
        )
        page = browser.new_page(viewport={"width": 1440, "height": 900})
        page.on("pageerror", lambda error: errors.append(f"{page.url}: {error}: {error.stack}"))
        page.on("console", lambda message: overflows.append(
            f"{page.url}: {message.text}"
        ) if "A RenderFlex overflowed" in message.text else None)
        def record_navigation(response):
            if "/api/navigation/menus" not in response.url:
                return
            try:
                groups = response.json()
                codes = [item.get("menuCode") for group in groups for item in group.get("items", [])]
                nav_events.append(f"{response.status} total={len(codes)} booking={sum(str(code).startswith('61') for code in codes)}")
            except Exception as error:
                nav_events.append(f"{response.status} parse_error={error}")

        page.on("response", record_navigation)
        page.on(
            "response",
            lambda response: api_failures.append(
                f"{response.status} {response.url}"
            ) if "/api/company/booking/" in response.url and response.status >= 400 else None,
        )
        page.goto(f"{BASE_URL}/#/booking/member", wait_until="domcontentloaded")
        page.wait_for_timeout(28000)
        if not page.url.endswith("/booking/member"):
            raise AssertionError(f"Member portal redirected: {page.url}")
        page.screenshot(path=str(ARTIFACTS / "booking-member-portal-1440.png"))
        for width in (1024, 768, 430):
            page.set_viewport_size({"width": width, "height": 780})
            page.wait_for_timeout(350)
        page.set_viewport_size({"width": 360, "height": 780})
        page.wait_for_timeout(500)
        page.screenshot(path=str(ARTIFACTS / "booking-member-portal-360.png"))
        page.set_viewport_size({"width": 1440, "height": 900})
        print("MEMBER_PORTAL=OPEN")
        page.goto(f"{BASE_URL}/#/login", wait_until="domcontentloaded")
        page.wait_for_timeout(28000)
        page.screenshot(path=str(ARTIFACTS / "booking-login.png"))
        page.mouse.click(650, 387)
        page.keyboard.insert_text("c111")
        page.mouse.click(650, 470)
        page.keyboard.insert_text(password)
        page.mouse.click(720, 565)
        page.wait_for_url("**/company/my-intranet", timeout=30000)
        print("LOGIN=PASS")
        page.wait_for_timeout(1500)
        errors.clear()  # Ignore startup errors from unrelated home widgets.
        for route in ROUTES:
            page.evaluate("route => window.location.hash = '#/company/booking-' + route", route)
            page.wait_for_timeout(2500)
            if not page.url.endswith(f"/company/booking-{route}"):
                page.screenshot(path=str(ARTIFACTS / "booking-route-failed.png"))
                print(f"NAV_EVENTS={nav_events} PAGE_ERRORS={errors} API_FAILURES={api_failures}")
                raise AssertionError(f"Route did not open: {route}: {page.url}")
            page.screenshot(path=str(ARTIFACTS / f"booking-{route}-1440.png"))
            print(f"ROUTE_{route.upper()}=OPEN")
            for width in (1024, 768, 430, 360):
                page.set_viewport_size({"width": width, "height": 780})
                page.wait_for_timeout(800)
                if width == 360:
                    page.screenshot(path=str(ARTIFACTS / f"booking-{route}-360.png"))
            page.set_viewport_size({"width": 1440, "height": 900})
            page.wait_for_timeout(500)
            if errors:
                print(f"PAGE_ERRORS={errors}")
                raise AssertionError(f"Flutter error on {route}")
        browser.close()
    if errors or api_failures or overflows:
        print(f"PAGE_ERRORS={errors}")
        print(f"BOOKING_API_FAILURES={api_failures}")
        print(f"BOOKING_OVERFLOWS={overflows}")
        raise AssertionError("Browser smoke test found an error")
    print("BROWSER_SMOKE=PASS widths=1440,1024,768,430,360")


if __name__ == "__main__":
    main()
