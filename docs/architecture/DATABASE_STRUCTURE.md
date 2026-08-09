# Database Structure

Version: 1.0  
Updated: 2026-08-09

## Database

LaOO Plaza ใช้ `DBTDLaoo` สำหรับ Authentication และข้อมูลธุรกิจของระบบ ไม่มี Project Master หรือความสัมพันธ์ User/Partner/Company กับ Project

## Organization

```text
TDADPartner
├── TDADPartnerUser
└── TDADCompany
    ├── TDADBranch
    └── TDADUser
```

## Module Entitlement

```text
TDSYModule
└── TDCMCompanyModule
    ├── Company ownership
    ├── Active period/state
    └── Laoo lock
```

Effective access ต้องผ่าน Customer Active, Module Active, ไม่ถูก Laoo Lock, User Active และ Permission ที่ถูกต้อง

## Naming

- Table: `TD + ModuleCode + EntityMeaning` แบบ PascalCase ไม่มี underscore
- Field: ชื่อสื่อความหมายแบบ PascalCase
- Coding Expert ตั้งชื่อ Table และ Field ได้เองตามมาตรฐาน
- Primary key, Foreign key, Unique constraint, Index, Status และ Audit field ต้องออกแบบตามการใช้งานจริง

## Ownership

- ตารางข้อมูล Customer ต้องมี Company key
- ตารางระดับ Branch ต้องมี Company และ Branch key
- Partner User ต้องอ้างอิง Partner เดียว
- Company ต้องอ้างอิง Partner เจ้าของความสัมพันธ์ปัจจุบัน
- การเปลี่ยน Partner แก้ความสัมพันธ์ที่ Company โดยไม่ย้ายหรือลบ Child data

## Database Delivery

ทุก Schema change ต้องส่ง SQL, Excel Data Dictionary และ PDF Data Dictionary ซึ่งอธิบายทุก Table และ Field โดยย่อ SQL สำหรับฐานนี้ต้องเริ่มด้วย:

```sql
USE [DBTDLaoo]
GO
```

