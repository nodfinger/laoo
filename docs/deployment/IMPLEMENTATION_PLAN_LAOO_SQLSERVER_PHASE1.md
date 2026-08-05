# LAOO SQL SERVER READ — PHASE 1

Version: 1.0  
Last Update: 2026-08-05

---

# Goal

ให้ Project `laoo` อ่านสถานะการเชื่อมต่อ SQL Server ผ่าน ASP.NET Core Web API ได้จริง

---

# Phase 1 Steps

## Step 1 — Documentation

- เพิ่ม `SYSTEM_INFO_API.md`
- เพิ่ม `API_ERROR_STANDARD.md`
- อัปเดต `C:\laoo\laoo\PROJECT.md`

## Step 2 — Backend Project

สร้าง Project ใหม่ในอนาคตที่

```text
C:\laoo\laoo_api
```

Technology

```text
ASP.NET Core Web API
SQL Server
Dapper หรือ ADO.NET ตาม Standard ที่อนุมัติ
```

## Step 3 — Database Connection

กำหนด Connection String ฝั่ง Server เท่านั้น

ทดสอบด้วย Query

```sql
SELECT 1 AS IsConnected;
```

## Step 4 — API Endpoint

สร้าง

```http
GET /api/system/info
```

## Step 5 — Flutter Integration

Project

```text
C:\laoo\laoo
```

เรียก API และแสดง

- System Name
- Server Time
- Database Status

## Step 6 — Verification

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

และทดสอบ API แยกก่อนเชื่อม Flutter

---

# Information Required Before Backend Code

ก่อนสร้าง `laoo_api` ต้องยืนยันข้อมูลต่อไปนี้

- SQL Server Version
- SQL Server Host หรือ IP
- Database Name
- Authentication Mode
- ชื่อ Table จริงที่ต้องอ่านในงานถัดไป
- .NET SDK Version ที่ติดตั้ง
- ต้องการใช้ Dapper หรือ ADO.NET
- Port และ URL ที่ต้องการให้ API Run
- API จะ Run บนเครื่องเดียวกับ SQL Server หรือคนละเครื่อง

ห้ามใส่ Password จริงลงใน Chat หรือไฟล์ Markdown
