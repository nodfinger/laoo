# Laoo Flutter Login API Update

## เป้าหมาย

เชื่อมหน้า Login ของ Project `laoo` กับ Laoo API จริง

```text
ProjectCode: LAOO
API: http://localhost:5081
Username: t
Password: t
```

## วิธีติดตั้ง

แตก ZIP ลงที่:

```text
C:\laooplatform\laoo_service
```

กดยืนยัน Replace ไฟล์เดิม

จากนั้นรัน:

```powershell
cd C:\laooplatform\laoo_service
powershell -ExecutionPolicy Bypass -File .\apply_laoo_flutter_login_update.ps1
```

## ก่อนเปิด Flutter

เปิด PowerShell อีกหน้าต่างและรัน API:

```powershell
cd C:\laooplatform\laoo_service\laoo_service_api
dotnet run --project .\laoo_service_api.csproj
```

ต้องเห็น:

```text
Now listening on: http://localhost:5081
```

## รัน Flutter

```powershell
cd C:\laooplatform\laoo_service
flutter run -d windows
```

## ทดสอบ

```text
Username: t
Password: t
```

เมื่อสำเร็จจะเปิดหน้า Dashboard ทดสอบ ซึ่งแสดง:

- Display Name
- Username
- ProjectCode
- Login Mode
- Login As User Permission
- Token Expiration

กด “ออกจากระบบ” แล้วระบบล้าง Session และกลับ Landing Page

## ไฟล์ที่เพิ่ม

```text
lib/core/config/app_config.dart
lib/features/auth/data/models/login_models.dart
lib/features/auth/data/services/auth_api_service.dart
lib/features/auth/data/services/auth_session_service.dart
lib/features/home/presentation/pages/authenticated_home_page.dart
```

## ไฟล์ที่แก้

```text
lib/app/laoo_app.dart
lib/features/auth/presentation/pages/login_page.dart
pubspec.yaml (ผ่าน PowerShell Script)
```

## หมายเหตุ

ชุดนี้ใช้ `http://localhost:5081` สำหรับ Development เพื่อหลีกเลี่ยงปัญหา HTTPS Development Certificate บน Flutter Windows

เมื่อ Deploy Production ต้องเปลี่ยนเป็น HTTPS URL จริง
