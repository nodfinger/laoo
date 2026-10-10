# LAOO_RENTAL — DEMO flow evidence

Date: 2026-10-09 (Asia/Bangkok)
Run ID: `RN_20261009_DEMO`
Database: `DBTDLaooService`; Company: `DEMO`; User: `c111`

## Result

- Center API Release build: passed, 0 warnings/errors. API health: HTTP 200 on port 5080.
- Flutter analyze: `projects/rental` and root integration files passed with no issues.
- Browser: login and all 10 routes `60001–60010` opened without page error or Rental API failure on port 8080.
- Browser popup inspected at 1440, 1024, 768, 430, and 360 px; ComboBox overflow was fixed.
- API actions metadata: 10/10 menus returned HTTP 200 with the expected ScreenType and permissions.
- Fixture SQL applied twice successfully, with no duplicate test item, warehouse, or entitlement.

## Persisted sample data

| Case | Booking | Result |
|---|---:|---|
| Serial rental, split rent payment, two-stage return, damage, partial deposit refund | 1 | CLOSED |
| Unpaid cancellation | 2 | CANCELLED |
| Cancellation after configured cutoff rejected | 3 | RESERVED |
| Paid cancellation with rent/deposit reversal | 4 | CANCELLED |
| Expired unpaid hold rejects payment and releases availability | 5 | RESERVED (expired) |
| Quantity rental, zero deposit, damage greater than deposit, additional payment | 6 | CLOSED |
| Simultaneous overlapping reservations: one succeeds, one HTTP 409 | 7 | RESERVED |
| Actual-clock late return: one hour late fee, additional payment | 8 | CLOSED |

Current Rental rows in DEMO: 3 rental items across 2 branches, 8 bookings
(3 CLOSED, 2 CANCELLED, 3 RESERVED), 3 stock transfers, 13 payment-ledger
entries, 25 private attachments, and 2 serial assignments. The quantity
item is `RN-DEMO-QTY`; the two sample warehouses start with
`RENTAL-RN261009-`.

## Verified API cases

- Settings and master: read/update permission metadata, item creation,
  branch filtering, quantity/serial stock transfers, inventory availability,
  and rejection of item deactivation/deletion while referenced.
- Reservations: company customer validation, booking idempotency, overlapping
  stock conflict, concurrent double-book prevention, and price snapshot after
  the master rate changes.
- Payment/handover: partial/full rent and deposit, receipt data, missing
  signatures/photo rejection, serial lookup, successful handover, repeat
  handover rejection, and no handover without full payment.
- Return/settlement: partial and final return, damage, over-return rejection,
  real-time late fee, deduction approval, additional payment required before
  close, positive and zero deposit refund, and repeat refund behavior.
- Cancellation: unpaid and fully paid, refund ledger entries, cutoff
  enforcement, and cancellation rejection after handover.
- Security and file validation: unauthenticated HTTP 401, unauthorized branch
  HTTP 403, unknown record/menu HTTP 404, invalid PDF upload and mismatched
  image bytes HTTP 400, and failed serial-transfer rollback preserving stock.
- History, pagination, dashboard, private attachment download, and Thai
  branch/customer/status presentation.

## Limits of this run

- No second-Company credential was available for an actual cross-Company
  runtime test; source guards are Company-scoped, but this case is not claimed
  as an executed acceptance test.
- Actual printer output, physical USB/Bluetooth barcode scanner, and
  handwritten signature quality were not hardware-tested. In-browser PDF
  printing was not exercised; receipt-data API returned HTTP 200.
- Browser automation opened every route and the add-item popup. API tests
  exercised saves and state changes; automated mouse/keyboard form submission
  on every Flutter screen was not performed.

## Re-run

Apply fixture files with `tools/test-data/Laoo.TestDataRunner`, then run
`projects/rental/tools/test-rental-flow.ps1` and
`projects/rental/tools/test-rental-late.ps1` with the DEMO test password.
For browser smoke, set `LAOO_RENTAL_TEST_PASSWORD` and run
`projects/rental/tools/test-rental-browser.py` while the Center API and
Flutter web server are available at ports 5080/8080.
