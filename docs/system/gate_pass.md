# Gate Pass

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: Gate Pass
- โฟลเดอร์เจ้าของโค้ดหลัก: `projects/gate_pass`
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `38001` | `/company/gate-pass-settings` | 2 | `LAOO_GATE_PASS` | true | [`projects/gate_pass/lib/features/gate_pass/gate_pass_route_contract.dart`](../../projects/gate_pass/lib/features/gate_pass/gate_pass_route_contract.dart) |
| `38002` | `/company/gate-pass-purposes` | 1 | `LAOO_GATE_PASS` | true | [`projects/gate_pass/lib/features/gate_pass/gate_pass_route_contract.dart`](../../projects/gate_pass/lib/features/gate_pass/gate_pass_route_contract.dart) |
| `38003` | `/company/gate-passes` | 4 | `LAOO_GATE_PASS` | true | [`projects/gate_pass/lib/features/gate_pass/gate_pass_route_contract.dart`](../../projects/gate_pass/lib/features/gate_pass/gate_pass_route_contract.dart) |
| `38004` | `/company/gate-pass-approvals` | 3 | `LAOO_GATE_PASS` | true | [`projects/gate_pass/lib/features/gate_pass/gate_pass_route_contract.dart`](../../projects/gate_pass/lib/features/gate_pass/gate_pass_route_contract.dart) |
| `38005` | `/company/gate-pass-exit-check` | 2 | `LAOO_GATE_PASS` | true | [`projects/gate_pass/lib/features/gate_pass/gate_pass_route_contract.dart`](../../projects/gate_pass/lib/features/gate_pass/gate_pass_route_contract.dart) |
| `38006` | `/company/gate-pass-returns` | 2 | `LAOO_GATE_PASS` | true | [`projects/gate_pass/lib/features/gate_pass/gate_pass_route_contract.dart`](../../projects/gate_pass/lib/features/gate_pass/gate_pass_route_contract.dart) |
| `38007` | `/company/my-gate-passes` | 4 | `LAOO_GATE_PASS` | true | [`projects/gate_pass/lib/features/gate_pass/gate_pass_route_contract.dart`](../../projects/gate_pass/lib/features/gate_pass/gate_pass_route_contract.dart) |
| `38008` | `/company/gate-pass-reports` | 3 | `LAOO_GATE_PASS` | true | [`projects/gate_pass/lib/features/gate_pass/gate_pass_route_contract.dart`](../../projects/gate_pass/lib/features/gate_pass/gate_pass_route_contract.dart) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `38001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `38002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `38003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `38004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `38005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `38006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `38007` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `38008` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
