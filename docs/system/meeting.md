# ระบบห้องประชุม

## ข้อกำหนดปัจจุบันที่มีสเปกยืนยัน

- `21001` จองห้องประชุม และ `21002` ปฏิทิน: ค้นหาตามวัน/ช่วงเวลา หรือห้อง; กรองสาขา อาคาร ชั้น จำนวนคน; ตรวจ Company, ห้องเปิดใช้, เวลาย้อนหลัง, ข้อจำกัดห้อง, ความจุ และการชนกับ `PENDING`/`APPROVED`
- บันทึกการจองเป็น `APPROVED` เมื่อไม่ต้องอนุมัติ หรือ `PENDING` เมื่อกฎห้องกำหนด; ผู้จอง ผู้ดูแลห้อง และ Company Admin แก้ไข/ยกเลิกได้ตามขอบเขต; API ต้องตรวจซ้ำ
- ปฏิทินมีมุมมองเดือน สัปดาห์ วัน และห้อง; API จอง/ค้นหา/ตรวจห้องว่างอยู่ในสเปกย้ายด้านล่าง

## พฤติกรรมที่พบในโค้ดและส่วนที่ยังไม่ยืนยัน

- Route contract มีเมนูประชุมอื่นนอก `21001`/`21002` แต่เอกสาร Function ที่ย้ายไม่ได้ยืนยันรายละเอียดทุกเมนู
- `docs/architecture/MEETING_EXTRACTION_PLAN.md` เป็นแผนสถาปัตยกรรม/placeholder ไม่ใช่สเปก Function ปัจจุบัน

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: ระบบห้องประชุม
- โฟลเดอร์เจ้าของโค้ดหลัก: `projects/meeting`
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `01001` | `partner` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `01004` | `technicalInfo` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `02001` | `laooUser` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `02002` | `partnerUser` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `02003` | `companyUser` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `03001` | `module` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `03002` | `customerModule` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `03003` | `permission` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `04001` | `audit` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `04002` | `loginLog` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `05001` | `companySetup` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `05002` | `masterData` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `06001` | `partnerCompanies` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `06002` | `partnerBranches` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `07001` | `partnerUsers` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `10001` | `companyEmployees` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `10002` | `companyUsers` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `10003` | `companyRoleGroups` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `10004` | `companyMenuPermissions` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `10005` | `organizationStructure` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `10007` | `companySupervisors` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `11001` | `partnerEmployees` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `11002` | `partnerUsers` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `11003` | `partnerRoleGroups` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `11004` | `partnerMenuPermissions` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `11005` | `organizationStructure` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `12001` | `customerEmployees` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `12002` | `laooUsers` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/app/router/app_menu_route_registry.dart`](../../projects/meeting/lib/app/router/app_menu_route_registry.dart) |
| `21001` | `/company/meeting-room-bookings` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/features/meeting/meeting_route_contract.dart`](../../projects/meeting/lib/features/meeting/meeting_route_contract.dart) |
| `21002` | `/company/meeting-room-calendar` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/features/meeting/meeting_route_contract.dart`](../../projects/meeting/lib/features/meeting/meeting_route_contract.dart) |
| `21003` | `/company/meeting-invitations` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/features/meeting/meeting_route_contract.dart`](../../projects/meeting/lib/features/meeting/meeting_route_contract.dart) |
| `21004` | `/company/meeting-room-approvals` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/features/meeting/meeting_route_contract.dart`](../../projects/meeting/lib/features/meeting/meeting_route_contract.dart) |
| `21005` | `/company/meeting-food-plans` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/features/meeting/meeting_route_contract.dart`](../../projects/meeting/lib/features/meeting/meeting_route_contract.dart) |
| `21006` | `/company/meeting-food-order-summary` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/features/meeting/meeting_route_contract.dart`](../../projects/meeting/lib/features/meeting/meeting_route_contract.dart) |
| `21007` | `/company/meeting-food-distribution` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/features/meeting/meeting_route_contract.dart`](../../projects/meeting/lib/features/meeting/meeting_route_contract.dart) |
| `22001` | `/company/room-check-in` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/features/meeting/meeting_route_contract.dart`](../../projects/meeting/lib/features/meeting/meeting_route_contract.dart) |
| `22002` | `/company/room-support-tasks` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/features/meeting/meeting_route_contract.dart`](../../projects/meeting/lib/features/meeting/meeting_route_contract.dart) |
| `22003` | `/company/room-issues` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/features/meeting/meeting_route_contract.dart`](../../projects/meeting/lib/features/meeting/meeting_route_contract.dart) |
| `22004` | `/company/meeting-attendance` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/features/meeting/meeting_route_contract.dart`](../../projects/meeting/lib/features/meeting/meeting_route_contract.dart) |
| `22005` | `/company/meeting-equipment-requests` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/features/meeting/meeting_route_contract.dart`](../../projects/meeting/lib/features/meeting/meeting_route_contract.dart) |
| `22006` | `/company/meeting-system-settings` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/features/meeting/meeting_route_contract.dart`](../../projects/meeting/lib/features/meeting/meeting_route_contract.dart) |
| `23001` | `/company/meeting-buildings` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/features/meeting/meeting_route_contract.dart`](../../projects/meeting/lib/features/meeting/meeting_route_contract.dart) |
| `23002` | `/company/meeting-rooms` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/features/meeting/meeting_route_contract.dart`](../../projects/meeting/lib/features/meeting/meeting_route_contract.dart) |
| `23004` | `/company/meeting-foods` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/features/meeting/meeting_route_contract.dart`](../../projects/meeting/lib/features/meeting/meeting_route_contract.dart) |
| `24001` | `/company/reports/meeting-room-utilization` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/features/meeting/meeting_route_contract.dart`](../../projects/meeting/lib/features/meeting/meeting_route_contract.dart) |
| `24002` | `/company/reports/meeting-no-show` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/features/meeting/meeting_route_contract.dart`](../../projects/meeting/lib/features/meeting/meeting_route_contract.dart) |
| `24003` | `/company/reports/meeting-feedback` | ไม่พบ | `ไม่พบ` | ไม่ระบุ | [`projects/meeting/lib/features/meeting/meeting_route_contract.dart`](../../projects/meeting/lib/features/meeting/meeting_route_contract.dart) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สเปก Function ที่ย้ายจาก `projects/meeting/docs/MEETING_ROOM_BOOKING_FUNCTIONS.md`

# ความสามารถระบบจองห้องประชุม

## ขอบเขตหน้าจอ

- หน้าจอจองห้องประชุมใช้ MenuCode `21001`
- หน้าจอปฏิทินการจองใช้ MenuCode `21002`
- ใช้ข้อมูลห้องประชุม สาขา อาคาร ชั้น ความจุ อุปกรณ์ และกฎประจำห้องจากระบบจริง
- การอ่าน/บันทึกข้อมูลใช้ Company Scope ของผู้ Login

## รูปแบบการค้นหา

ระบบรองรับ 2 รูปแบบ:

1. **ตามวันที่**
   - เลือกวันที่จากปฏิทิน
   - เลือกเวลาเริ่มต้นและเวลาสิ้นสุดแบบ 24 ชั่วโมง
   - เลือกจองวันเดียวหรือหลายวัน
   - ค้นหาห้องว่างตามช่วงวันที่และเวลา
   - กรองสาขา อาคาร ชั้น และจำนวนผู้ใช้งาน

2. **ตามห้องประชุม**
   - เลือกวันที่และเวลาในฝั่งปฏิทิน
   - ชุดค้นหาห้องว่างอยู่ฝั่งเดียวกับปฏิทินและอยู่ด้านบนของปฏิทิน
   - แสดงรายชื่อห้องประชุมให้อยู่ด้านข้างหรือด้านล่างตามขนาดหน้าจอ
   - ตรวจสอบสถานะว่างของห้องที่เลือกโดยตรง

## การตรวจสอบห้องว่าง

เมื่อกดค้นหา ระบบจะตรวจสอบ:

- ห้องต้องอยู่ใน Company เดียวกับผู้ Login และยังเปิดใช้งาน
- ช่วงเวลาต้องไม่ย้อนหลัง
- จำนวนวันล่วงหน้าต้องไม่เกินกฎของห้อง
- ระยะเวลาจองต้องไม่เกินกฎของห้อง
- จำนวนผู้เข้าร่วมต้องไม่เกินความจุห้อง
- ต้องไม่ชนกับรายการจองสถานะ `PENDING` หรือ `APPROVED`
- ถ้าห้องไม่ว่าง จะแสดงสาเหตุและรายการจองที่ชนกัน
- รายการชนกันแสดงวัน เวลา หัวข้อ และชื่อผู้จอง
- ถ้ามากกว่า 3 รายการ ระบบแสดง 3 รายการแรกและมีปุ่มดูทั้งหมด/ซ่อนรายการ

## การจองและแก้ไข

- เมื่อเลือกห้องว่าง สามารถเปิด Popup เพื่อกรอกข้อมูลการจองได้
- ข้อมูลใน Popup ได้แก่ หัวข้อการประชุม จำนวนผู้เข้าร่วม รายละเอียด และหมายเหตุ
- รองรับการจองเวลาไม่ตรงชั่วโมง เช่น `09:15-10:45`
- เวลาเริ่มต้นจะปัดเป็นช่วงละ 5 นาทีตามเวลาปัจจุบัน
- การแก้ไขใช้ Popup เดิม และต้องคงห้อง/วันที่เดิมไว้ ไม่สลับกลับไปหน้าค้นหา
- หลังบันทึกสำเร็จจะแจ้งเตือนและโหลดข้อมูลใหม่
- รายการที่ถูกยกเลิกหรือปฏิเสธจะไม่สามารถแก้ไขต่อได้ตามกติกา API

## การอนุมัติ

กฎประจำห้องรองรับ:

- ไม่ต้องอนุมัติ: บันทึกเป็น `APPROVED` ทันที
- อนุมัติโดยหัวหน้า: อ่านสายบังคับบัญชาของผู้จอง
- กำหนดผู้อนุมัติโดย Admin: ใช้รายชื่อผู้อนุมัติที่กำหนดไว้ในกฎห้อง
- กำหนดได้ว่าจะต้องอนุมัติครบทุกคนหรืออนุมัติคนใดคนหนึ่ง
- รายการที่รออนุมัติใช้สถานะ `PENDING`

## ปฏิทินการจอง

รองรับมุมมอง:

- เดือน: แสดงกรอบวันที่และรายการจองในแต่ละวัน
- สัปดาห์: แสดงรายการตามช่วงสัปดาห์
- วัน: แสดงรายละเอียดรายการของวันที่เลือก
- ห้องประชุม: แสดงห้องประชุมและรายการจองล่วงหน้า 7 วัน

ในมุมมองเดือน หากเลือกวันที่ ระบบควรแสดงรายการจองของวันนั้นทางด้านขวาบนจอกว้าง และแสดงเป็นแผงด้านล่างบนจอแคบ

เมื่อกดปุ่ม “จองวันที่นี้” ระบบควรเปิด Popup จองทันที โดยไม่เปลี่ยนไปหน้าค้นหาห้องและไม่เปลี่ยน Workspace Mode

## สิทธิ์และเจ้าของรายการ

การแก้ไข/ยกเลิกรายการจองควรอนุญาตเฉพาะ:

- เจ้าของรายการจอง
- ผู้ดูแลห้องของห้องนั้น
- Customer Admin ภายใน Company เดียวกัน

ผู้อนุมัติไม่มีสิทธิ์แก้รายละเอียดการจองเพียงเพราะเป็นผู้อนุมัติ Backend ต้องตรวจซ้ำ ไม่ใช่ตรวจเฉพาะการซ่อนปุ่มบนหน้าจอ

## API หลัก

- `GET /api/meeting-room-bookings/actions`
- `GET /api/meeting-room-bookings/options`
- `GET /api/meeting-room-bookings`
- `GET /api/meeting-room-bookings/{id}`
- `POST /api/meeting-room-bookings/availability`
- `POST /api/meeting-room-bookings`
- `PUT /api/meeting-room-bookings/{id}`
- `DELETE /api/meeting-room-bookings/{id}`
- `GET /api/meeting-room-bookings/calendar`

## ไฟล์หลัก

- `lib/features/meeting/pages/meeting_room_booking_page.dart`
- `lib/features/meeting/widgets/meeting_room_calendar_view.dart`
- `lib/features/meeting/data/meeting_room_booking_repository.dart`
- `packages/dotnet/Laoo.Meeting.Module/Controllers/MeetingRoomBookingController.cs`

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `01001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `01004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `02001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `02002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `02003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `03001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `03002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `03003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `04001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `04002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `05001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `05002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `06001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `06002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `07001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `10001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `10002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `10003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `10004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `10005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `10007` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `11001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `11002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `11003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `11004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `11005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `12001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `12002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `21001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `21002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `21003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `21004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `21005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `21006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `21007` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `22001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `22002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `22003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `22004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `22005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `22006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `23001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `23002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `23004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `24001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `24002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `24003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
