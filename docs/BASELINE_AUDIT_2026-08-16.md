# LAOO Baseline Audit — 2026-08-16

## Result

Flutter และ API ผ่านการตรวจ Source/Build/Test ที่ทำได้โดยไม่เปลี่ยน Schema ฐานข้อมูล โครงสร้างราก `C:\laoo` ถูกจัดให้เหลือ Project หลัก เอกสาร Script เครื่องมือ และ Archive ชัดเจน พร้อม Workspace กลาง `laoo.code-workspace`

## Completed

### Repository and files

- เพิ่ม `.gitattributes` และปรับ `.gitignore` สำหรับ Flutter, .NET, Secret, Build, Publish, Temp และ Archive
- ย้าย `api_token` จากรากไป `.secrets\api_token`
- ย้ายงานเก่า/สำรองที่ไม่ถูกอ้างอิงไป `archive\legacy`, `archive\artifacts`, `archive\notes` และ `archive\generated-output`
- ลบ Build, Temp และ Log ที่สร้างใหม่ได้ รวมถึง log Emulator เก่าประมาณ 2 GB
- เพิ่ม `laoo.code-workspace` สำหรับ App, API, Docs, SQL Scripts และ Build Tools

### Flutter

- Theme/Style ใช้สีจาก Preset กลาง และไม่บังคับ Light/White ใน Shared Shell
- Route ทุกหน้าที่เป็นเมนูตรวจ `VIEW` จาก Navigation API ด้วย `MenuCode`; URL ตรง fail-closed
- Navigation permission cache แยกตาม Session/User และล้างเมื่อ Logout/Refresh
- หยุดเก็บ Password ใน SharedPreferences
- ย้าย Access Token ไป `flutter_secure_storage` และรองรับย้าย Token เก่าครั้งแรก
- Alert/SnackBar อ่าน `TDSTCompanySetUp.TimeAlert`, ปิดเองและกดปิดได้
- เพิ่ม Android Internet permission, ปิด Auto Backup, ตั้งชื่อแอป `LAOO` และใช้ Launcher Icon จริง
- หน้า Landing รองรับจอแคบและ Large Text โดยไม่ Overflow
- API URL และ Project Code รับจาก `--dart-define`

### API and security

- Login บังคับ `ProjectCode`; ไม่มี fallback เป็น `LAOO`
- JWT/Context ใช้ `user_type`, stable user ID และ `project_id`
- ตรวจ Project membership สำหรับ Company/Partner และปิด Partner cross-scope access
- Backend ตรวจ Permission ของ Company/Branch/Role/Menu actions ซ้ำทุก Action ที่แก้ไข
- Password case-sensitive; policy ขั้นต่ำ 12 ตัว พร้อมตัวใหญ่ ตัวเล็ก ตัวเลข และอักขระพิเศษ
- Login ผิด 5 ครั้งล็อก 15 นาที
- Forgot Password ตอบข้อความกลาง ป้องกัน account enumeration; Reset token ผูก Project และ Transaction rollback ครบ
- เพิ่ม Rate Limit สำหรับ Login/Forgot/Reset
- Technical Info เปิดเฉพาะ Development และจำกัด path/extension
- Production ใช้ persistent Data Protection key ring, HSTS, configured CORS และ Console logging ที่เหมาะกับ Plesk/IIS
- เพิ่ม `/health` ตรวจ API และ SQL Server
- `local.json` และ `appsettings.Local.json` ถูกตัดออกจาก Publish เสมอ

## Verification

- `flutter analyze --no-pub`: ผ่าน ไม่มี Issue
- `flutter test --no-pub`: ผ่าน 25 Tests
- API Release Build: ผ่าน 0 Warnings / 0 Errors
- `GET /health` กับ SQL Server จริง: `200 {"status":"Healthy"}`
- API Cloud ZIP: 66 entries, forbidden secret files 0
- APK: Compile SDK 36, Internet permission, application label `LAOO`, V2 signature valid

## Build artifacts

- `C:\laoo\publish\laoo_api_cloud.zip`
  - SHA-256: `8900A3C4846DCB22BB1DAD3C0E036D09534B28357C72E0BF2DB0C98F14F5CC13`
- `C:\laoo\publish\laoo-LAOO-test.apk`
  - API: `https://api-plaza.nod-finger.com`
  - Project: `LAOO`
  - SHA-256: `48C6827BA8DD9125D57AF6DBCED670A81B7AB824147A96CE358A1B0F89524152`

## Decisions required before production baseline

1. Typography Standard มีค่าขัดกัน (`Page Title 28` กับ runtime/AGENTS `18`, Body/Button `12` กับ `13`, Input Label `16` กับ `13`) จึงยังไม่ปรับตัวเลข Typography จนกว่า Product Owner จะเลือกค่ามาตรฐานเดียว
2. Partner Admin จริง 6 บัญชียังไม่มี Project Permission/Role ทั้ง `LAOO` และ `LAOO_MEETING`; Security ใหม่จะไม่ให้ Login จนกว่าจะกำหนด Grant ชัดเจน ห้ามใช้ Admin bypass โดยเดา
3. SQL Delivery ยังไม่ reproducible: API ใช้ Table มากกว่า Script ที่มี, หลาย Script ไม่มี `USE`, หลาย Script hard-code `DBTDLaoo`, และ Meeting route เดิมชี้ `DBTDMeeting` ไม่ใช่ชื่อเป้าหมาย `DBLaooMeeting`
4. Test APK ยังใช้ package ID `com.example.laoo` และ Android Debug Signing Key ต้องกำหนด Production Application ID และ Release Keystore ก่อน Store/แจก Production
5. Source ชุดใหญ่ใน Working Tree รวม Feature Profile/Favorite/Password Reset ยังไม่ได้ Commit/Push ต้อง Review และ Commit เป็น Baseline ก่อนแตก Project ใหม่

## Project 2 gate

ยังไม่ควร Copy `laoo` ไปเป็น Project Meeting จนกว่าจะปิดข้อ 1–5 จากนั้นให้สร้าง Project/Workspace/API/Database แยก และใช้ส่วนกลางผ่านมาตรฐาน/Template/Build Tools แทนการแชร์ไฟล์ Source แบบแก้พร้อมกัน
