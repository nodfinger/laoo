# ระบบบริหารสต๊อก

> ค่าขนาดหน้าจอและ popup ในสเปกเดิมด้านล่างเป็นประวัติ UI ปัจจุบันให้อ่าน [my-ui](../standards/my-ui.md)

## ข้อกำหนดปัจจุบันและเจ้าของที่ต้องยึด

- Migration `20261107120000_LAOO_stock_project.sql` ย้ายสิทธิ์/เมนู `08001`–`08011` ไป `LAOO_STOCK` โดยไม่ย้ายข้อมูลธุรกิจ สเปกเก่าที่ระบุว่าเมนูเหล่านี้เป็น Core `LAOO` เป็นภาพ ณ ก่อน migration และ **ไม่ใช่ค่าปัจจุบันของ ProjectCode**
- `08001` ทะเบียนสินค้า: นโยบายการเข้าถึงโครงการ `ALL`/`SELECTED`; เมื่อเลือก `SELECTED` ต้องมี projectId อย่างน้อยหนึ่งค่า ค่าเริ่มต้นของ Group/Type ใช้กับช่องใหม่ที่ยังไม่แก้เท่านั้น ดูรายละเอียดด้านล่าง
- `08005` รับสินค้า: RECEIPT ต้องมีผู้ขายที่เปิดใช้งาน, OPENING ไม่บังคับ; บันทึก Draft และยืนยันแยกกัน การยืนยันเพิ่มสต๊อกครั้งเดียว พร้อมการตรวจ Serial และสิทธิ์คลังเดิม/ใหม่ รายละเอียดเพดานและ API อยู่ด้านล่าง
- `08007` ผู้ขาย: ค้นหารหัส/ชื่อ/เลขภาษี/โทรศัพท์; รหัสและชื่อบังคับ รหัสไม่ซ้ำใน Company; `RowVersion` ป้องกันแก้ไขทับ; การลบติด FK ต้องปฏิเสธ ดูรายละเอียดด้านล่าง
- `08008`–`08011`: migration ยืนยันว่ามีเมนู แต่ไม่พบ Route หรือสเปก Function ในการสำรวจนี้ จึงยังไม่กำหนดหน้าที่เอง

## พฤติกรรมที่พบในโค้ด / ความเชื่อมโยง

- Source ของบางหน้าสต๊อกอยู่ใน `projects/service` และ Core; ตำแหน่งไฟล์ไม่ใช่ ProjectCode ในทะเบียนปัจจุบัน
- การรับสินค้าอ้างผู้ขายและสินค้า; เอกสารขาย/ส่งของอ้างยอดสต๊อกและสินค้า โครงการที่เข้าถึงสินค้าไม่ได้ต้องถูกปฏิเสธในขั้นบันทึก

## ยังไม่ยืนยัน

