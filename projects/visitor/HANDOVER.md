# Visitor handover — 2026-09-27

ผู้รับผิดชอบเดิม: เครื่อง mhon
ผู้รับช่วงชั่วคราว: เครื่อง mon

## ขอบเขตและเมนู

| MenuCode | MenuName | สถานะ source |
| --- | --- | --- |
| 31002 | รับผู้มาติดต่อ | Check-in, รายการผู้ที่อยู่ภายใน, หลักฐาน, ผลการเข้าพบ และ Check-out |
| 31005 | ประวัติผู้มาติดต่อ | มี source; การเปิดใช้งานขึ้นกับ Core metadata |
| 32001 | นัดหมายล่วงหน้า | สร้าง/แก้ไข/ยกเลิกนัดของผู้รับรอง |
| 32002 | สถานะการอนุมัติ | ผู้รับรองอนุมัติหรือปฏิเสธนัด |
| 32003 | ยืนยันการเข้าพบ | Mobile-first host confirmation พร้อมดูหลักฐาน |
| 33001 | กำหนดจุดติดต่อ | CRUD จุดติดต่อและผูกพนักงานประจำจุด |
| 34003 | รายการผิดปกติ | Show-only, filter/pagination/detail อ่านอย่างเดียว |
| 36004 | กำหนดค่าระบบ Visitor | Settings กลางของ Visitor |

## งานที่เสร็จ

- Visitor รองรับ host ตาม Company Business Type, Contact Point, Check-in/Check-out, หลักฐาน DOCUMENT/VEHICLE/OTHER, Visit outcome และ audit
- Appointment, Host confirmation และ Notification outbox อยู่ใน Visitor source
- 34003 route `/visitor/exceptions`, `visitorExceptions` และ `VisitorRoutes.isImplemented=true` อยู่บน `main`; Core metadata activation merge แล้วใน `5c457a0`
- การตรวจ scope อยู่ที่ Backend ตาม Company, Branch และ Contact Point

## งานค้าง / ประเด็นที่ทราบ

- ต้องทดสอบ UAT ทั้ง flow จาก Center runtime หลังเปิด Developer Mode ของ Windows; `flutter pub get` ใน worktree สะอาดถูก block เพราะ Windows ยังไม่เปิด Developer Mode สำหรับ plugin symlink
- Swagger `/swagger/v1/swagger.json` เคยล้มจาก schema ซ้ำใน Time (`AssignmentRequest`); ไม่ใช่ Visitor และไม่ควรแก้จาก Visitor
- ตรวจสิทธิ์/Navigation จริงของ 34003 หลัง Core metadata activation กับบัญชี Company User
- History/Report อื่นที่ metadata ยัง inactive ต้องให้ Core เปิดตามแผนงานแยก

## วิธี run / build / test

```powershell
dotnet build .\laoo_api\laoo_api.csproj
C:\src\flutter\bin\flutter.bat analyze projects\visitor
C:\src\flutter\bin\flutter.bat test projects\visitor\test
powershell -ExecutionPolicy Bypass -File .\tools\scripts\check-machine-boundaries.ps1 -Module visitor
powershell -ExecutionPolicy Bypass -File .\tools\scripts\verify-center.ps1 -Module visitor
```

Runtime มาตรฐาน Center: API `http://localhost:5080`, Flutter Web `http://localhost:8080`.

ผลล่าสุดก่อน handover: API build ผ่าน (มีคำเตือน SixLabors ImageSharp license ที่มีอยู่เดิม), Flutter analyze/test ผ่านบน source ที่มี dependency พร้อม, Boundary Check ผ่าน. Verify Center ใน worktree ใหม่ยังรอ Developer Mode.

## Migrations

Visitor migrations อยู่ที่ `projects/visitor/database/migrations/`:

- `20260920150000_LAOO_VISITOR_settings_and_checkin.sql`
- `20260920162000_LAOO_VISITOR_multi_host.sql`
- `20260920213000_LAOO_VISITOR_guarantor_by_room.sql`
- `20260920223000_LAOO_VISITOR_contact_points.sql`
- `20260921100000_LAOO_VISITOR_business_location_hosts.sql`
- `20260923100000_LAOO_VISITOR_visit_outcome_evidence.sql`
- `20260924100000_LAOO_VISITOR_host_confirmation.sql`
- `20260924110000_LAOO_VISITOR_host_confirmation_repair.sql`
- `20260924120000_LAOO_VISITOR_appointments.sql`
- `20260924130000_LAOO_VISITOR_appointment_rental_host.sql`
- `20260925140000_LAOO_VISITOR_notification_outbox.sql`

สถานะ apply ของแต่ละเครื่อง/DB ต้องตรวจจาก DBTDLaooService ก่อนรันเพิ่ม ใช้เท่านั้น:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\scripts\run-migrations.ps1 -Module visitor
```

## การพึ่งพา Core / งานอื่น

- Core Navigation metadata และ permission เป็น source of truth ของทุก MenuCode
- Host identity, host notification recipient, Company Business Type และ location ใช้ Shared Contract ของ Core เท่านั้น
- Notification inbox/email channel เป็น Core-owned; Visitor มีเฉพาะ outbox/event ของตน
- ห้ามแก้ Root Router, Authentication, Person, User, Employee หรือ Core schema จากงาน Visitor

## Config / ข้อมูลที่ต้องส่งแยก (ห้าม commit)

- `local.machine.json` และ appsettings/connection strings
- DBTDLaooService และข้อมูล Company/Branch/Employee/Resident/Host ที่ใช้ UAT
- uploads ภายใต้ API Server `wwwroot/uploads/visitor/`
- SMTP/Notification/Company setup ที่ตั้งค่ากลาง
- Flutter SDK cache และ build/runtime logs

## การส่งต่อ

Branch นี้เก็บการแก้ข้อความไทยของ 34003 และเอกสาร handover เท่านั้น ไม่ merge main ในรอบรวบรวมนี้. หลังเครื่อง mon ยืนยันรับงานครบ ให้ใช้ branch นี้เป็นจุดอ้างอิงและตรวจ main ล่าสุดก่อนทำงานต่อ.
