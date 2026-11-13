# Visitor

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: Visitor
- โฟลเดอร์เจ้าของโค้ดหลัก: `projects/visitor`
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `31001` | `/visitor/gate-dashboard` | 3 | `LAOO_VISITOR` | false | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `31002` | `/visitor/check-in` | 1 | `LAOO_VISITOR` | true | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `31003` | `/visitor/inside` | 3 | `LAOO_VISITOR` | false | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `31004` | `/visitor/check-out` | 2 | `LAOO_VISITOR` | false | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `31005` | `/visitor/history` | 3 | `LAOO_VISITOR` | true | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `32001` | `/visitor/pre-register` | 1 | `LAOO_VISITOR` | true | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `32002` | `/visitor/approval-status` | 3 | `LAOO_VISITOR` | true | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `32003` | `/visitor/host-confirm` | 2 | `LAOO_VISITOR` | true | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `33001` | `/visitor/site-zone-gate` | 1 | `LAOO_VISITOR` | true | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `33002` | `/visitor/residential` | 1 | `LAOO_VISITOR` | false | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `33003` | `/visitor/corporate` | 1 | `LAOO_VISITOR` | false | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `33004` | `/visitor/common-master` | 1 | `LAOO_VISITOR` | false | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `34001` | `/visitor/admin-dashboard` | 3 | `LAOO_VISITOR` | false | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `34002` | `/visitor/reports` | 3 | `LAOO_VISITOR` | false | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `34003` | `/visitor/exceptions` | 3 | `LAOO_VISITOR` | true | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `34004` | `/visitor/timeline` | 3 | `LAOO_VISITOR` | false | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `35001` | `/visitor/notifications` | 3 | `LAOO_VISITOR` | false | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `35002` | `/visitor/notification-history` | 3 | `LAOO_VISITOR` | false | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `35003` | `/visitor/notification-channels` | 2 | `LAOO_VISITOR` | false | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `36001` | `/visitor/audit` | 3 | `LAOO_VISITOR` | false | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `36002` | `/visitor/watchlist` | 1 | `LAOO_VISITOR` | false | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `36003` | `/visitor/retention-policy` | 2 | `LAOO_VISITOR` | false | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |
| `36004` | `/visitor/system-settings` | 2 | `LAOO_VISITOR` | true | [`projects/visitor/lib/features/visitor/visitor_route_contract.dart`](../../projects/visitor/lib/features/visitor/visitor_route_contract.dart) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `31001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `31002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `31003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `31004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `31005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `32001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `32002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `32003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `33001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `33002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `33003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `33004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `34001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `34002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `34003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `34004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `35001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `35002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `35003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `36001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `36002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `36003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `36004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
