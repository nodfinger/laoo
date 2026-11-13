# Provider

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: Provider
- โฟลเดอร์เจ้าของโค้ดหลัก: `projects/provider`
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `51001` | `/company/provider-settings` | 2 | `LAOO_PROVIDER` | true | [`projects/provider/lib/features/provider/provider_route_contract.dart`](../../projects/provider/lib/features/provider/provider_route_contract.dart) |
| `51002` | `/company/provider-locations` | 1 | `LAOO_PROVIDER` | true | [`projects/provider/lib/features/provider/provider_route_contract.dart`](../../projects/provider/lib/features/provider/provider_route_contract.dart) |
| `51003` | `/company/provider-service-types` | 1 | `LAOO_PROVIDER` | true | [`projects/provider/lib/features/provider/provider_route_contract.dart`](../../projects/provider/lib/features/provider/provider_route_contract.dart) |
| `51004` | `/company/provider-profile` | 2 | `LAOO_PROVIDER` | true | [`projects/provider/lib/features/provider/provider_route_contract.dart`](../../projects/provider/lib/features/provider/provider_route_contract.dart) |
| `51005` | `/company/provider-approvals` | 3 | `LAOO_PROVIDER` | true | [`projects/provider/lib/features/provider/provider_route_contract.dart`](../../projects/provider/lib/features/provider/provider_route_contract.dart) |
| `51006` | `/company/provider-review-links` | 1 | `LAOO_PROVIDER` | true | [`projects/provider/lib/features/provider/provider_route_contract.dart`](../../projects/provider/lib/features/provider/provider_route_contract.dart) |
| `51007` | `/company/provider-reviews` | 3 | `LAOO_PROVIDER` | true | [`projects/provider/lib/features/provider/provider_route_contract.dart`](../../projects/provider/lib/features/provider/provider_route_contract.dart) |
| `51008` | `/company/provider-reports` | 3 | `LAOO_PROVIDER` | true | [`projects/provider/lib/features/provider/provider_route_contract.dart`](../../projects/provider/lib/features/provider/provider_route_contract.dart) |
| `51009` | `/company/provider-portfolio` | 1 | `LAOO_PROVIDER` | true | [`projects/provider/lib/features/provider/provider_route_contract.dart`](../../projects/provider/lib/features/provider/provider_route_contract.dart) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `51001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `51002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `51003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `51004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `51005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `51006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `51007` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `51008` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `51009` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
