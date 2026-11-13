# Five S

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: Five S
- โฟลเดอร์เจ้าของโค้ดหลัก: `projects/five_s`
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `39001` | `/company/five-s/inspection-areas` | 1 | `LAOO_5S` | true | [`projects/five_s/lib/features/five_s/five_s_route_contract.dart`](../../projects/five_s/lib/features/five_s/five_s_route_contract.dart) |
| `39002` | `/company/five-s/templates` | 1 | `LAOO_5S` | true | [`projects/five_s/lib/features/five_s/five_s_route_contract.dart`](../../projects/five_s/lib/features/five_s/five_s_route_contract.dart) |
| `39003` | `/company/five-s/inspection-teams` | 1 | `LAOO_5S` | true | [`projects/five_s/lib/features/five_s/five_s_route_contract.dart`](../../projects/five_s/lib/features/five_s/five_s_route_contract.dart) |
| `39004` | `/company/five-s/inspection-plans` | 1 | `LAOO_5S` | true | [`projects/five_s/lib/features/five_s/five_s_route_contract.dart`](../../projects/five_s/lib/features/five_s/five_s_route_contract.dart) |
| `39005` | `/company/five-s/inspections` | 4 | `LAOO_5S` | true | [`projects/five_s/lib/features/five_s/five_s_route_contract.dart`](../../projects/five_s/lib/features/five_s/five_s_route_contract.dart) |
| `39006` | `/company/five-s/inspection-confirmations` | 2 | `LAOO_5S` | true | [`projects/five_s/lib/features/five_s/five_s_route_contract.dart`](../../projects/five_s/lib/features/five_s/five_s_route_contract.dart) |
| `39007` | `/company/five-s/findings` | 2 | `LAOO_5S` | true | [`projects/five_s/lib/features/five_s/five_s_route_contract.dart`](../../projects/five_s/lib/features/five_s/five_s_route_contract.dart) |
| `39008` | `/company/five-s/inspection-history` | 3 | `LAOO_5S` | true | [`projects/five_s/lib/features/five_s/five_s_route_contract.dart`](../../projects/five_s/lib/features/five_s/five_s_route_contract.dart) |
| `39009` | `/company/five-s/reports` | 3 | `LAOO_5S` | true | [`projects/five_s/lib/features/five_s/five_s_route_contract.dart`](../../projects/five_s/lib/features/five_s/five_s_route_contract.dart) |
| `39010` | `/company/five-s/settings` | 2 | `LAOO_5S` | true | [`projects/five_s/lib/features/five_s/five_s_route_contract.dart`](../../projects/five_s/lib/features/five_s/five_s_route_contract.dart) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `39001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `39002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `39003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `39004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `39005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `39006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `39007` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `39008` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `39009` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `39010` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
