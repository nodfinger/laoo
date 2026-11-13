# Service

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: Service
- โฟลเดอร์เจ้าของโค้ดหลัก: `projects/service`
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `01003` | `branch` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/service/lib/app/router/app_menu_route_registry.dart`](../../projects/service/lib/app/router/app_menu_route_registry.dart) |
| `01005` | `globalSettings` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/service/lib/app/router/app_menu_route_registry.dart`](../../projects/service/lib/app/router/app_menu_route_registry.dart) |
| `01006` | `globalPermissionSettings` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/service/lib/app/router/app_menu_route_registry.dart`](../../projects/service/lib/app/router/app_menu_route_registry.dart) |
| `05003` | `companySetupAdditional` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/service/lib/app/router/app_menu_route_registry.dart`](../../projects/service/lib/app/router/app_menu_route_registry.dart) |
| `10006` | `companySubPermissions` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/service/lib/app/router/app_menu_route_registry.dart`](../../projects/service/lib/app/router/app_menu_route_registry.dart) |
| `12005` | `organizationStructure` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/service/lib/app/router/app_menu_route_registry.dart`](../../projects/service/lib/app/router/app_menu_route_registry.dart) |
| `14002` | `/asset/items` | 1 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `14003` | `/asset/customers` | 1 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `14005` | `/service/customers` | 1 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_route_contract.dart`](../../projects/service/lib/features/service/service_route_contract.dart) |
| `14006` | `/service/residents` | 1 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_route_contract.dart`](../../projects/service/lib/features/service/service_route_contract.dart) |
| `15001` | `/cm/tickets` | 1 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `15002` | `/cm/qr-portal` | 1 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `16001` | `/pm/plans` | 1 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `16002` | `/pm/checklists` | 1 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `16003` | `/pm/calendar` | 2 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `17001` | `/jobs/dispatch` | 2 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `17002` | `/jobs/work-orders` | 2 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `17003` | `/jobs/closeout` | 2 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `18001` | `/company/service-settings` | 2 | `LAOO_SERVICE` | true | [`projects/service/lib/features/service/service_route_contract.dart`](../../projects/service/lib/features/service/service_route_contract.dart) |
| `18002` | `/company/service-request-subjects` | 1 | `LAOO_SERVICE` | true | [`projects/service/lib/features/service/service_route_contract.dart`](../../projects/service/lib/features/service/service_route_contract.dart) |
| `19001` | `/reports/dashboard` | 3 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `19002` | `/reports/history` | 3 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `20001` | `/portal/request` | 1 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `20002` | `/portal/tracking` | 3 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `20003` | `/portal/history` | 3 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `20004` | `/portal/pm-schedule` | 3 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |
| `20006` | `/portal/complaint` | 1 | `LAOO_SERVICE` | unspecified | [`projects/service/lib/features/service/service_go_routes.dart`](../../projects/service/lib/features/service/service_go_routes.dart) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `01003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `01005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `01006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `05003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `10006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `12005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `14002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `14003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `14005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `14006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `15001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `15002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `16001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `16002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `16003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `17001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `17002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `17003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `18001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `18002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `19001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `19002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `20001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `20002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `20003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `20004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `20006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
