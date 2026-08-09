# Laoo API — Phase 1 Foundation

ตำแหน่งติดตั้ง:

```text
C:\laoo\laoo_api
```

## สำคัญ

โฟลเดอร์นี้ต้องมีไฟล์ Project เพียงไฟล์เดียว:

```text
laoo_api.csproj
```

ก่อนวางทับ แนะนำให้สำรองโฟลเดอร์เดิม และเก็บ `local.json` ไว้นอก ZIP

```text
Laoo.Api.csproj
laoo_api.csproj เดิม
```

จากนั้นแตกชุด Version 2 ลงในโฟลเดอร์ใหม่ที่สะอาด

## ขั้นตอนติดตั้ง

1. เปลี่ยนชื่อโฟลเดอร์เดิม:

```powershell
Rename-Item C:\laoo\laoo_api C:\laoo\laoo_api_backup
```

2. สร้างโฟลเดอร์ใหม่และแตก ZIP ลงไป:

```powershell
New-Item -ItemType Directory C:\laoo\laoo_api
```

3. คัดลอก `local.json` เดิมจากโฟลเดอร์ Backup กลับมา หรือสร้างจาก `local.example.json`

4. รัน SQL ตามลำดับ:

```text
C:\laoo\scripts\phase1\MIGRATE_DATABASE_ROUTING_V1.sql
C:\laoo\scripts\phase1\MIGRATE_AUTH_CONSTRAINTS_V1.sql
```

5. รัน API:

```powershell
cd C:\laoo\laoo_api
dotnet run --project .\laoo_api.csproj
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
