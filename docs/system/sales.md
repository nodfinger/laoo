# ระบบขายและเอกสารการค้า

## ข้อกำหนดปัจจุบันที่มีสเปกยืนยัน

- `09006` ใบส่งของอ้างเอกสารได้หนึ่งชนิด (`QUOTATION`, `PREORDER`, `TEMP_RECEIPT`, `DELIVERY_NOTE`) หรือ `NONE`; ใช้สถานะ `DRAFT`, `CONFIRMED`, `VOID`
- ยืนยันแล้วจึงตัดสต๊อกและเขียน Stock Movement ภายใน transaction; VOID คืนสต๊อกด้วย REVERSAL; ป้องกันตัด/คืนซ้ำ; หากอ้างใบจองต้องตรวจ `DeliveredQty` ไม่เกิน `AllocatedQty`
- ข้อมูล/ API /สิทธิ์ของใบส่งของอยู่ในสเปกที่ย้ายด้านล่าง; หน้าขายอื่นยังต้องตรวจสเปกเฉพาะ

## ความเชื่อมโยงข้ามระบบ

- ใบส่งของใช้สินค้าจาก `stock.md` และเชื่อมใบเสนอราคา/ใบจอง/ใบเสร็จชั่วคราวผ่าน `TDARDocumentLink`

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: ระบบขายและเอกสารการค้า
- โฟลเดอร์เจ้าของโค้ดหลัก: `projects/sales`
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `09001` | `/company/customers` | 1 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `09002` | `companyBranches` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `09003` | `/company/quotations` | 4 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `09004` | `/company/pre-orders` | 4 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `09005` | `/company/temporary-receipts` | 4 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `09006` | `/company/delivery-notes` | 4 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `09007` | `/company/tax-invoices` | 4 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `09008` | `/company/vat-settings` | 2 | `LAOO` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `09009` | `/company/purchase-deliveries` | 4 | `LAOO` | unspecified | [`projects/service/lib/features/service/service_route_contract.dart`](../../projects/service/lib/features/service/service_route_contract.dart) |
| `09010` | `/company/purchase-tax-invoices` | 4 | `LAOO` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `09019` | `/company/sales-tax-report` | 3 | `LAOO` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `09020` | `/company/purchase-tax-report` | 3 | `LAOO` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `45001` | `/company/sales-settings` | 2 | `LAOO_SALES` | true | [`projects/sales/lib/sales_feature.dart`](../../projects/sales/lib/sales_feature.dart) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สเปก Function ที่ย้ายจาก `docs/DELIVERY_NOTE_FLOW.md`

# ใบส่งของ (MenuCode 09006)

## เอกสารอ้างอิง

ใบส่งของเลือกอ้างอิงได้ 1 ประเภท หรือไม่อ้างอิงเอกสารก็ได้

- `QUOTATION` ใบเสนอราคา
- `PREORDER` ใบจองสินค้า
- `TEMP_RECEIPT` ใบเสร็จรับเงินชั่วคราว โดยระบบติดตามกลับไปยังใบจองหรือใบเสนอราคาต้นทาง
- `DELIVERY_NOTE` ใบส่งของเดิม สำหรับการส่งต่อ/ส่งซ้ำตามจำนวนคงเหลือ
- `NONE` ไม่อ้างอิงเอกสาร และเพิ่มสินค้าเอง

ความสัมพันธ์ระหว่างเอกสารบันทึกใน `TDARDocumentLink`

## สถานะและสต๊อก

- `DRAFT`: แก้ไขและลบได้ ยังไม่ตัดสต๊อก
- `CONFIRMED`: ยืนยันส่งของ ตัด `TDIVItem.StockBalance` และบันทึก `TDIVStockMovement` ภายใน Transaction เดียว
- `VOID`: ยกเลิกเอกสารที่ยืนยันแล้ว คืนสต๊อกและบันทึกรายการ `REVERSAL`

ระบบใช้ Unique Constraint ในสมุดสต๊อก ป้องกันการตัดหรือคืนสต๊อกซ้ำ และตรวจสต๊อกด้วย `UPDLOCK,HOLDLOCK`

ถ้าอ้างใบจอง ระบบเพิ่ม/ลด `TDARPreOrderDetail.DeliveredQty` พร้อมตรวจไม่ให้เกิน `AllocatedQty`

## ตาราง

- `TDARDeliveryNote`: หัวเอกสารและ Snapshot ลูกค้า/ที่อยู่จัดส่ง
- `TDARDeliveryNoteDetail`: รายการสินค้า จำนวนอ้างอิง จำนวนส่งสะสม และจำนวนส่งครั้งนี้
- `TDIVStockMovement`: สมุดรายการตัดและคืนสต๊อก

## API

- `GET /api/company/delivery-notes`
- `GET /api/company/delivery-notes/actions`
- `GET /api/company/delivery-notes/lookup`
- `GET /api/company/delivery-notes/source/{type}/{id}`
- `GET /api/company/delivery-notes/{id}`
- `POST /api/company/delivery-notes`
- `PUT /api/company/delivery-notes/{id}`
- `DELETE /api/company/delivery-notes/{id}` (เฉพาะ Draft)
- `POST /api/company/delivery-notes/{id}/confirm`
- `POST /api/company/delivery-notes/{id}/void`

API ทุกคำสั่งกรอง `CompanyID` จาก JWT และตรวจสิทธิ์ `VIEW/CREATE/EDIT/DELETE` ของ MenuCode `09006`; Company Admin ใช้งานได้ทุกคำสั่ง

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `09001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `09002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `09003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `09004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `09005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `09006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `09007` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `09008` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `09009` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `09010` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `09019` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `09020` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `45001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
