# ระบบจัดซื้อ

## ข้อกำหนดปัจจุบัน

- `69001` กำหนดค่าระบบจัดซื้อเป็น ScreenType 2; คำสั่งเดิมให้เพิ่มเฉพาะทะเบียนเมนู ยังไม่ระบุช่องตั้งค่า
- `69002` `SC Request` เป็น ScreenType 4; ใช้เลขเอกสารอัตโนมัติ (`RunData`), พิมพ์เอกสารได้ และกำหนดการแสดง/จัดเรียงรายการได้; Route ยังเป็นหน้าเริ่มต้นและ Flow/API ธุรกิจยังไม่ยืนยัน
- ทะเบียนผู้ขาย `08007` อยู่ใน [stock.md](stock.md) ตามกลุ่มเมนูและ migration ปัจจุบัน แต่เป็นข้อมูลที่ระบบจัดซื้ออาจอ้างอิง; ยังไม่พบสัญญาเชื่อมจัดซื้อที่ยืนยันแล้ว

## ยังไม่ยืนยัน

- คำขอซื้อ ใบสั่งซื้อ รับสินค้า และ Flow อนุมัติของระบบจัดซื้อยังไม่พบเป็นเมนู/สเปกที่ยืนยันในดัชนีนี้

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: ระบบจัดซื้อ
- โค้ดอาจอยู่ใน Core และหลายโมดูล; ดูแหล่งอ้างอิงรายเมนู
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `69001` | `/company/my-system/purchase-settings` | 2 | `LAOO` | ไม่ระบุ | `database/migrations/20261111233000_LAOO_my_system_purchase_legal_menus.sql` (ไฟล์ migration ถูกลบหลังรันแล้ว; ตรวจประวัติ Git) |
| `69002` | `/company/my-system/purchase-sc-request` | 4 | `LAOO` | VIEW, CREATE, EDIT, DELETE | RunData, AllowPrint, AllowListDisplaySettings; [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `69001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
