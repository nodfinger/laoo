# ระบบกฎหมาย

## ข้อกำหนดปัจจุบัน

- `70001` กำหนดค่าระบบ: ScreenType 2; เพิ่มเฉพาะทะเบียนเมนู ยังไม่กำหนดช่องตั้งค่า
- `70002` ขอเอกสารสำคัญ: ScreenType 4, ขออนุมัติทุกครั้ง, จัดเรียง/กำหนดการเข้าถึงได้, ไม่ส่งออกและไม่พิมพ์ ตามคำสั่งล่าสุด; ก่อนหน้านี้มีคำสั่ง “พิมพ์ได้” ซึ่งถูกเปลี่ยนภายหลัง
- `70003` ประเภทเอกสาร: ScreenType 1, RunData; ไม่พิมพ์ ไม่ส่งออก ไม่ขออนุมัติ; ต้องกรองกลุ่มเอกสารกฎหมายและมีค้นหา

## ยังไม่ยืนยัน

- ชื่อ DTO, ตาราง, ActionCode และสถานะการอนุมัติต้องตรวจ API/DB เพิ่ม; ห้ามตีความจาก ScreenType เพียงอย่างเดียว

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: ระบบกฎหมาย
- โค้ดอาจอยู่ใน Core และหลายโมดูล; ดูแหล่งอ้างอิงรายเมนู
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `70001` | `/company/my-system/legal-settings` | 2 | `LAOO` | ไม่ระบุ | `database/migrations/20261111233000_LAOO_my_system_purchase_legal_menus.sql` (ไฟล์ migration ถูกลบหลังรันแล้ว; ตรวจประวัติ Git) |
| `70002` | `/company/my-system/legal-document-request` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `70003` | `/company/my-system/legal-document-types` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `70001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `70002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `70003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
