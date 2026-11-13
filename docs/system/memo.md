# Memo

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: Memo
- โฟลเดอร์เจ้าของโค้ดหลัก: `projects/memo`
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `50001` | `/company/memo-settings` | 2 | `LAOO_MEMO` | true | [`projects/memo/lib/features/memo/memo_route_contract.dart`](../../projects/memo/lib/features/memo/memo_route_contract.dart) |
| `50002` | `/company/memo-types` | 1 | `LAOO_MEMO` | true | [`projects/memo/lib/features/memo/memo_route_contract.dart`](../../projects/memo/lib/features/memo/memo_route_contract.dart) |
| `50003` | `/company/memo-approval-routes` | 1 | `LAOO_MEMO` | true | [`projects/memo/lib/features/memo/memo_route_contract.dart`](../../projects/memo/lib/features/memo/memo_route_contract.dart) |
| `50004` | `/company/memo-templates` | 1 | `LAOO_MEMO` | true | [`projects/memo/lib/features/memo/memo_route_contract.dart`](../../projects/memo/lib/features/memo/memo_route_contract.dart) |
| `50005` | `/company/memos` | 4 | `LAOO_MEMO` | true | [`projects/memo/lib/features/memo/memo_route_contract.dart`](../../projects/memo/lib/features/memo/memo_route_contract.dart) |
| `50006` | `/company/memo-approvals` | 3 | `LAOO_MEMO` | true | [`projects/memo/lib/features/memo/memo_route_contract.dart`](../../projects/memo/lib/features/memo/memo_route_contract.dart) |
| `50007` | `/company/memo-inbox` | 3 | `LAOO_MEMO` | true | [`projects/memo/lib/features/memo/memo_route_contract.dart`](../../projects/memo/lib/features/memo/memo_route_contract.dart) |
| `50008` | `/company/memo-history` | 3 | `LAOO_MEMO` | true | [`projects/memo/lib/features/memo/memo_route_contract.dart`](../../projects/memo/lib/features/memo/memo_route_contract.dart) |
| `50009` | `/company/memo-reports` | 3 | `LAOO_MEMO` | true | [`projects/memo/lib/features/memo/memo_route_contract.dart`](../../projects/memo/lib/features/memo/memo_route_contract.dart) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `50001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `50002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `50003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `50004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `50005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `50006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `50007` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `50008` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `50009` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
