# Laoo

> **Enterprise Software Platform**
> Build Once, Customize Anywhere

---

# Overview

Laoo คือแพลตฟอร์มสำหรับพัฒนาระบบงานองค์กร โดยออกแบบให้สามารถสร้างผลิตภัณฑ์ได้หลายประเภทจากมาตรฐานเดียวกัน

ตัวอย่างผลิตภัณฑ์ในอนาคต

* Laoo (Core Platform)
* Laoo Meeting
* Laoo HR
* Laoo Quality
* Laoo License
* และผลิตภัณฑ์อื่น ๆ

---

# Vision

สร้างแพลตฟอร์มซอฟต์แวร์ที่

* พัฒนาครั้งเดียว
* นำกลับมาใช้ซ้ำได้
* ปรับแต่งได้ตามความต้องการของลูกค้า
* รองรับทั้ง On-Premise และ SaaS
* ใช้มาตรฐานเดียวกันทุก Project

---

# Technology

Current Technology Stack

* Flutter
* ASP.NET Core Web API
* SQL Server
* Git
* GitHub

รายละเอียดทั้งหมดอยู่ใน `docs/standards`

---

# Repository Structure

```text
laoo/
│
├── docs/
│
│   ├── platform/
│   ├── standards/
│   ├── engines/
│   ├── security/
│   ├── qa/
│   ├── deployment/
│   ├── templates/
│   └── meeting/
│
├── projects/
│
│   └── laoo/
│       ├── app/
│       ├── api/
│       ├── database/
│       └── docs/
│
├── tools/
│
└── scripts/
```

---

# Documentation

เอกสารทั้งหมดของบริษัทอยู่ในโฟลเดอร์

```text
docs/
```

แบ่งออกเป็น

* Platform
* Standards
* Engines
* Security
* QA
* Deployment
* Templates
* Meeting

---

# Projects

ทุกผลิตภัณฑ์จะถูกเก็บไว้ภายใต้

```text
projects/
```

เช่น

```text
projects/
    laoo/
    laoo-meeting/
    laoo-hr/
```

---

# Development Process

ทีมงานใช้กระบวนการพัฒนาเดียวกันทุก Project

```text
Requirement
    ↓
Platform Standard
    ↓
Prototype
    ↓
Implementation
    ↓
Testing
    ↓
Review
    ↓
Release
```

---

# AI Development

AI ทุกตัวต้องอ่าน

1. AGENTS.md
2. เอกสารใน `docs/`
3. เอกสารเฉพาะ Project

ก่อนเริ่มสร้างหรือแก้ไข Code

---

# Current Status

Project Status

**Foundation Phase**

Current Milestone

* Platform Blueprint ✅
* Git Repository ✅
* GitHub Repository ✅

Next Milestone

* Flutter Foundation
* Core Authentication
* Dashboard
* Theme Engine

---

# License

Copyright © Laoo

All Rights Reserved.
