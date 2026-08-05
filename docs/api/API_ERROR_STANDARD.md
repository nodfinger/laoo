# API_ERROR_STANDARD

Version: 1.0  
Last Update: 2026-08-05  
Owner: BA / SEC / QA  
Status: Active

---

# Purpose

กำหนดรูปแบบ Error Response กลางสำหรับ API ของ Laoo Solutions

---

# Standard Error Response

```json
{
  "code": "ERROR_CODE",
  "message": "ข้อความสำหรับผู้ใช้งาน",
  "traceId": "server-generated-trace-id"
}
```

---

# Rules

- `code` ใช้ตัวพิมพ์ใหญ่และ `_`
- `message` ต้องเป็นข้อความที่ผู้ใช้เข้าใจได้
- `traceId` ต้องสร้างฝั่ง Server
- ห้ามส่ง Stack Trace ไปยัง Client
- ห้ามส่ง Connection String หรือ Secret
- HTTP Status ต้องตรงกับประเภท Error

---

# Initial Error Codes

| HTTP Status | Code | Meaning |
|---:|---|---|
| 400 | `BAD_REQUEST` | Request ไม่ถูกต้อง |
| 401 | `UNAUTHORIZED` | ยังไม่ได้ยืนยันตัวตน |
| 403 | `FORBIDDEN` | ไม่มีสิทธิ์ |
| 404 | `NOT_FOUND` | ไม่พบข้อมูล |
| 500 | `INTERNAL_SERVER_ERROR` | Error ภายในระบบ |
| 503 | `DATABASE_UNAVAILABLE` | Database ไม่พร้อมใช้งาน |
