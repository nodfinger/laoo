# Laoo API — Phase 1 Foundation

ตำแหน่งติดตั้ง:

```text
C:\laooplatformplatformplatform\laoo\laoo_service_api
```

## สำคัญ

โฟลเดอร์นี้ต้องมีไฟล์ Project เพียงไฟล์เดียว:

```text
laoo_service_api.csproj
```

ก่อนวางทับ แนะนำให้สำรองโฟลเดอร์เดิม และเก็บ `local.json` ไว้นอก ZIP

```text
Laoo.Service.Api.csproj
laoo_service_api.csproj เดิม
```

จากนั้นแตกชุด Version 2 ลงในโฟลเดอร์ใหม่ที่สะอาด

## ขั้นตอนติดตั้ง

1. เปลี่ยนชื่อโฟลเดอร์เดิม:

```powershell
Rename-Item C:\laooplatformplatformplatform\laoo\laoo_service_api C:\laooplatformplatformplatform\laoo\laoo_service_api_backup
```

2. สร้างโฟลเดอร์ใหม่และแตก ZIP ลงไป:

```powershell
New-Item -ItemType Directory C:\laooplatformplatformplatform\laoo\laoo_service_api
```

3. คัดลอก `local.json` เดิมจากโฟลเดอร์ Backup กลับมา หรือสร้างจาก `local.example.json`

4. รัน SQL ตามลำดับ:

```text
C:\laooplatformplatform\scripts\phase1\MIGRATE_DATABASE_ROUTING_V1.sql
C:\laooplatformplatform\scripts\phase1\MIGRATE_AUTH_CONSTRAINTS_V1.sql
```

5. รัน API:

```powershell
cd C:\laooplatformplatformplatform\laoo\laoo_service_api
dotnet run --project .\laoo_service_api.csproj
```

6. เปิด:

```text
https://localhost:7080/swagger
```

## สิ่งที่เพิ่มใน Phase 1

- Support Login เดิมยังทำงานเหมือนเดิม
- Company User Login ผ่าน Username/Password/ProjectCode เดิม
- Database Routing แบบ Company → Partner → Default
- `GET /api/database-routing/current` สำหรับตรวจ Route และทดสอบ Connection
- Connection String จริงอยู่ใน `local.json` เท่านั้น

## ทดสอบ

```text
ใช้ `test_login.http` หรือ Swagger โดย Login ก่อน แล้วกด Authorize ด้วย JWT
```

## local.json

```json
{
  "ConnectionStrings": {
    "LaooDatabase": "ค่าจริง"
  },
  "Jwt": {
    "SecretKey": "อย่างน้อย 32 ตัวอักษร"
  }
}
```

`local.json` ถูก ignore โดย Git

## Production / Plesk

ไฟล์ `local.json` และ `appsettings.Local.json` ถูกตัดออกจากผล Publish เสมอ ห้ามอัปโหลดไฟล์ Secret ไปกับ ZIP ให้กำหนดค่าผ่าน Environment Variables ของ Hosting:

```text
ASPNETCORE_ENVIRONMENT=Production
ConnectionStrings__LaooDatabase=<SQL Server connection string>
Jwt__SecretKey=<random secret อย่างน้อย 32 ตัวอักษร>
DataProtection__ApplicationName=Laoo.Service.Api
DataProtection__KeyRingPath=<absolute persistent writable folder>
SeedData__Enabled=false
```

หากให้ Flutter Web เรียก API ให้เพิ่ม Origin ที่อนุญาต เช่น:

```text
Cors__AllowedOrigins__0=https://app.example.com
```

Flutter Android/iOS ไม่อยู่ภายใต้ CORS แต่ต้อง Build ด้วย API URL จริง:

```powershell
flutter build apk --release --dart-define=API_URL=https://api.example.com --dart-define=PROJECT_CODE=LAOO
```

หลัง Deploy ให้ตรวจ `GET /health` ซึ่งจะคืนสถานะ API และการเชื่อมต่อฐานข้อมูล โดยไม่เปิดเผย Secret
