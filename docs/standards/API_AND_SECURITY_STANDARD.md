# API and Security Standard

Version: 1.0  
Updated: 2026-08-09

## Rules

- ใช้ HTTPS และ JSON
- Endpoint ที่ป้องกันต้องตรวจ JWT/Session และ User active
- ใช้ Parameterized Query เท่านั้น
- ไม่คืน Password hash, Secret, Connection String หรือข้อมูลภายในที่ไม่จำเป็น
- Error response ใช้รูปแบบกลางและไม่เปิดเผย Stack Trace ใน Production
- ทุก Endpoint ต้องตรวจ Permission, Data Scope และ Record Ownership
- Module endpoint ต้องตรวจ Effective Module Access
- Partner endpoint ต้องบังคับ Partner scope จาก Server context
- Company/Branch identifier จาก Client ใช้เป็น Target ได้ แต่ไม่ใช่หลักฐานสิทธิ์

## Status Codes

| Code | Meaning |
|---|---|
| 200/201 | สำเร็จ |
| 400 | Request ไม่ถูกต้อง |
| 401 | ยังไม่ยืนยันตัวตน/Token ใช้ไม่ได้ |
| 403 | ยืนยันตัวตนแล้วแต่ไม่มีสิทธิ์หรืออยู่นอก Scope |
| 404 | ไม่พบข้อมูลภายใน Scope ที่เข้าถึงได้ |
| 409 | ข้อมูลขัดแย้ง เช่น Code/Username ซ้ำ |
| 422 | Business validation ไม่ผ่าน |
| 500 | Internal error ที่ถูกบันทึก Log แล้ว |

## Audit

การเปลี่ยนข้อมูลสำคัญต้องเก็บ Actor, Actor Type, Target, Action, Before/After ที่เหมาะสม, Reason, Timestamp, Correlation ID และ Source/IP เท่าที่นโยบายอนุญาต

## Implemented Identity and Scope Baseline (2026-08-09)

- Login รองรับ `LAOO_SUPPORT`, `PARTNER_USER` และ `COMPANY_USER`
- Token/Session ต้องส่ง user type และบริบท `PartnerID` หรือ `CompanyID` เมื่อมี
- Server เป็นผู้กำหนด Data Scope จาก Session ห้ามเชื่อ identifier จาก Client เป็นหลักฐานสิทธิ์
- Admin เห็นเมนูทั้งหมดของประเภท Login ตนเองโดยอัตโนมัติ; User ปกติเห็นตาม Permission ที่ได้รับ
- Frontend ใช้ Permission เพื่อซ่อนเมนู/Action เท่านั้น; API ต้องตรวจ Permission, Scope และ Ownership ซ้ำ
