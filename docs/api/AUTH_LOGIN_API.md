# Auth Login API

Status: Current contract baseline  
Updated: 2026-08-09

```http
POST /api/auth/login
Content-Type: application/json
```

```json
{
  "username": "string",
  "password": "string"
}
```

LaOO Plaza ไม่ให้ Client เลือก Project, Partner, Company หรือ Branch ตอน Login API ต้องระบุ User Type และ Scope จากฐานข้อมูลเอง

Response สำเร็จคืน Access Token/Session metadata ที่จำเป็นเท่านั้น ห้ามคืน Password data หรือ Secret

หมายเหตุ: API ปัจจุบันอาจยังรับ `projectCode` เพื่อความเข้ากันได้ชั่วคราว แต่ต้องถือเป็น Technical debt และไม่ใช้ค่านี้ตัดสิน Scope ใน Baseline ใหม่