- ต้องเทียบฐานข้อมูลที่ deploy จริงว่ารัน stock migration แล้วหรือยัง; repository อย่างเดียวไม่ยืนยันสถานะ production
- ชื่อ, ScreenType, Route, API และ Permission เฉพาะ `08008`–`08011` ต้องตรวจ DB/Controller เพิ่ม

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: ระบบบริหารสต๊อก
- โค้ดอาจอยู่ใน Core และหลายโมดูล; ดูแหล่งอ้างอิงรายเมนู
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `08001` | `companyProducts` | ไม่พบ | `LAOO_STOCK` | ไม่ระบุ | [`projects/service/lib/app/router/app_menu_route_registry.dart`](../../projects/service/lib/app/router/app_menu_route_registry.dart) |
| `08002` | `/inventory/items` | 3 | `LAOO_STOCK` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `08003` | `/inventory/usage` | 4 | `LAOO_STOCK` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `08004` | `/inventory/warehouses` | 1 | `LAOO_STOCK` | unspecified | [`projects/service/lib/features/service/service_route_contract.dart`](../../projects/service/lib/features/service/service_route_contract.dart) |
| `08005` | `/inventory/stock-receipts` | 4 | `LAOO_STOCK` | unspecified | [`projects/service/lib/features/service/service_route_contract.dart`](../../projects/service/lib/features/service/service_route_contract.dart) |
| `08006` | `/inventory/item-instances` | 3 | `LAOO_STOCK` | unspecified | [`projects/service/lib/features/service/service_route_contract.dart`](../../projects/service/lib/features/service/service_route_contract.dart) |
| `08007` | `companyVendors` | ไม่พบ | `LAOO_STOCK` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `08008` | `ไม่พบ Route` | ไม่พบ | `LAOO_STOCK` | ไม่ระบุ | `database/migrations/20261107120000_LAOO_stock_project.sql` (ไฟล์ migration ถูกลบหลังรันแล้ว; ตรวจประวัติ Git) |
| `08009` | `ไม่พบ Route` | ไม่พบ | `LAOO_STOCK` | ไม่ระบุ | `database/migrations/20261107120000_LAOO_stock_project.sql` (ไฟล์ migration ถูกลบหลังรันแล้ว; ตรวจประวัติ Git) |
| `08010` | `ไม่พบ Route` | ไม่พบ | `LAOO_STOCK` | ไม่ระบุ | `database/migrations/20261107120000_LAOO_stock_project.sql` (ไฟล์ migration ถูกลบหลังรันแล้ว; ตรวจประวัติ Git) |
| `08011` | `ไม่พบ Route` | ไม่พบ | `LAOO_STOCK` | ไม่ระบุ | `database/migrations/20261107120000_LAOO_stock_project.sql` (ไฟล์ migration ถูกลบหลังรันแล้ว; ตรวจประวัติ Git) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สเปก Function ที่ย้ายจาก `docs/STOCK_RECEIPT.md` (ข้อความ ProjectCode เดิมขัดกับ stock migration ใหม่; ดูข้อกำหนดปัจจุบันด้านบน)

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

## สเปก Function ที่ย้ายจาก `docs/VENDOR.md` (ข้อความ ProjectCode เดิมขัดกับ stock migration ใหม่; ดูข้อกำหนดปัจจุบันด้านบน)

# Core Vendor (08007)

Vendor belongs to Core LAOO, in menu group 08. ScreenType 1 uses the central
List/Card and 480px popup conventions, table typography 14px, and the approved
red delete confirmation from docs/standards/my-ui.md.

## Behavior

- Search explicitly by code/name/tax ID/telephone; filter status and entity type.
- Person and organization vendor types are supported. Person identity, customer
  records, login accounts and receipt integration are not created by this feature.
- Code/name are required. Code is unique within Company, including inactive rows.
- Popup save stays open and changes create to edit. A create-only user cannot
  update the created row after save. View-only users get a read-only popup.
- RowVersion protects update/delete from stale edits. Data returned from a save
  is the atomic SQL OUTPUT for that write.
- Delete is permanent with confirmation; FK references reject deletion. Disable
  a referenced vendor rather than removing it.

## API and ownership

- GET /api/company/vendors/actions returns VIEW/CREATE/EDIT/DELETE capabilities.
- GET /api/company/vendors supports search, isActive, entityTypeCode, page and
  pageSize (1–200); returns items, total, page, pageSize.
- GET /api/company/vendors/{id}, POST /api/company/vendors,
  PUT /api/company/vendors/{id}, DELETE /api/company/vendors/{id}?rowVersion=...
- Request fields: vendorCode, vendorName, entityTypeCode (PERSON/ORGANIZATION),
  taxID, address, telephone, email, contactName, contactTelephone, contactEmail,
  creditDays (0–3650), remark, isActive; rowVersion required for updates/deletes.
- TDAPVendor.CompanyID comes from session; CompanySetupID references the existing
  TDSTCompanySetUp.PKValue candidate key. Backend resolves it within Company/Partner.
- Every endpoint checks active user/Company/Partner, enabled Core entitlement,
  active menu, ScreenType and direct/role action permission. Admin bypass applies
  inside Company scope. No new permissions are automatically granted to ordinary users.

