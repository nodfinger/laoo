# Decision Log

Version: 1.0  
Baseline: 2026-08-09

## Approved Decisions

1. Root workspace คือ `C:\laoo`; โปรเจกต์หลักอยู่ที่ root โดยไม่มีโฟลเดอร์ `projects`.
2. Technology หลักคือ Flutter, ASP.NET Core Web API, SQL Server, Git และ GitHub.
3. Flutter ติดต่อ SQL Server ผ่าน API เท่านั้น.
4. LaOO Plaza เป็นระบบอิสระ มี App/API/Authentication/Database ของตนเอง และไม่มี Runtime Project Master หรือ Project Database Routing.
5. Organization คือ `Laoo → Partner → Customer/Company → Branch → User`; Version 1 ไม่ใช้ TenantCode.
6. User มีสามกลุ่มหลัก: Laoo Support, Partner User และ Company User.
7. หน้า Login ไม่ให้เลือก Project, Partner, Company หรือ Branch.
8. Laoo สร้าง Customer ด้วยบัญชี Laoo แล้วผูก Partner จากหน้าจอ; ไม่สวมรอยเป็น Partner.
9. Laoo และ Partner ที่มี Permission เปิด–ปิด Module ให้ Customer ได้; Company User ทำไม่ได้.
10. Laoo สามารถ Lock Module และ Partner แก้สถานะไม่ได้ระหว่าง Lock.
11. ปิด Module แล้วหยุด Menu/Action/Route/API แต่ไม่ลบ Role/Permission เดิม.
12. ไม่มีสิทธิ์ให้ซ่อน UI เป็นค่าเริ่มต้น แต่ API ต้องตรวจสิทธิ์ทุกครั้งและ Deny by Default.
13. Laoo Support ใช้ Login As User ตาม Permission พร้อมเหตุผล, Banner และ Audit; ไม่ใช้ Master Password.
14. Default theme คือ STYLE01 กลุ่ม Hybrid; Workspace/Content/Title Bar เป็นพื้นขาว.
15. Coding Expert ตั้งชื่อ Table/Field ได้ตาม `TD + ModuleCode + EntityMeaning`.
16. ทุก Database change ต้องส่ง SQL + Excel Data Dictionary + PDF Data Dictionary; SQL ของ Laoo Plaza เริ่ม `USE [DBTDLaoo]` และ `GO`.
17. เอกสารเป็น AI-agnostic และ `DOCUMENTATION_GUIDE.md` เป็นทางเข้าเพื่อเลือกเอกสาร.

มติเดิมที่ขัดกับรายการนี้ถือว่า Superseded ได้แก่โครงสร้าง `C:\laoo\projects`, Central Project Master, `TDADProject*`, Project selection ใน Login, Project-based database routing และการใช้คำ TenantCode ใน Version 1.

