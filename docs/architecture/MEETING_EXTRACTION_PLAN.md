# Meeting Extraction Plan

สถานะเอกสาร: ดำเนิน Extraction แล้ว โดยไม่แก้ UX และไม่เปลี่ยนฐานข้อมูล

## ผลดำเนินการ

- Flutter Source ธุรกิจ Meeting อยู่ที่ `projects/meeting/lib/features/meeting` จุดเดียว
- Root เพิ่ม Path dependency `laoo_meeting` และ import หน้าธุรกิจผ่าน `meeting_feature.dart`
- เพิ่ม Host Adapter ทำให้ Root ใช้ Sidebar/Login/Session ของ Core ส่วน Meeting standalone ใช้ Host เดิมของ Meeting
- RouteName, RoutePath, MenuCode และ ScreenType ของ 15 Route อยู่ใน `meeting_route_contract.dart`
- ลบ Root `lib/features/meeting` ที่ซ้ำ 17 ไฟล์แล้ว
- Meeting API controllers อยู่ใน `projects/meeting/packages/dotnet/Laoo.Meeting.Module` จุดเดียว
- Core API และ Meeting API Host โหลด Controller จาก Module เดียวกัน
- ลบ Controller ซ้ำจาก API Host 16 ไฟล์ และย้าย `MasterGroupCodes.cs` เข้า Module
- คงการตรวจ Company entitlement `LAOO_MEETING` ไว้ใน Module
- Swagger ของทั้งสอง API Host แสดง Meeting endpoints ตรงกัน 40 paths

## เป้าหมายและ Source of Truth

- เจ้าของ Source ธุรกิจ Meeting คือ `projects/meeting` เท่านั้น
- LAOO Core เรียกใช้ Meeting ผ่าน Module/Package ที่อยู่ใต้ `projects/meeting` ห้ามมีสำเนา `lib/features/meeting` อีกชุดใน Root
- หน้าส่วนกลางยังเป็นเจ้าของโดย Core/Shared Package ได้แก่ Login, Profile, Branch, Employee, Organization, User, Role, Permission, Company setup, Navigation และ Theme/Shell
- ยังไม่ลบไฟล์ซ้ำที่มีผู้เรียกใช้ จนกว่า App ทั้งสองฝั่งเปลี่ยนไปอ้าง Module กลางและผ่าน Build

## 1. หน้าธุรกิจ Meeting

### Route ที่มีหน้าจอจริงแล้ว

| MenuCode | ScreenType | RouteName / RoutePath | Page หลัก | API หลัก |
|---|---:|---|---|---|
| 21001 | 1 | `meetingRoomBookings` / `/company/meeting-room-bookings` | `meeting_room_booking_page.dart` | `/api/company/meeting-room-bookings` |
| 21002 | 3 | `meetingRoomCalendar` / `/company/meeting-room-calendar` | `meeting_room_booking_page.dart` (`initialCalendar: true`) | `/api/company/meeting-room-bookings/calendar` |
| 21003 | 2 | `meetingInvitationRsvp` / `/company/meeting-invitations` | `meeting_invitation_page.dart` | `/api/company/my-meeting-invitations` |
| 21004 | 2 | `meetingRoomApprovals` / `/company/meeting-room-approvals` | `meeting_room_approval_page.dart` | `/api/company/meeting-room-bookings/approval-requests` |
| 21005 | 1 | `meetingFoodPlans` / `/company/meeting-food-plans` | `meeting_food_plan_page.dart` | `/api/company/meeting-food-plans` |
| 23001 | 1 | `meetingBuildings` / `/company/meeting-buildings` | `meeting_building_page.dart` | `/api/company/meeting-structure` |
| 23002 | 1 | `meetingRooms` / `/company/meeting-rooms` | `meeting_room_page.dart` | `/api/company/meeting-rooms` และ rules |
| 23003 | 1 | `meetingFacilities` / `/company/meeting-facilities` | `meeting_facility_page.dart` | `/api/company/meeting-facilities` |
| 23004 | 1 | `meetingFoods` / `/company/meeting-foods` | `meeting_food_page.dart` | `/api/company/meeting-foods` |

### Route ที่ยังเป็น Placeholder

| MenuCode | ScreenType | RouteName / RoutePath | สถานะ |
|---|---:|---|---|
| 22001 | 2 | `roomCheckIn` / `/company/room-check-in` | ไม่มี Page และ API ธุรกิจ |
| 22002 | 2 | `roomSupportTasks` / `/company/room-support-tasks` | ไม่มี Page และ API ธุรกิจ |
| 22003 | 1 | `roomIssues` / `/company/room-issues` | ไม่มี Page และ API ธุรกิจ |
| 24001 | 3 | `meetingRoomUtilizationReport` / `/company/reports/meeting-room-utilization` | ไม่มี Page และ API ธุรกิจ |
| 24002 | 3 | `meetingNoShowReport` / `/company/reports/meeting-no-show` | ไม่มี Page และ API ธุรกิจ |
| 24003 | 3 | `meetingFeedbackReport` / `/company/reports/meeting-feedback` | ไม่มี Page และ API ธุรกิจ |

