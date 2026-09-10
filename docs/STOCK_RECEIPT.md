# Core stock receipt (08005)

Menu metadata: 08005, รับสินค้าเข้าคลัง, ScreenType 4, project LAOO.
The reusable implementation remains under projects/service for compatibility; folder location does not change ownership.
Meeting is not part of this change.

## Workflow

- Header: document number (server generated), receipt date, warehouse, RECEIPT/OPENING, vendor, supplier reference, delivered by and remark.
- RECEIPT requires an active vendor in the current Company. OPENING allows no vendor.
- The vendor search shows active company vendors. Creating one uses the existing Core vendor popup and requires vendor CREATE permission.
- Detail: sequential ID, delete action, searchable item, unit, quantity, unit cost, calculated amount and serial progress.
- Below 900px, detail/list rows reflow into cards.
- Save validates header/details, then opens the serial popup if needed. Opening/closing the popup does not write anything.
- The popup collects factory serials (one per unit, Enter advances focus), or requests internally generated serials.
- Save document writes the entire draft atomically, returns its ID and actual serials, and leaves the popup open in a saved state.
- Returning to the form preserves values. Subsequent saves update the same ID; the save button is disabled during a request.
- Confirm is separate, requires EDIT, and is the only step that adds stock and item instances.
- Confirmation is serialized with receipt saves per Company; repeated/concurrent confirmation cannot add stock twice.

## API

Existing base: /api/company/stock-receipts.

- GET lookup additionally returns vendors and canCreateVendor.
- POST / PUT {id} additionally accept vendorID and deliveredBy.
- Each item accepts serialSourceCode: FACTORY (default for old clients) or INTERNAL.
- INTERNAL with an empty serials array generates one unique IS-prefixed GUID (34 characters) per unit on the server.
- INTERNAL with serials supplied is allowed only when those numbers were previously generated for the same document and item.
- Successful save returns stockReceiptID, receiptCode, statusCode, and items containing lineNo, itemID, serialSourceCode and serials (string array).
- GET {id} returns vendor ID/code/name snapshots, deliveredBy, and detail serialSourceCode/unitCode.
- Quantity/cost accept up to four decimal places; serial quantity must be integral.
- Limits: 500 lines and 2,000 serial units per document; serial length 1–200; no blank or duplicate serials.
- Duplicate checks cover both existing company item instances and active draft/confirmed receipt serials.
- Updates check permission for both old and selected warehouses. Company/Partner/User/menu permissions remain server-enforced.
- SQL errors are logged server-side; user responses contain safe message/description.

## Migration and compatibility

Run tools/scripts/run-migrations.ps1 -Module core after pulling main. The runner provides a transaction across GO batches, application lock, checksum and ledger.

20260910170000_LAOO_receipt_vendor_serial adds nullable VendorID, VendorCode, VendorName and DeliveredBy to TDIVStockReceipt, a Company+Vendor FK/index, and SerialSourceCode with default FACTORY to TDIVStockReceiptDetail.
Existing receipt header values, mappings, serials and stock are not rewritten.
Historical receipts without a vendor remain readable and retain the existing confirmation flow; editing a RECEIPT draft now requires selecting a vendor.
Schema migration must precede API deployment. Restart the rebuilt Core API and restart/rebuild the Core Flutter app; refreshing an old binary will not load the new code.

## Verification

Flutter regression tests: test/features/company/stock_receipt_test.dart and existing vendor tests.
Backend executable: tools/receipt-tests/ReceiptTests.csproj.
The backend suite creates a uniquely tagged vendor/product, exercises the actual controller and database, then deletes only captured fixture IDs in finally. It never changes an existing product's stock or user permissions.
Run this suite only against the authorized development database.

Verified on 2026-09-10: backend build (0 warnings/errors), 29 database/controller checks, and 9 Flutter receipt/vendor widget tests passed; analyzer reported no issues. Migration applied and its second execution was skipped by the ledger. Desktop/mobile sizing was checked with widget tests at 1100/390px, not an interactive browser session.
