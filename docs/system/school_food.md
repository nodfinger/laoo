# School Food

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: School Food
- โฟลเดอร์เจ้าของโค้ดหลัก: `projects/school_food`
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `53001` | `/company/school_food-settings` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/school_food/lib/src/routes.dart`](../../projects/school_food/lib/src/routes.dart) |
| `53002` | `/company/school_food-shops` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/school_food/lib/src/routes.dart`](../../projects/school_food/lib/src/routes.dart) |
| `53003` | `/company/school_food-items` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/school_food/lib/src/routes.dart`](../../projects/school_food/lib/src/routes.dart) |
| `53004` | `/company/school_food-commission` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/school_food/lib/src/routes.dart`](../../projects/school_food/lib/src/routes.dart) |
| `53005` | `/company/school_food-identifiers` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/school_food/lib/src/routes.dart`](../../projects/school_food/lib/src/routes.dart) |
| `53006` | `/company/school_food-transfers` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/school_food/lib/src/routes.dart`](../../projects/school_food/lib/src/routes.dart) |
| `53007` | `/company/school_food-wallet` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/school_food/lib/src/routes.dart`](../../projects/school_food/lib/src/routes.dart) |
| `53008` | `/company/school_food-pos` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/school_food/lib/src/routes.dart`](../../projects/school_food/lib/src/routes.dart) |
| `53009` | `/company/school_food-sales` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/school_food/lib/src/routes.dart`](../../projects/school_food/lib/src/routes.dart) |
| `53010` | `/company/school_food-students` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/school_food/lib/src/routes.dart`](../../projects/school_food/lib/src/routes.dart) |
| `53011` | `/company/school_food-settlements` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/school_food/lib/src/routes.dart`](../../projects/school_food/lib/src/routes.dart) |
| `53012` | `/company/school_food-dashboard` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/school_food/lib/src/routes.dart`](../../projects/school_food/lib/src/routes.dart) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `53001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `53002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `53003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `53004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `53005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `53006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `53007` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `53008` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `53009` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `53010` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `53011` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `53012` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
