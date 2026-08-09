# Document Cleanup Report

Baseline: 2026-08-09

## ผลลัพธ์

- ตรวจชุด `docs(1).zip` จำนวน 117 entries และเอกสาร API เพิ่มเติม 1 ไฟล์
- ลดเอกสารที่ใช้งานจริงเหลือชุด Baseline ขนาดเล็ก โดยรวมไฟล์ย่อยที่ซ้ำกัน
- รักษาเอกสาร UX/UI, CRUD, Pagination, Typography, Flutter State, Git และ Environment ที่ยังใช้ได้
- เขียน Architecture, Authentication, Database, Organization/Module และ API Security ใหม่ให้ตรงกับมติล่าสุด
- สร้าง `DOCUMENTATION_GUIDE.md` เป็นทางเข้าเดียวสำหรับทีมและ AI
- เก็บ Meeting Summary ล่าสุดไว้ใน `history/` และระบุชัดว่าไม่ใช่ Source of Truth

## ข้อขัดแย้งที่แก้แล้ว

1. ยกเลิก `C:\laoo\projects`; ใช้ `C:\laoo\laoo`, `laoo_meeting`, `laoo_api` ที่ root
2. ยกเลิก Central Project Master, `TDADProject*`, Project selection ตอน Login และ Project Database Routing สำหรับ Laoo Plaza
3. เพิ่ม Partner User เป็น User Type แยกจาก Laoo Support และ Company User
4. แก้ Post-login Context ไม่ให้คืน Project list เป็น Target contract
5. ยืนยัน Laoo/Partner เปิด–ปิด Customer Module ตาม Permission และ Laoo Lock มีอำนาจสูงกว่า
6. เปลี่ยน Data Isolation จากคำ TenantCode เป็น Company/Branch ownership สำหรับ Version 1
7. แก้ Theme group เป็น STYLE01–10 Hybrid, STYLE11–20 Light/Colored, STYLE21–30 Dark, STYLE31–40 White Menu
8. ยืนยันสิทธิ์ตั้งชื่อ Table/Field และ Database delivery แบบ SQL + Excel + PDF

## ไฟล์กลุ่มที่ยกเลิก

- Multi Project Architecture
- Project Connection Resolver
- Project Database Architecture/Routing/Onboarding
- Authentication/Permission implementation notes ที่อ้าง `TDADProject`, `TDADLaooUserProject`, `TDADUserProject`
- Decision log เก่าที่มีโครงสร้าง `projects/` และ Tenant model
- README/Manifest/System Map เก่าที่ลิงก์ไปเอกสารยกเลิก

รายละเอียดระดับไฟล์อยู่ใน `DOCUMENT_INVENTORY.md`

## การนำไปใช้

1. สำรอง `C:\laoo\docs` เดิมเป็น ZIP หรือย้ายไป `C:\laoo\archive`
2. ลบ/ย้ายโฟลเดอร์ `C:\laoo\docs` เดิมหลังตรวจ Backup แล้ว
3. นำโฟลเดอร์ `docs` จาก ZIP ชุดนี้ไปวางที่ `C:\laoo\docs`
4. เปิด `C:\laoo\docs\DOCUMENTATION_GUIDE.md` และตรวจ Link/Path
5. Commit เป็น Documentation Baseline แยกหนึ่ง Commit

## Technical Debt ที่ต้องแก้ใน Code/API

- Login API ปัจจุบันยังอาจรับ `projectCode`
- Post-login Context implementation ปัจจุบันยัง Resolve/คืน Project
- Permission/Menu responses บางฉบับยังมี `projectCode`
- Database เดิมอาจยังมี `TDADProject`, `TDADLaooUserProject`, `TDADUserProject`; ห้ามลบทันทีจนตรวจ Code dependency และทำ Migration/Backup/Rollback plan

