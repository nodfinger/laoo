# Booking

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: Booking
- โฟลเดอร์เจ้าของโค้ดหลัก: `projects/booking`
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `61001` | `/company/booking-settings` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/booking/lib/src/booking_routes.dart`](../../projects/booking/lib/src/booking_routes.dart) |
| `61002` | `/company/booking-services` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/booking/lib/src/booking_routes.dart`](../../projects/booking/lib/src/booking_routes.dart) |
| `61003` | `/company/booking-providers` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/booking/lib/src/booking_routes.dart`](../../projects/booking/lib/src/booking_routes.dart) |
| `61004` | `/company/booking-resources` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/booking/lib/src/booking_routes.dart`](../../projects/booking/lib/src/booking_routes.dart) |
| `61005` | `/company/booking-members` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/booking/lib/src/booking_routes.dart`](../../projects/booking/lib/src/booking_routes.dart) |
| `61006` | `/company/booking-promotions` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/booking/lib/src/booking_routes.dart`](../../projects/booking/lib/src/booking_routes.dart) |
| `61007` | `/company/booking-calendar` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/booking/lib/src/booking_routes.dart`](../../projects/booking/lib/src/booking_routes.dart) |
| `61008` | `/company/booking-usage` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/booking/lib/src/booking_routes.dart`](../../projects/booking/lib/src/booking_routes.dart) |
| `61009` | `/company/booking-member-history` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/booking/lib/src/booking_routes.dart`](../../projects/booking/lib/src/booking_routes.dart) |
| `61010` | `/company/booking-dashboard` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/booking/lib/src/booking_routes.dart`](../../projects/booking/lib/src/booking_routes.dart) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `61001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `61002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `61003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `61004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `61005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `61006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `61007` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `61008` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `61009` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `61010` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
