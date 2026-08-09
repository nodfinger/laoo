# Architecture

Version: 1.0  
Updated: 2026-08-09

## Runtime Architecture

```text
Flutter App
    ↓ HTTPS/JSON
ASP.NET Core Web API
    ↓
SQL Server — DBTDLaoo
```

LaOO Plaza มี Application, API, Authentication และ Business Database ของตนเอง ไม่ใช้ Project Master หรือ Project Database Resolver ใน Runtime

## Core Rules

- Client ไม่เก็บ Connection String, Database credential หรือ JWT secret
- Secret อยู่ใน `local.json`, Environment Variable หรือ Secret Store และห้าม Commit
- API เป็น Trust Boundary และต้อง Deny by Default
- ตารางข้อมูล Customer ต้องมี Company ownership; ข้อมูลระดับ Branch ต้องมี Company และ Branch ownership
- Runtime Context ต้องมาจาก JWT/Session และการตรวจฐานข้อมูล ไม่เชื่อ owner ID จาก Client โดยตรง
- Role/Permission แยกจาก Module entitlement
- ปิด Module แล้ว Route, Menu, Action และ API ของ Module ต้องไม่ทำงาน แต่ไม่ลบ Role/Permission เดิม

## User Groups

- Laoo Support User
- Partner User
- Company User

รายละเอียดอยู่ใน `AUTHENTICATION_STRUCTURE.md`

## ระบบอื่นของ Laoo

`laoo_meeting` และระบบใหม่สามารถแยก App/API/Database ได้ การออกแบบข้ามระบบต้องทำเป็น Architecture Decision ใหม่ ไม่ให้นำ Multi-Project model เดิมกลับมาใช้โดยอัตโนมัติ

