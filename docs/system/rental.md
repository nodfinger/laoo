# Rental

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: Rental
- โฟลเดอร์เจ้าของโค้ดหลัก: `projects/rental`
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `60001` | `/company/rental-settings` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/rental/lib/src/rental_routes.dart`](../../projects/rental/lib/src/rental_routes.dart) |
| `60002` | `/company/rental-items` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/rental/lib/src/rental_routes.dart`](../../projects/rental/lib/src/rental_routes.dart) |
| `60003` | `/company/rental-availability` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/rental/lib/src/rental_routes.dart`](../../projects/rental/lib/src/rental_routes.dart) |
| `60004` | `/company/rental-bookings` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/rental/lib/src/rental_routes.dart`](../../projects/rental/lib/src/rental_routes.dart) |
| `60005` | `/company/rental-payments` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/rental/lib/src/rental_routes.dart`](../../projects/rental/lib/src/rental_routes.dart) |
| `60006` | `/company/rental-handover` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/rental/lib/src/rental_routes.dart`](../../projects/rental/lib/src/rental_routes.dart) |
| `60007` | `/company/rental-returns` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/rental/lib/src/rental_routes.dart`](../../projects/rental/lib/src/rental_routes.dart) |
| `60008` | `/company/rental-settlements` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/rental/lib/src/rental_routes.dart`](../../projects/rental/lib/src/rental_routes.dart) |
| `60009` | `/company/rental-history` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/rental/lib/src/rental_routes.dart`](../../projects/rental/lib/src/rental_routes.dart) |
| `60010` | `/company/rental-dashboard` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/rental/lib/src/rental_routes.dart`](../../projects/rental/lib/src/rental_routes.dart) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `60001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `60002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `60003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `60004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `60005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `60006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `60007` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `60008` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `60009` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `60010` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