## Deployment and verification

Migration: 20260910150000_LAOO_vendor via tools/scripts/run-migrations.ps1 -Module core.
Legacy migration 20260909100000 used SHA256 of its UTF-16 migration ID plus :v1,
not the runner's UTF-8 normalized file hash. The approved reconciliation script
checks the legacy digest and schema under the migration application lock,
preserves the original ledger row as
20260909100000_LAOO_branch_warehouse_user_access_legacy_v1_checksum, then updates
only the original checksum. It does not change branch/warehouse business rows.

Backend regression: build tools/vendor-tests/VendorTests.csproj with a separate
output directory while the API is running; run VendorTests.dll with repository
root as argument. Actual controller writes run in an uncommitted TransactionScope.
UI regression: flutter test test/features/company/vendor/vendor_test.dart.

Restart Core API and reload Flutter after deployment. Refresh navigation/login
to see the new menu. Non-admin users need menu 08007 permission assigned first.

## สเปก Function ที่ย้ายจาก `docs/ITEM_PROJECT_DEFAULTS.md` (ข้อความ ProjectCode เดิมขัดกับ stock migration ใหม่; ดูข้อกำหนดปัจจุบันด้านบน)

# Core item project availability and classification defaults

## Implemented contract

- Menu 08001 remains ScreenType 1; one Company item master is maintained in Core.
- `projectAccess` is additive on item detail/upsert: `accessModeCode` is `ALL` or
  `SELECTED`, and `projectIds` contains distinct enabled Company project IDs.
  SELECTED requires at least one ID; ALL sends an empty list. Old clients omitting
  this property preserve existing policy. Missing policy means ALL, retaining
  legacy availability; it never grants user, branch or warehouse permissions.
- Item and project selections commit in the same transaction. Existing item,
  usage, stock and document data are not migrated or rewritten.
- `GET /api/company/items/project-options` returns enabled, active, unexpired
  Company projects. `GET /api/company/items?projectId=...` additionally filters
  item availability. The unfiltered endpoint remains the Company master list.
- `GET /api/company/items/classification-defaults?groupCode=...&typeCode=...`
  resolves TYPE before GROUP. `PUT` accepts scopeCode, classificationCode,
  itemKindCode, stockTrackingCode and usageCodes, and requires item EDIT.
  Defaults are Company-scoped and apply only to new untouched form values.
  Group/type master groups remain the existing 006/007; no master recoding occurs.
- The form uses a bounded 1100px popup, fixed bottom actions, 13px buttons and
  14px inputs. Details/notes share a panel. Successful creation changes to edit
  mode rather than clearing the form or creating another item on a second save.

## Deployment and authorization boundary

Migration `20260910120000_LAOO_item_project_defaults` runs through the existing
transactional, application-locked, checksum-ledger migration runner.

- ItemController uses a dedicated Core catalog guard. It validates the active
  user, Company, Partner, session Project, Company entitlement dates and user
  project membership. Each action also checks the mapped Core menu 08001,
  ScreenType and direct/role permissions. Company Admin bypass remains within
  the enabled Company/project scope. Core catalog access no longer requires a
  Service subscription.
- Sales, delivery, item/material and inventory workflows belong to Core
  (`LAOO` / ข้อมูลส่วนกลาง). Their API project guards and item availability
  checks use Core. The legacy `projects/service` source location does not
  establish business ownership. Service is not required for these workflows.
  Existing feature, menu, Company and warehouse permission guards remain.
- Quotation, preorder, delivery, tax invoice, stock receipt and stock issue
  lookups filter project availability. Saves, warehouse/serial allocation and
  stock confirmation revalidate inside the document transaction. Serial lists,
  history and location changes also enforce availability. Inactive or
  cross-company items are denied with HTTP 403 / `ITEM_PROJECT_DENIED`.
- Existing document reads and stock reversal paths retain their existing
  permissions; revoking availability must not prevent reversing a historical
  document. Product availability never grants warehouse or user permissions,
  and Company Admin does not bypass a product's selected-project policy.
