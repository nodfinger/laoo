# Document Control

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: Document Control
- โฟลเดอร์เจ้าของโค้ดหลัก: `projects/document_control`
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `48001` | `/company/document-control-settings` | 2 | `LAOO_DOCUMENT` | true | [`projects/document_control/lib/features/document_control/document_control_route_contract.dart`](../../projects/document_control/lib/features/document_control/document_control_route_contract.dart) |
| `48002` | `/company/document-types` | 1 | `LAOO_DOCUMENT` | true | [`projects/document_control/lib/features/document_control/document_control_route_contract.dart`](../../projects/document_control/lib/features/document_control/document_control_route_contract.dart) |
| `48003` | `/company/controlled-documents` | 4 | `LAOO_DOCUMENT` | true | [`projects/document_control/lib/features/document_control/document_control_route_contract.dart`](../../projects/document_control/lib/features/document_control/document_control_route_contract.dart) |
| `48004` | `/company/document-approvals` | 3 | `LAOO_DOCUMENT` | true | [`projects/document_control/lib/features/document_control/document_control_route_contract.dart`](../../projects/document_control/lib/features/document_control/document_control_route_contract.dart) |
| `48005` | `/company/general-documents` | 1 | `LAOO_DOCUMENT` | true | [`projects/document_control/lib/features/document_control/document_control_route_contract.dart`](../../projects/document_control/lib/features/document_control/document_control_route_contract.dart) |
| `48006` | `/company/document-library` | 3 | `LAOO_DOCUMENT` | true | [`projects/document_control/lib/features/document_control/document_control_route_contract.dart`](../../projects/document_control/lib/features/document_control/document_control_route_contract.dart) |
| `48007` | `/company/document-acknowledgements` | 3 | `LAOO_DOCUMENT` | true | [`projects/document_control/lib/features/document_control/document_control_route_contract.dart`](../../projects/document_control/lib/features/document_control/document_control_route_contract.dart) |
| `48008` | `/company/document-control-reports` | 3 | `LAOO_DOCUMENT` | true | [`projects/document_control/lib/features/document_control/document_control_route_contract.dart`](../../projects/document_control/lib/features/document_control/document_control_route_contract.dart) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `48001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `48002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `48003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `48004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `48005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `48006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `48007` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `48008` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
