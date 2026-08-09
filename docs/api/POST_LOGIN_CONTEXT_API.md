# Post-login Context API

Status: Target contract; replaces Project-based document  
Updated: 2026-08-09

```http
GET /api/auth/post-login-context
Authorization: Bearer <access-token>
```

API อ่านตัวตนจาก JWT/Session แล้ว Resolve จากฐานข้อมูลตาม User Type:

```text
Laoo Support → Laoo scope + permissions
Partner User → Partner + permitted customers + modules + permissions
Company User → Company + branches + effective modules + permissions
```

Response ต้องมีอย่างน้อย User identity/type, effective scope, effective modules, permissions, support state และ Company Setup runtime ที่จำเป็น ห้ามคืน Project list ใน Laoo Plaza

Client ห้ามเป็นผู้ตัดสิน User Type, ownership หรือ Effective Module Access เอง