- Meeting and other project consumers are not integrated in this change. No
  Meeting source, configuration or data is changed. Do not advertise enforcement
  across every project until each consumer is integrated.

## Verification

- Backend build; Flutter item form widget tests at 390px and 1100px.
- New defaults, preserved edit values, project serialization, repeated-save ID.
- `tools/scripts/test-item-project-defaults.ps1` exercises SQL cases in a
  transaction that is always rolled back; no fixture data persists.
- `tools/scripts/test-item-project-enforcement.ps1` executes the production SQL
  predicates with rollback-only fixtures: Core without Service, action guards,
  Company/Partner boundaries, membership, active status and ALL/SELECTED policy.
- Browser visual and authenticated end-to-end checks remain required.

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `08001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `08002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `08003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `08004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `08005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `08006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `08007` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `08008` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `08009` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `08010` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `08011` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |

## ศัพท์และกติกาจาก CONTEXT เดิม

## Inventory Language

**Item**:
ทะเบียนกลางของสิ่งที่ Company ซื้อ ขาย ใช้ หรือนำไปให้บริการ โดยรหัสเดียวอาจมีหลายวัตถุประสงค์
_Avoid_: Product, Spare Part, Material เมื่อหมายถึงทะเบียนหลัก

**Item Kind**:
ลักษณะพื้นฐานของ Item ว่าเป็นสิ่งของ (`GOODS`) หรือบริการ (`SERVICE`)
_Avoid_: Item Type, Usage

**Stock Tracking**:
ระดับการควบคุมคงเหลือของ Item ได้แก่ไม่ควบคุม (`NONE`), ตามจำนวน (`QUANTITY`) หรือตาม Serial (`SERIAL`)
_Avoid_: Item Kind, Usage

**Item Usage**:
วัตถุประสงค์ที่ Item ถูกนำไปใช้ ได้แก่ขาย วัสดุ อุปกรณ์ หรืออะไหล่ โดย Item หนึ่งรายการมีได้หลาย Usage
_Avoid_: Item Group, Item Type

**Warehouse**:
สถานที่เก็บ Item ภายใต้ Branch ซึ่งเป็นขอบเขตของยอดคงเหลือและการเคลื่อนไหว
_Avoid_: Branch, Room

**Item Project Availability**:
ขอบเขต Project ที่นำ Item ของ Company ไปใช้ได้ แยกจากวัตถุประสงค์และไม่ทดแทนสิทธิ์ของผู้ใช้
_Avoid_: Item Usage, User Permission

**Item Classification Default**:
ค่าเริ่มต้นของชนิด วิธีควบคุมสต็อก และวัตถุประสงค์สำหรับสินค้าใหม่ในกลุ่มหรือประเภทนั้น ไม่ใช่คำสั่งเปลี่ยนสินค้าที่มีอยู่แล้ว
_Avoid_: Item Project Availability

**Item Instance**:
หน่วยจริงหนึ่งชิ้นของ Item แบบ Serial ซึ่งมี Serial สถานะ และตำแหน่งปัจจุบันเฉพาะตัว
_Avoid_: Item, Stock Balance

**Warranty Policy**:
ค่าเริ่มต้นความคุ้มครองของ Item แยกประกันผู้ขายและประกันลูกค้า โดยกำหนดว่าไม่มีประกัน ตลอดอายุ หรือจำนวนเดือน
_Avoid_: วันหมดอายุของ Serial, ประกันเอกสาร

**Serial Warranty Coverage**:
Snapshot ความคุ้มครองของ Item Instance หนึ่งชิ้น ซึ่งเก็บวันเริ่ม วันหมดอายุ เหตุการณ์ และเอกสารที่เริ่มประกันจริง
_Avoid_: Warranty Policy, Item Warranty

**Inventory Fulfillment**:
หลักฐานว่ารายการต้นทางถูกตัดสต็อกโดยเอกสารใดแล้ว เพื่อป้องกันการตัดจำนวนหรือ Serial ซ้ำ
_Avoid_: Stock Movement, Invoice Line
