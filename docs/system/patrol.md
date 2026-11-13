# Patrol

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: Patrol
- โฟลเดอร์เจ้าของโค้ดหลัก: `projects/patrol`
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `56001` | `/company/patrol-settings` | 2 | `LAOO_PATROL` | true | [`projects/patrol/lib/features/patrol/patrol_route_contract.dart`](../../projects/patrol/lib/features/patrol/patrol_route_contract.dart) |
| `56002` | `/company/patrol-checkpoints` | 1 | `LAOO_PATROL` | true | [`projects/patrol/lib/features/patrol/patrol_route_contract.dart`](../../projects/patrol/lib/features/patrol/patrol_route_contract.dart) |
| `56003` | `/company/patrol-devices` | 1 | `LAOO_PATROL` | true | [`projects/patrol/lib/features/patrol/patrol_route_contract.dart`](../../projects/patrol/lib/features/patrol/patrol_route_contract.dart) |
| `56004` | `/company/patrol-credentials` | 1 | `LAOO_PATROL` | true | [`projects/patrol/lib/features/patrol/patrol_route_contract.dart`](../../projects/patrol/lib/features/patrol/patrol_route_contract.dart) |
| `56005` | `/company/patrol-checklists` | 1 | `LAOO_PATROL` | true | [`projects/patrol/lib/features/patrol/patrol_route_contract.dart`](../../projects/patrol/lib/features/patrol/patrol_route_contract.dart) |
| `56006` | `/company/patrol-routes` | 1 | `LAOO_PATROL` | true | [`projects/patrol/lib/features/patrol/patrol_route_contract.dart`](../../projects/patrol/lib/features/patrol/patrol_route_contract.dart) |
| `56007` | `/company/patrol-schedules` | 4 | `LAOO_PATROL` | true | [`projects/patrol/lib/features/patrol/patrol_route_contract.dart`](../../projects/patrol/lib/features/patrol/patrol_route_contract.dart) |
| `56008` | `/company/patrol-runs` | 4 | `LAOO_PATROL` | true | [`projects/patrol/lib/features/patrol/patrol_route_contract.dart`](../../projects/patrol/lib/features/patrol/patrol_route_contract.dart) |
| `56009` | `/company/patrol-monitor` | 3 | `LAOO_PATROL` | true | [`projects/patrol/lib/features/patrol/patrol_route_contract.dart`](../../projects/patrol/lib/features/patrol/patrol_route_contract.dart) |
| `56010` | `/company/patrol-incidents` | 3 | `LAOO_PATROL` | true | [`projects/patrol/lib/features/patrol/patrol_route_contract.dart`](../../projects/patrol/lib/features/patrol/patrol_route_contract.dart) |
| `56011` | `/company/patrol-audit` | 3 | `LAOO_PATROL` | true | [`projects/patrol/lib/features/patrol/patrol_route_contract.dart`](../../projects/patrol/lib/features/patrol/patrol_route_contract.dart) |
| `56012` | `/company/patrol-dashboard` | 3 | `LAOO_PATROL` | true | [`projects/patrol/lib/features/patrol/patrol_route_contract.dart`](../../projects/patrol/lib/features/patrol/patrol_route_contract.dart) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `56001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `56002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `56003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `56004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `56005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `56006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `56007` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `56008` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `56009` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `56010` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `56011` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `56012` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
