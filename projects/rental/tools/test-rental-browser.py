"""Smoke-test every Rental route using the local Center host.

Set LAOO_RENTAL_TEST_PASSWORD in the environment. Screenshots are written to
projects/rental/test-artifacts and should be removed after review.
"""

import os
from pathlib import Path

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "test-artifacts"
ROUTES = (
    "settings",
    "items",
    "availability",
    "bookings",
    "payments",
    "handover",
    "returns",
    "settlements",
    "history",
    "dashboard",
)


def main() -> None:
    password = os.environ["LAOO_RENTAL_TEST_PASSWORD"]
    ARTIFACTS.mkdir(exist_ok=True)
    errors: list[str] = []
    api_failures: list[str] = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            executable_path=r"C:\Program Files\Google\Chrome\Application\chrome.exe",
            headless=True,
        )
        page = browser.new_page(viewport={"width": 1440, "height": 900})
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on(
            "response",
            lambda response: api_failures.append(
                f"{response.status} {response.url}"
            )
            if "/api/company/rental/" in response.url and response.status >= 400
            else None,
        )
        page.goto("http://127.0.0.1:8080/#/login", wait_until="domcontentloaded")
        page.wait_for_timeout(28000)
        page.mouse.click(650, 387)
        page.keyboard.insert_text("c111")
        page.mouse.click(650, 470)
        page.keyboard.insert_text(password)
        page.mouse.click(720, 565)
        page.wait_for_url("**/company/my-intranet", timeout=30000)
        print("LOGIN=PASS")
        for route in ROUTES:
            page.evaluate(
                "route => window.location.hash = '#/company/rental-' + route",
                route,
            )
            page.wait_for_timeout(3000)
            if not page.url.endswith(f"/company/rental-{route}"):
                raise AssertionError(f"Route did not open: {route}: {page.url}")
            page.screenshot(path=str(ARTIFACTS / f"rental-{route}-1440.png"))
            print(f"ROUTE_{route.upper()}=OPEN")
        page.evaluate("window.location.hash = '#/company/rental-items'")
        page.wait_for_timeout(2000)
        page.mouse.click(1100, 100)
        page.wait_for_timeout(2000)
        page.screenshot(path=str(ARTIFACTS / "rental-item-popup-1440.png"))
        print("ITEM_POPUP=CAPTURED")
        page.keyboard.press("Escape")
        for width in (1024, 768, 430, 360):
            page.set_viewport_size({"width": width, "height": 780})
            page.wait_for_timeout(700)
            page.screenshot(path=str(ARTIFACTS / f"rental-item-popup-{width}.png"))
            print(f"POPUP_{width}=CAPTURED")
        browser.close()
    if errors or api_failures:
        print(f"PAGE_ERRORS={errors}")
        print(f"RENTAL_API_FAILURES={api_failures}")
        raise AssertionError("Browser smoke test found an error")
    print("BROWSER_SMOKE=PASS")


if __name__ == "__main__":
    main()
