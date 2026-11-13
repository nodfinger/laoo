# Pet

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: Pet
- โฟลเดอร์เจ้าของโค้ดหลัก: `projects/pet`
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `62001` | `/company/pet-settings` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/pet/lib/src/pet_routes.dart`](../../projects/pet/lib/src/pet_routes.dart) |
| `62002` | `/company/pet-services` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/pet/lib/src/pet_routes.dart`](../../projects/pet/lib/src/pet_routes.dart) |
| `62003` | `/company/pet-rooms` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/pet/lib/src/pet_routes.dart`](../../projects/pet/lib/src/pet_routes.dart) |
| `62004` | `/company/pet-profiles` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/pet/lib/src/pet_routes.dart`](../../projects/pet/lib/src/pet_routes.dart) |
| `62005` | `/company/pet-packages` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/pet/lib/src/pet_routes.dart`](../../projects/pet/lib/src/pet_routes.dart) |
| `62006` | `/company/pet-appointments` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/pet/lib/src/pet_routes.dart`](../../projects/pet/lib/src/pet_routes.dart) |
| `62007` | `/company/pet-work` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/pet/lib/src/pet_routes.dart`](../../projects/pet/lib/src/pet_routes.dart) |
| `62008` | `/company/pet-history` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/pet/lib/src/pet_routes.dart`](../../projects/pet/lib/src/pet_routes.dart) |
| `62009` | `/company/pet-owner-portal` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/pet/lib/src/pet_routes.dart`](../../projects/pet/lib/src/pet_routes.dart) |
| `62010` | `/company/pet-dashboard` | ไม่พบ | `ไม่พบ` | unspecified | [`projects/pet/lib/src/pet_routes.dart`](../../projects/pet/lib/src/pet_routes.dart) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `62001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `62002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `62003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `62004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `62005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `62006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `62007` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `62008` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `62009` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `62010` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