## 2. ไฟล์ธุรกิจที่ให้ `projects/meeting` เป็นเจ้าของ

ย้ายเข้า Module เดียวใต้ `projects/meeting` โดยคง UX ของฝั่ง Meeting ตามปัจจุบัน:

```text
lib/features/meeting/data/
  meeting_facility_repository.dart
  meeting_food_plan_repository.dart
  meeting_food_repository.dart
  meeting_invitation_repository.dart
  meeting_room_booking_repository.dart
  meeting_room_repository.dart
  meeting_structure_repository.dart

lib/features/meeting/pages/
  meeting_building_page.dart
  meeting_facility_page.dart
  meeting_food_page.dart
  meeting_food_plan_page.dart
  meeting_invitation_page.dart
  meeting_room_approval_page.dart
  meeting_room_booking_page.dart
  meeting_room_page.dart

lib/features/meeting/widgets/
  meeting_room_calendar_view.dart
```

ไฟล์ Root `lib/features/meeting/data/meeting_company_directory_repository.dart` ไม่ใช่ Business owner ที่ถูกต้อง เพราะเป็น Adapter ของ Branch/Employee/Organization ส่วนกลาง และถูกหน้า `organization_supervisor_page.dart` เรียกย้อนกลับ ต้องแทนด้วย Contract จาก Shared Admin ก่อนลบ

## 3. หน้าส่วนกลางที่พบใน Meeting App

ไฟล์ต่อไปนี้จำเป็นต่อการ Login/Shell หรือถูกคัดลอกมาเพื่อให้ Meeting รันเดี่ยว แต่ไม่ใช่ Source ธุรกิจ Meeting:

- `features/auth`: Login และ Reset password
- `features/home`, `features/landing`: Home/Landing
- `features/profile`: User profile dialog
- `features/access`: Role group และ Menu permission
- `features/partner`: Customer และ Customer user
- `features/support/branch`: สาขา
- `features/support/employee`: พนักงาน
- `features/support/organization`: โครงสร้างองค์กรและผู้บังคับบัญชา
- `features/support/partner_user`: ผู้ใช้งาน
- `features/support/company_setup`, `master_data`, `technical_info`
- `features/support/presentation`: Shared workspace shell และ placeholder
- `app/theme`, `core/api`, `core/navigation`, `core/widgets`, `app/router`: Infrastructure ส่วนกลาง

ข้อสรุป: Meeting App ใช้ของส่วนกลางได้ แต่ห้ามเป็นเจ้าของหรือ Copy ไปพัฒนาแยก ให้เปลี่ยนไปอ้าง `packages/laoo_shared_*` และ Core contract ทีละส่วน

## 4. Route ที่ต้อง Extraction

Source ปัจจุบันซ้ำอยู่ทั้ง:

```text
lib/app/router/route_names.dart
lib/app/router/route_paths.dart
lib/app/router/app_menu_route_registry.dart
lib/app/router/app_router.dart

projects/meeting/lib/app/router/route_names.dart
projects/meeting/lib/app/router/route_paths.dart
projects/meeting/lib/app/router/app_menu_route_registry.dart
projects/meeting/lib/app/router/app_router.dart
```

ให้สร้าง Meeting route contract ใต้ `projects/meeting` ซึ่ง export RouteName, RoutePath, MenuCode และ Route builder ของกลุ่ม 21-24 แล้วให้ Root Router และ Meeting Router compose contract ชุดเดียวกัน

`10007 companySupervisors` เป็นหน้าส่วนกลาง ต้องไม่อยู่ใน Meeting route module แม้เดิมจะเคยแทรกอยู่ใน `_meetingRoutes`

## 5. API ธุรกิจที่ต้องย้ายเป็น Module

เจ้าของ Source คือ `projects/meeting/laoo_meeting_api/Controllers`:

| Controller | Base Route | ScreenCode |
|---|---|---|
| `MeetingRoomBookingController.cs` | `api/company/meeting-room-bookings` | 21001, 21002, 21004 |
| `MeetingInvitationController.cs` | `api/company/my-meeting-invitations` | 21003 |
| `MeetingFoodPlanController.cs` | `api/company/meeting-food-plans` | 21005 |
| `MeetingStructureController.cs` | `api/company/meeting-structure` | 23001 |
| `MeetingRoomController.cs` | `api/company/meeting-rooms` | 23002 |
| `MeetingRoomRuleController.cs` | `api/company/meeting-rooms/{roomId}/rules` | 23002 |
| `MeetingFacilityController.cs` | `api/company/meeting-facilities` | 23003 |
| `MeetingFoodController.cs` | `api/company/meeting-foods` | 23004 |

