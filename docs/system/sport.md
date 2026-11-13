# Sport

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: Sport
- โฟลเดอร์เจ้าของโค้ดหลัก: `projects/sport`
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `54001` | `/company/sport-settings` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/sport/lib/src/routes.dart`](../../projects/sport/lib/src/routes.dart) |
| `54002` | `/company/sport-types` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/sport/lib/src/routes.dart`](../../projects/sport/lib/src/routes.dart) |
| `54003` | `/company/sport-facilities` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/sport/lib/src/routes.dart`](../../projects/sport/lib/src/routes.dart) |
| `54004` | `/company/sport-levels` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/sport/lib/src/routes.dart`](../../projects/sport/lib/src/routes.dart) |
| `54005` | `/company/sport-packages` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/sport/lib/src/routes.dart`](../../projects/sport/lib/src/routes.dart) |
| `54006` | `/company/sport-members` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/sport/lib/src/routes.dart`](../../projects/sport/lib/src/routes.dart) |
| `54007` | `/company/sport-enrollments` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/sport/lib/src/routes.dart`](../../projects/sport/lib/src/routes.dart) |
| `54008` | `/company/sport-bookings` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/sport/lib/src/routes.dart`](../../projects/sport/lib/src/routes.dart) |
| `54009` | `/company/sport-checkins` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/sport/lib/src/routes.dart`](../../projects/sport/lib/src/routes.dart) |
| `54010` | `/company/sport-pos-pricing` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/sport/lib/src/routes.dart`](../../projects/sport/lib/src/routes.dart) |
| `54011` | `/company/sport-dashboard` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/sport/lib/src/routes.dart`](../../projects/sport/lib/src/routes.dart) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `54001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `54002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `54003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `54004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `54005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `54006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `54007` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `54008` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `54009` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `54010` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `54011` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
