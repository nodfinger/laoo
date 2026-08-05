# Laoo Solutions Documentation

> Shared Standards and Project Entry Point  
> Build Once, Customize Anywhere

Version: 1.2  
Last Update: 2026-08-05  
Owner: CI / CA / CDO

---

# Purpose

ไฟล์นี้เป็นจุดเริ่มต้นหลักสำหรับมนต์ ทีมงาน และ AI ทุกตัวที่ทำงานกับ Laoo Solutions

ก่อนเริ่มวิเคราะห์ สร้าง หรือแก้ไข Source Code ต้องเริ่มจาก `PROJECT.md` ของ Project ปัจจุบันเสมอ

---

# Platform Overview

Laoo Solutions คือ Platform สำหรับพัฒนาระบบงานหลายประเภทจากมาตรฐานกลางชุดเดียว

ตัวอย่าง Project

- `laoo`
- `laoo_meeting`
- `laoo_market`
- `laoo_pos`
- `laoo_hr`

---

# Root Structure

```text
C:\laoo
│
├── docs
├── tools
├── scripts
│
├── laoo
├── laoo_meeting
├── laoo_market
├── laoo_pos
└── ...
```

Project ทุกตัวอยู่โดยตรงภายใต้

```text
C:\laoo
```

ไม่ใช้โฟลเดอร์ `C:\laoo\projects`

---

# Shared Documentation

เอกสารมาตรฐานกลางทั้งหมดอยู่ที่

```text
C:\laoo\docs
```

เอกสารกลางเป็น Single Source of Truth

ห้ามคัดลอก Standard ไปไว้ซ้ำในแต่ละ Project

---

# Project Manifest Workflow

ทุก Project ต้องมีไฟล์

```text
PROJECT.md
```

`PROJECT.md` ทำหน้าที่เป็น Project Manifest และ Source of Truth ของ Project นั้น

ก่อนเริ่มงาน ให้ดำเนินการตามลำดับ

1. อ่าน `PROJECT.md` ของ Project ปัจจุบัน
2. อ่านรายการในหัวข้อ `Required Documents`
3. ตรวจสอบว่าเอกสารทุกไฟล์มีอยู่จริง
4. หากเอกสารขาดหรือขัดแย้ง ให้แจ้งก่อนและห้ามเดา
5. อ่าน Source Code และ Configuration ที่เกี่ยวข้อง
6. จึงเริ่มวิเคราะห์ ออกแบบ หรือแก้ไข Code

ห้ามอ่านเอกสารทั้งหมดใน `docs` โดยไม่จำเป็น

ให้อ่านเฉพาะไฟล์ที่ `PROJECT.md` ระบุ และไฟล์เพิ่มเติมที่เกี่ยวข้องกับงานจริง

---

# Conflict Rule

หาก `PROJECT.md` ขัดแย้งกับ Standard กลาง

AI ต้อง

- แจ้งรายการที่ขัดแย้ง
- หยุดก่อนเปลี่ยน Architecture หรือ Scope
- ขอคำตัดสินจากมนต์หรือ CI/CA

ห้ามเลือกข้อมูลด้านใดด้านหนึ่งเอง

---

# Required Project Information

`PROJECT.md` ต้องมีอย่างน้อย

- Project Name
- Display Name
- Project Path
- Purpose
- Current Objective
- Version Scope
- Out of Scope
- Required Documents
- Target Platforms
- Development Rules
- Definition of Done

Template อยู่ที่

```text
C:\laoo\docs\templates\PROJECT_TEMPLATE.md
```

---

# Naming Agreement

เมื่อใช้คำว่า

```text
laoo
```

ให้หมายถึง Flutter Project

```text
C:\laoo\laoo
```

เมื่อใช้คำว่า

```text
Laoo Solutions
```

ให้หมายถึง Platform และ Ecosystem ทั้งหมด

---

# Current Projects

## laoo

```text
C:\laoo\laoo
```

Public Portal สำหรับแสดงข้อมูลและ Product ของ Laoo Solutions

## laoo_meeting

```text
C:\laoo\laoo_meeting
```

ระบบแสดงและจัดการข้อมูลห้องประชุม

---

# Technology

Technology Stack หลัก

- Flutter
- Dart
- ASP.NET Core Web API
- SQL Server
- Git
- GitHub

รายละเอียดให้ดูจากเอกสารที่ Project Manifest อ้างอิง

---

# Important Rule

ไฟล์ Markdown ไม่ได้ถูก Flutter อ่านอัตโนมัติตอน Run

เอกสารเหล่านี้เป็นข้อกำหนดสำหรับมนต์ ทีมงาน ChatGPT และ AI Coding Assistant ก่อนสร้างหรือแก้ไข Source Code

---

# License

Copyright © Laoo Solutions

All Rights Reserved.
