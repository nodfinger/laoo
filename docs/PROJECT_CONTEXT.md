# Project Context

Version: 1.0  
Updated: 2026-08-09

## เป้าหมาย

Laoo Solutions พัฒนาระบบที่ใช้งานจริงแบบ Simple First, Scalable Later โดยใช้ Flutter, ASP.NET Core Web API และ SQL Server

## Workspace

```text
C:\laoo\laoo
C:\laoo\laoo_meeting
C:\laoo\laoo_api
C:\laoo\docs
C:\laoo\tools
C:\laoo\scripts
C:\laoo\publish
C:\laoo\backup
C:\laoo\archive
```

ไม่มีโฟลเดอร์ `C:\laoo\projects` ในโครงสร้างปัจจุบัน

## ระบบที่กำลังพัฒนา

LaOO Plaza ใช้แอป API และฐานข้อมูลของตนเอง โดยฐานข้อมูลปัจจุบันคือ `DBTDLaoo` ภายในระบบนี้ไม่มี Project Master, Project selection ตอน Login หรือ Project-based database routing

โครงสร้างธุรกิจหลัก:

```text
Laoo → Partner → Customer/Company → Branch → User
```

## สถานะปัจจุบัน

- Flutter Landing และ Login ใช้งานได้
- Login ผ่าน ASP.NET Core API และ SQL Server ได้
- Company Setup และ Theme Runtime อยู่ระหว่างเชื่อมใช้งานจริงให้ครบ
- ตาราง Partner User, Module Master และ Company Module ถูกสร้างแล้ว
- งานถัดไปคือปรับ API และ Flutter ให้รองรับ Partner User, Customer ownership และ Customer Module ตาม Baseline ใหม่

## หลักการพัฒนา

```text
Requirement → Standard → Implementation → Run → Verify → Update Documentation
```

- Flutter ห้ามเชื่อม SQL Server โดยตรง
- API เป็นผู้ตรวจ Authentication, Permission, Data Scope และ Record Ownership
- ไม่มีสิทธิ์ให้ซ่อนเมนู ปุ่ม และ Action เป็นค่าเริ่มต้น
- ก่อนสร้างหรือแก้ UX/UI ต้องสรุปให้ Product Owner อนุมัติ เว้นแต่ Product Owner สั่งให้ลง Code จริงทันที
- งานฐานข้อมูลทุกครั้งต้องส่ง SQL, Excel Data Dictionary และ PDF Data Dictionary

