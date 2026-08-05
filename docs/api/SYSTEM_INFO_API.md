# SYSTEM_INFO_API

Version: 1.0  
Last Update: 2026-08-05  
Owner: CI / BA / DBA  
Status: Draft for Implementation

---

# Purpose

กำหนด API Contract แรกของ Project `laoo` สำหรับทดสอบการอ่านข้อมูลจริงจาก SQL Server ผ่าน ASP.NET Core Web API

เป้าหมายคือพิสูจน์การเชื่อมต่อแบบครบสาย

```text
Flutter
   ↓ HTTP
ASP.NET Core Web API
   ↓
SQL Server
```

---

# Endpoint

```http
GET /api/system/info
```

---

# Authentication

Version 1:

```text
Not Required
```

Endpoint นี้ใช้สำหรับทดสอบการเชื่อมต่อเท่านั้น

ห้ามส่งข้อมูลลับ เช่น Connection String, Password, Server Name ภายใน Response

---

# Request

ไม่มี Request Body

ตัวอย่าง

```http
GET /api/system/info
Accept: application/json
```

---

# Success Response

HTTP Status:

```text
200 OK
```

Response Body:

```json
{
  "systemName": "Laoo",
  "version": "1.0.0",
  "serverTime": "2026-08-05T22:00:00+07:00",
  "databaseStatus": "Connected"
}
```

---

# Response Fields

| Field | Type | Required | Description |
|---|---|---:|---|
| `systemName` | string | Yes | ชื่อระบบ |
| `version` | string | Yes | Version ของ API หรือระบบ |
| `serverTime` | string | Yes | เวลาฝั่ง Server รูปแบบ ISO 8601 |
| `databaseStatus` | string | Yes | สถานะการเชื่อมต่อ Database |

ค่าที่อนุญาตสำหรับ `databaseStatus`

```text
Connected
Unavailable
```

---

# Database Verification

API ต้องตรวจสอบ SQL Server ด้วย Query ที่ปลอดภัยและไม่มีผลกระทบต่อข้อมูล

ตัวอย่างแนวคิด

```sql
SELECT 1 AS IsConnected;
```

Version 1 ยังไม่อ่านข้อมูล Business Table

---

# Error Response

## Database Unavailable

HTTP Status:

```text
503 Service Unavailable
```

Response Body:

```json
{
  "code": "DATABASE_UNAVAILABLE",
  "message": "ไม่สามารถเชื่อมต่อฐานข้อมูลได้ในขณะนี้",
  "traceId": "server-generated-trace-id"
}
```

## Internal Error

HTTP Status:

```text
500 Internal Server Error
```

Response Body:

```json
{
  "code": "INTERNAL_SERVER_ERROR",
  "message": "เกิดข้อผิดพลาดภายในระบบ",
  "traceId": "server-generated-trace-id"
}
```

---

# Security Rules

- ห้ามส่ง Connection String กลับไปยัง Client
- ห้ามส่งชื่อผู้ใช้หรือรหัสผ่าน Database
- ห้ามส่งรายละเอียด Exception ภายใน Response
- ต้องบันทึก Error ฝั่ง Server พร้อม Trace ID
- Endpoint นี้ต้องถูกจำกัดหรือถอดออกจาก Production หากไม่มีความจำเป็น
- Flutter Client ต้องเชื่อเฉพาะ HTTPS ใน Production

---

# Definition of Done

- API Run ได้
- API เชื่อม SQL Server ได้
- `GET /api/system/info` คืนค่า `200`
- Response ตรงตาม Contract
- เมื่อ Database ใช้งานไม่ได้ คืนค่า `503`
- Flutter อ่าน JSON ได้
- Flutter แสดง `systemName`, `serverTime` และ `databaseStatus` ได้