ทั้ง 8 Controller มีสำเนาใน `laoo_api/Controllers` แต่ Hash ไม่ตรงกัน จึงห้ามเลือกลบทิ้งโดยเดา ให้ย้าย Source ฝั่ง `projects/meeting` เข้า .NET class library เช่น `projects/meeting/packages/dotnet/Laoo.Meeting.Module` แล้วให้ทั้ง `laoo_api` และ `laoo_meeting_api` register controllers จาก assembly เดียวกัน ก่อนลบ Controller ซ้ำจาก Host ทั้งสองฝั่ง

Controller ส่วนกลางใน `laoo_meeting_api` เช่น Auth, Navigation, Permission, Branch, Employee, Organization, Partner และ Company setup ยังต้องคงไว้จนกว่าจะมี Shared API module หรือ Meeting เปลี่ยนไปเรียก Core API/Gateway

## 6. Dependency ที่ต้องแยกก่อนย้าย Page

ลำดับ Dependency ฝั่ง Flutter:

1. API abstraction: `ApiClient`, `ApiException`, API URL/config ไปอยู่ `laoo_shared_core`
2. Owner scope และ Directory contract: Branch, Employee, Organization ใช้ `laoo_shared_admin` ที่มีอยู่แล้ว
3. Shared UI bridge: Theme token, Typography, Workspace shell, Alert overlay, Combo box และ Profile launcher ต้องมี interface/export จาก package กลาง
4. Navigation contract: Menu caption, permission/action และ route context ต้องไม่ import repository จาก App host โดยตรง
5. Meeting route contract: MenuCode 21-24, names, paths และ builders
6. Meeting feature module: Page, repository และ widget ทั้ง 16 ไฟล์

Package ภายนอกที่ Meeting feature ใช้โดยตรง:

- `flutter`
- `go_router`
- `file_picker`
- `image`

ตารางธุรกิจหลักที่ API อ้าง ได้แก่ `TDADMeetingRoom`, `TDADMeetingFacility`, `TDADMeetingFood`, `TDADMeetingRoomBooking*`, `TDADMeetingRoomBookingRule*`, `TDADMeetingBookingFood*`, `TDADBuilding`, `TDADFloor` และตารางส่วนกลาง Branch/Employee/Organization/User/Permission/Master ซึ่งต้องรักษา CompanyID และ Project permission scope

## 7. ลำดับดำเนินการจริง

1. เพิ่ม Contract/Adapter ที่ขาดใน Shared packages โดยยังไม่เปลี่ยน UX
2. สร้าง Flutter Meeting feature module ใต้ `projects/meeting` และย้าย Source ฝั่ง Meeting เข้า Module แบบคงโค้ดเดิม
3. ให้ Meeting App ใช้ Module แล้ว Build/Test ที่ 8083/5083
4. ให้ LAOO Core ใช้ Module เดียวกัน แล้ว Build/Test ที่ 8080/5080
5. เมื่อทั้งสอง App ไม่ import `lib/features/meeting` ชุดเดิมแล้ว จึงลบ Root duplicate ทั้งชุด
6. สร้าง .NET Meeting module จาก Controller ฝั่ง `projects/meeting`
7. ให้ API Host ทั้งสอง register Module เดียวกันและทดสอบ Permission/Company scope
8. ลบ Controller Meeting ที่ซ้ำจาก Host หลัง Integration ผ่าน
9. ค่อยสร้างหน้าจอ/API สำหรับ 6 Placeholder เป็นงานแยก ห้ามรวมกับ Extraction

## 8. เกณฑ์ลบไฟล์ซ้ำ

- Hash ตรงอย่างเดียวไม่เพียงพอ ต้องไม่มี import/reference เหลือใน App เดิม
- Root และ Meeting ต้อง `flutter analyze`, `flutter test` และ build ผ่านก่อนลบ
- API Host ทั้งสองต้อง build และ endpoint smoke test ผ่านก่อนลบ Controller
- ลบเป็น Commit แยกจากการปรับ UX เพื่อย้อนกลับได้ชัดเจน

ผลหลัง Extraction: Reference ถูกเปลี่ยนไปยัง Source หลักแล้ว จึงลบไฟล์ Flutter และ API ที่ซ้ำได้ครบโดย Build/Test ผ่าน
