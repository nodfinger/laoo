# ระบบส่วนกลาง

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: ระบบส่วนกลาง
- โค้ดอาจอยู่ใน Core และหลายโมดูล; ดูแหล่งอ้างอิงรายเมนู
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `01007` | `laooMenuManagement` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `01008` | `qrCodeGenerator` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `05004` | `companyDocumentNumberFormat` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `10008` | `companyAiCapabilities` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `10009` | `/company/position-levels` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `10010` | `/company/menu-data-access` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `10011` | `/company/approval-pattern` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `13001` | `companyBranches` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `13002` | `companyPersons` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `14001` | `assetLocations` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `55001` | `companyBusinessCardOcrSettings` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `55002` | `companyContacts` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `59003` | `ไม่พบ Route` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `64001` | `companyAiIntentTest` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `64002` | `companyAiSettings` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `64003` | `companyAiAgents` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `65001` | `/company/my-system/settings` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `65002` | `/company/my-system/sap-pms` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |

กลุ่มเมนู `65` ภายใต้ระบบของฉันใช้ชื่อ `ระบบ-IT` โดยมีเมนู `65001` กำหนดค่าระบบ (หน้าเปล่าชั่วคราว) และ `65002` ตรวจสอบข้อมูล API SAP-PMS อยู่ภายในกลุ่มเดียวกัน
| `66001` | `/company/my-system/travel` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |
| `66002` | `/company/my-system/purchase` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`lib/app/router/app_menu_route_registry.dart`](../../lib/app/router/app_menu_route_registry.dart) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `01007` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `01008` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `05004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `10008` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `10009` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `10010` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `10011` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `13001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `13002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `14001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `55001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `55002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `59003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `64001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `64002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `64003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `65001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `65002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `66001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `66002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |

## เอกสารร่างที่เกี่ยวข้อง

- [หน้าสิทธิ์ระดับย่อย](../drafts/SUB_PERMISSION_SCREEN_DRAFT.md) เป็นแบบร่าง ต้องตรวจ Source และสิทธิ์ปัจจุบันก่อนใช้

## ศัพท์และกติกาจาก CONTEXT เดิม

## People Language

**Person**:
ตัวตนกลางของบุคคลหนึ่งคนภายใน Company ซึ่งอาจมีหลายบทบาทและมีบัญชีเข้าใช้งานเดียวกัน
_Avoid_: Employee, Resident, User เมื่อต้องการกล่าวถึงตัวบุคคล

**Employee**:
บทบาทการทำงานของ Person ภายใน Company ซึ่งมีข้อมูลเฉพาะงาน เช่น รหัสพนักงาน ฝ่าย แผนก และตำแหน่ง
_Avoid_: Person, User

**Employee Organization Assignment**:
ประวัติช่วงวันที่ที่ Employee สังกัด Branch ฝ่าย และแผนก เพื่อให้ทุก Project อ้างโครงสร้างองค์กรตามวันที่เกิดรายการแทนค่าปัจจุบัน
_Avoid_: สังกัดปัจจุบันบน Employee, Work Schedule Group

**Home Branch**:
Branch ที่ Employee สังกัดตาม Employee Organization Assignment ใน Work Date
_Avoid_: Work Branch, Branch ของอุปกรณ์ที่รับ Event

**Work Branch**:
Branch ที่ Employee ถูกจัดให้ปฏิบัติงานตามตารางหรือ Schedule Override ใน Work Date ซึ่งอาจต่างจาก Home Branch
_Avoid_: Home Branch, การย้ายสังกัด

**Resident**:
บทบาทการพักอาศัยของ Person ซึ่งผูกกับสถานที่พักและช่วงเวลาการเข้าพัก
_Avoid_: Employee, User, Tenant เมื่อหมายถึงผู้พักอาศัยทุกประเภท

**User**:
บัญชีที่ Person ใช้ยืนยันตัวตนและเข้าสู่ระบบ โดยหนึ่ง Person ภายใน Company มีบัญชีหลักเพียงหนึ่งบัญชี
_Avoid_: Person, Employee, Resident
