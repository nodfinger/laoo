"""Real-browser Booking member login using a random DEMO fixture password."""

import json
import os
import secrets
from pathlib import Path
from urllib.request import Request, urlopen

from playwright.sync_api import sync_playwright


API = os.getenv("LAOO_BOOKING_TEST_API_URL", "http://127.0.0.1:5080")
WEB = os.getenv("LAOO_BOOKING_TEST_BASE_URL", "http://127.0.0.1:8080")
ARTIFACTS = Path(__file__).resolve().parents[1] / "test-artifacts"


def api(method: str, path: str, body=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = Request(
        API + path,
        data=json.dumps(body).encode() if body is not None else None,
        headers=headers,
        method=method,
    )
    with urlopen(request, timeout=30) as response:
        return json.load(response)


def main():
    staff_password = os.environ["LAOO_BOOKING_TEST_PASSWORD"]
    staff = api("POST", "/api/auth/login",
                {"username": "c111", "password": staff_password})
    staff_token = staff["accessToken"]
    members = api("GET", "/api/company/booking/members?page=1&pageSize=20",
                  token=staff_token)
    member = next(row for row in members["items"]
                  if row["code"] == "BK26_MEMBER")
    password = "B" + secrets.token_hex(16) + "a9!"
    next_password = "C" + secrets.token_hex(16) + "a9!"
    api("PUT", f"/api/company/booking/members/{member['id']}/credential",
        {"newPassword": password, "isActive": True}, staff_token)

    ARTIFACTS.mkdir(exist_ok=True)
    errors = []
    member_responses = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            executable_path=r"C:\Program Files\Google\Chrome\Application\chrome.exe",
            headless=True,
        )
        page = browser.new_page(viewport={"width": 360, "height": 780})
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("response", lambda response: member_responses.append(
            (response.url, response.status)
        ) if "/api/booking/member/" in response.url else None)
        page.goto(f"{WEB}/?v=20261009-booking-member-final#/booking/member",
                  wait_until="domcontentloaded")
        page.wait_for_timeout(28000)
        if not page.url.endswith("/booking/member"):
            raise AssertionError(f"Portal redirected: {page.url}")
        page.mouse.click(90, 207)
        page.keyboard.insert_text("DEMO")
        page.mouse.click(90, 278)
        page.keyboard.insert_text("BK26_MEMBER")
        page.mouse.click(90, 336)
        page.keyboard.insert_text(password)
        page.mouse.click(165, 400)
        page.wait_for_timeout(4000)
        page.screenshot(path=str(ARTIFACTS / "booking-member-after-login-360.png"))
        if any("/api/booking/member/history" in url
               for url, _ in member_responses):
            raise AssertionError("History loaded before mandatory password change")
        page.mouse.click(90, 300)
        page.keyboard.insert_text(next_password)
        page.mouse.click(165, 365)
        page.wait_for_timeout(3000)
        if not any("/api/booking/member/change-password" in url and status == 200
                   for url, status in member_responses):
            raise AssertionError(f"Password change failed: {member_responses}")
        page.mouse.click(90, 336)
        page.keyboard.insert_text(next_password)
        page.mouse.click(165, 400)
        page.wait_for_timeout(4000)
        page.screenshot(path=str(ARTIFACTS / "booking-member-history-360.png"))
        browser.close()
    if errors:
        raise AssertionError(f"Flutter page errors: {errors}")
    if not any("/api/booking/member/login" in url and status == 200
               for url, status in member_responses):
        raise AssertionError(f"Member login API did not pass: {member_responses}")
    if not any("/api/booking/member/me" in url and status == 200
               for url, status in member_responses):
        raise AssertionError(f"Member profile API did not pass: {member_responses}")
    if not any("/api/booking/member/history" in url and status == 200
               for url, status in member_responses):
        raise AssertionError(f"History did not load after password change: {member_responses}")
    print("BOOKING_MEMBER_BROWSER_PASS mobileLogin=200 change=200 history=200")


if __name__ == "__main__":
    main()
