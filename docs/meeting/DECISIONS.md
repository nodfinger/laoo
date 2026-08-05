# DECISIONS.md

# Laoo Decision Log

Version: 1.0  
Last Updated: 2026-08-04

---

## Purpose

เอกสารนี้ใช้เก็บมติสำคัญของทีม Laoo เพื่อให้สามารถย้อนกลับมาตรวจสอบได้ว่า

- ทีมตัดสินใจเรื่องอะไร
- เลือกแนวทางใด
- เพราะเหตุใด
- มีผลกับส่วนใดของ Platform หรือ Project

เอกสารนี้ไม่ใช่ Requirement รายละเอียด และไม่ใช่มาตรฐานเชิงเทคนิคโดยตรง  
เมื่อถึงเวลาพัฒนา ต้องนำมติที่เกี่ยวข้องไปอ้างอิงในเอกสารมาตรฐานหรือเอกสาร Feature ที่เหมาะสม

---

## Decision Status

ใช้สถานะดังนี้

- `Proposed` — ข้อเสนอที่ยังไม่ได้อนุมัติ
- `Tentative` — เห็นชอบเบื้องต้น แต่ยังปรับได้
- `Approved` — อนุมัติแล้ว
- `Superseded` — ถูกแทนที่ด้วยมติใหม่
- `Cancelled` — ยกเลิกแล้ว

---

## Decision #001 — Root Workspace Name

**Status:** Approved

ใช้ Root Folder ชื่อ

```text
C:\laoo
```

ภายในเก็บ

- เอกสารมาตรฐานกลาง
- Project ทั้งหมด
- Tools
- Scripts

---

## Decision #002 — Project Structure

**Status:** Approved

แต่ละ Project แยกออกจากกันภายใต้

```text
C:\laoo\projects
```

Project แรกใช้ชื่อ

```text
laoo
```

ตำแหน่ง

```text
C:\laoo\projects\laoo
```

---

## Decision #003 — Documentation Structure

**Status:** Approved

เอกสารกลางของ Laoo เก็บไว้ที่

```text
docs/
├── platform/
├── standards/
├── engines/
├── security/
├── qa/
├── deployment/
├── templates/
└── meeting/
```

---

## Decision #004 — AGENTS.md

**Status:** Approved

ต้องมี `AGENTS.md`

หน้าที่หลักคือ

- กำหนดวิธีทำงานของ AI
- กำหนดลำดับการอ่านเอกสาร
- กำหนดกฎของทีม
- ห้ามใช้เป็นที่เก็บ Requirement รายละเอียด

---

## Decision #005 — Development Approach

**Status:** Approved

ใช้แนวทาง

```text
Platform + Prototype
```

พัฒนาไปพร้อมกัน

ใช้หลัก

```text
Prototype Driven Development
Just-in-Time Documentation
```

เมื่อพบปัญหาจากการพัฒนาจริง ให้ย้อนกลับไปปรับ Platform Standard

---

## Decision #006 — Primary Technology

**Status:** Approved

ใช้เทคโนโลยีหลัก

- Flutter
- ASP.NET Core Web API
- SQL Server
- Git
- GitHub

Flutter ห้ามเชื่อมต่อ SQL Server โดยตรง

โครงสร้างการเชื่อมต่อ

```text
Flutter
→ ASP.NET Core Web API
→ SQL Server
```

---

## Decision #007 — Business Hierarchy

**Status:** Superseded by Decision #035

โครงสร้างธุรกิจหลัก

```text
Laoo
→ Partner
→ Customer
→ Branch
→ User
```

ข้อมูลของลูกค้าแต่ละรายต้องแยกออกจากกันอย่างชัดเจน

---

## Decision #008 — Multi-Tenant Data Isolation

**Status:** Approved

หลักการสำคัญที่สุดคือ

> ลูกค้าแต่ละรายต้องเห็นเฉพาะข้อมูลของตนเอง

ทุก Request ต้องตรวจ

- Authentication
- Tenant
- Permission
- Data Scope
- Record Ownership

---

## Decision #009 — Support Access

**Status:** Approved

เลือกใช้แนวทาง

```text
Login As User
```

แทน Password กลาง

ข้อกำหนด

- ใช้ได้เฉพาะเจ้าหน้าที่ Laoo ที่ได้รับสิทธิ์
- ต้องระบุเหตุผล
- ต้องมี Audit Log
- ต้องมีแถบแจ้งเตือนว่ากำลังใช้งานในนามลูกค้า
- ต้องมีปุ่มออกจากโหมด Support

---

## Decision #010 — Permission Model

**Status:** Approved

เลือกใช้

```text
Hybrid Permission Model
```

หลักการ

- มี Permission Template
- สามารถคัดลอกสิทธิ์จาก Template ไป User
- สามารถคัดลอกสิทธิ์จาก User ไป User
- หลังคัดลอกแล้ว User Permission เป็นอิสระ
- Runtime ตรวจสิทธิ์จาก User Permission

---

## Decision #011 — UI Permission Behavior

**Status:** Approved

ค่าเริ่มต้น

```text
ไม่มีสิทธิ์ = ซ่อน
```

ใช้กับ

- เมนู
- ปุ่ม
- Action

ใช้ `Disabled` เฉพาะกรณีที่ Requirement ระบุชัดเจน หรือเกิดจาก Business Condition

---

## Decision #012 — User Preferences

**Status:** Approved

User แต่ละคนสามารถกำหนดค่าของตนเอง เช่น

- Theme
- เมนูลัด
- Startup Screen
- Notification Preference
- รูป Profile
- Password

ระบบต้องจำค่าของ User และนำกลับมาใช้เมื่อ Login ครั้งถัดไป

---

## Decision #013 — Theme

**Status:** Approved

ระบบเตรียม Theme สำเร็จรูปให้เลือก เช่น

- โทนสีเขียว
- โทนสีฟ้า

User เลือก Theme เป็นชุด ไม่ปรับสีทีละส่วน

เมื่อเปลี่ยน Theme ระบบต้อง Refresh และใช้งานทันที

---

## Decision #014 — Favorite Menu

**Status:** Approved

แต่ละหน้าจอสามารถเพิ่มเป็นเมนูลัดได้

ระบบต้องมีเมนู

```text
เมนูลัดของฉัน
```

เพื่อแสดงหน้าจอที่ User เลือกไว้

---

## Decision #015 — Startup Screen

**Status:** Approved

User สามารถเลือกหน้าจอแรกหลัง Login ได้

ตัวอย่าง

- Dashboard
- Invoice
- POS
- Product

ระบบต้องตรวจ Permission ก่อนเปิดหน้าเริ่มต้น

ถ้าไม่มีสิทธิ์ ให้กลับไปหน้า Default ของระบบ

---

## Decision #016 — Notification Preference

**Status:** Approved

User สามารถเลือกได้เองว่า

- งานประเภทใด
- แจ้งเตือนผ่านช่องทางใด

ช่องทางเริ่มต้น

- In-App
- Email
- Push

บาง Notification ด้าน Security อาจเป็น Mandatory และปิดไม่ได้

---

## Decision #017 — Organization, Permission, Data Scope, Workflow

**Status:** Approved

ต้องแยกแนวคิดออกจากกัน

1. Permission — ทำอะไรได้
2. Data Scope — เห็นข้อมูลของใคร
3. Organization — อยู่ตรงไหนในองค์กร
4. Workflow — ส่งอนุมัติอย่างไร

ห้ามนำทั้งสี่เรื่องไปรวมเป็นระบบเดียวจนปรับแต่งไม่ได้

---

## Decision #018 — Organization Hierarchy

**Status:** Tentative

โครงสร้างตัวอย่าง

```text
MD
→ ผู้ช่วย MD
→ ผู้อำนวยการ
→ ผู้จัดการ
→ หัวหน้า
→ เจ้าหน้าที่
```

ระบบต้องรองรับโครงสร้างที่ลูกค้าแต่ละรายกำหนดเองได้

---

## Decision #019 — Multi-Branch

**Status:** Approved

Customer หนึ่งรายสามารถมีหลายสาขา

Owner หรือผู้บริหารสามารถดูภาพรวมหลายสาขาตาม Data Scope เช่น

- ยอดขาย
- Stock
- รายงาน
- ข้อมูลสรุปอื่น ๆ

User ทั่วไปเห็นเฉพาะสาขาที่ได้รับสิทธิ์

---

## Decision #020 — File Storage

**Status:** Tentative

แนวทางหลัก

- SQL Server เก็บ Metadata และตำแหน่งไฟล์
- ไฟล์จริงเก็บใน Folder หรือ Object Storage
- On-Premise เริ่มจาก Local/Network Folder
- SaaS รองรับ Object Storage ในอนาคต
- Coding เป็นผู้สร้าง Folder ตาม Configuration
- ไฟล์ Upload ต้องแยกตาม Tenant
- ไฟล์ Private ไม่ควรเก็บใน `wwwroot`

---

## Decision #021 — Image Policy

**Status:** Approved

ระบบต้องรองรับ Policy ตาม

- Platform
- Project
- Customer
- Screen
- File Category

ตัวอย่าง

```text
รูปพนักงาน
ขนาดไม่เกิน 100 KB
```

รองรับ

- Resize
- Compress
- Thumbnail
- Allowed File Type
- Maximum Width/Height

---

## Decision #022 — Deployment

**Status:** Approved

Version แรกใช้

```text
Manual Deployment
```

ขั้นตอนหลัก

- Build
- Remote เข้า Server
- Copy File
- Paste
- Restart ระบบ
- Smoke Test

ต้องออกแบบให้มนต์สามารถติดตั้งและดูแลเองได้

---

## Decision #023 — Cloud Strategy

**Status:** Approved

ใช้หลัก

```text
Simple First, Scalable Later
```

เริ่มจาก Windows Server VM หรือโครงสร้างที่ใกล้ On-Premise

ยังไม่ใช้ Microservices, Kubernetes หรือระบบ Cloud ซับซ้อนใน Version แรก

---

## Decision #024 — Security on Browser and API

**Status:** Approved

การซ่อนเมนูไม่ใช่ Security หลัก

Server/API ต้องตรวจสิทธิ์ทุกครั้ง

ต้องป้องกัน

- Copy URL
- เปลี่ยน Record ID
- เรียก API โดยตรง
- Cross-Tenant Access
- Unauthorized File Access

ใช้หลัก

```text
Deny by Default
```

---

## Decision #025 — Testing Strategy

**Status:** Approved

แบ่งการทดสอบเป็น 2 ระยะ

1. Product Release Test
2. Function Change Test

ก่อน Release ต้องมี

- Developer Test
- Functional Test
- Integration Test
- Security Test
- External Security Test
- Installation Test
- Backup/Restore Test
- Regression Test
- UAT ภายในทีม Laoo

---

## Decision #026 — Internal QA Report

**Status:** Approved

ทีม Laoo เป็นผู้ทดสอบระบบเอง

ต้องสามารถสร้างรายงานภาษาไทย เช่น

- Test Report
- Security Test Report
- Release Readiness Report
- Bug Report
- Test Summary

สามารถส่งออกเป็น PDF และ Excel ได้ในอนาคต

---

## Decision #027 — Git and GitHub

**Status:** Approved

Root Repository

```text
https://github.com/nodfinger/laoo
```

ใช้ Git และ GitHub ตั้งแต่เริ่มต้น

Commit ตาม Checkpoint, Milestone, Feature หรือ Bug Fix ที่มีความหมาย

---

## Decision #028 — Project Flutter Name

**Status:** Approved

Flutter Project แรกใช้ชื่อ

```text
laoo
```

Package Identifier เริ่มต้น

```text
com.laoo.laoo
```

---

## Decision #029 — Team Communication

**Status:** Approved

ทีมเรียก Product Owner ว่า

```text
มนต์
```

ไม่ใช้คำว่า “คุณมนต์”

---

## Decision #030 — CA Responsibilities

**Status:** Approved

CA ต้อง

- คุม Roadmap
- เตือนเมื่อข้ามขั้นตอน
- เตือนเมื่อถึงเวลา Commit
- ทบทวน Requirement จากการประชุม
- นำ Requirement ไปใส่ใน Markdown เมื่อถึงส่วนที่เกี่ยวข้อง
- อธิบายศัพท์เทคนิคให้มนต์เข้าใจง่าย

---

## Decision #031 — Team Governance

**Status:** Approved

- มนต์เป็น Project Owner และผู้ตัดสินใจ Requirement และ Business Logic
- CI เป็น Project Manager มีหน้าที่คัดเลือกและมอบหมายผู้เชี่ยวชาญที่เหมาะสมเป็นผู้รับผิดชอบหลักของแต่ละงาน
- CA รับผิดชอบ Architecture, Standard, Planning และ Review
- Codex รับผิดชอบ Coding, Refactor, File Change, Error Fix และ Build Verification ใน VS Code
- ผู้เชี่ยวชาญแต่ละด้านต้องทำงานตามมาตรฐานกลางและมติที่บันทึกไว้

---

## Decision #032 — Data Entry Design Gate

**Status:** Approved

ก่อนออกแบบหรือพัฒนาหน้าจอที่มีการกรอกข้อมูล ทีมต้องสอบถามและได้รับข้อสรุปจากมนต์ก่อนเสมอ อย่างน้อยในเรื่อง

- รายการข้อมูลที่ต้องกรอก
- ชนิดและรูปแบบข้อมูล
- ข้อมูลบังคับและข้อมูลไม่บังคับ
- Validation และเงื่อนไขข้อมูลซ้ำ
- ข้อมูลอ่อนไหวและวัตถุประสงค์การจัดเก็บ

ห้ามเดา Business Logic หรือเริ่ม Coding หน้าจอดังกล่าวก่อนผ่านจุดตรวจนี้

---

## Decision #033 — Product Isolation and Shared Standards

**Status:** Approved

Laoo Solutions ประกอบด้วยหลาย Product โดยแต่ละ Product ต้องแยกออกจากกันอย่างชัดเจน ได้แก่

- Source Code และ VS Code Project
- UI และ Business Logic
- Domain
- Backend API
- Database เช่น `DBLaooPOS` และ `DBLaooHR`

ทุก Product ใช้เอกสารมาตรฐานกลางใน `docs/` ร่วมกัน แต่ห้ามใช้หน้าจอหรือ Database ร่วมกันโดยปริยาย

การเชื่อมต่อมาตรฐานของแต่ละ Product คือ

```text
Flutter
→ Product API
→ Product Database
```

ห้าม Flutter เชื่อมต่อ SQL Server โดยตรง และหลีกเลี่ยงการ Query ข้าม Product Database โดยตรง

---

## Decision #034 — Laoo Entry Point and Registration Scope

**Status:** Approved

- Project แรกชื่อ `Laoo`
- Laoo เป็นระบบหลักและมี Landing Page เป็นหน้าเริ่มต้น
- Landing Page ใช้เป็นทางเข้าสู่ Product ต่าง ๆ ในรูปแบบ SaaS และเชื่อมไปยัง Domain ของแต่ละ Product
- Product ทั่วไปใช้ Login Page เป็นหน้าเริ่มต้น
- ตัดหน้าสมัครสมาชิกออกจากขอบเขตปัจจุบันเพื่อป้องกันความสับสน

---

## Decision #035 — Authenticated Business Context

**Status:** Approved

Decision นี้ใช้แทน Business Hierarchy ใน Decision #007

หลัง Login ระบบต้องระบุตัวตนและ Business Context ได้ตามลำดับ

```text
Laoo
→ Partner
→ Customer
→ Employee
```

- ตัดระดับ `Branch` ออกจากโครงสร้างปัจจุบัน
- ใช้ `Employee` แทน `User` ใน Business Hierarchy
- Customer เป็นขอบเขตหลักของการแยกข้อมูล
- ทุก Request ที่มีการป้องกันต้องตรวจ Authentication, Partner, Customer, Permission และ Data Scope
- API ต้องตรวจ Context จากตัวตนที่ Login และห้ามเชื่อถือ Partner หรือ Customer ที่ส่งจากหน้าจอเพียงอย่างเดียว

---

## Decision #036 — Meeting Documentation Continuity

**Status:** Approved

- ก่อนเริ่มงานทุกครั้งต้องอ่าน Markdown เดิมตามลำดับที่กำหนดใน `AGENTS.md`
- ต้องนำ Requirement, Standard และมติเดิมที่เกี่ยวข้องมาใช้ทั้งหมด
- เมื่อมีข้อสรุปหรือการเปลี่ยนแปลง Requirement ต้องอัปเดตบันทึกการประชุมหรือ Decision Log ภายในงานรอบเดียวกัน
- หากมติใหม่แทนมติเดิม ให้เก็บประวัติเดิมและเปลี่ยนสถานะเป็น `Superseded`
- เป้าหมายคือให้ทีมทำงานต่อเนื่องได้โดยไม่ต้องให้มนต์อธิบายข้อมูลเดิมซ้ำ

---

## Decision #037 — Friendly Advisory Communication

**Status:** Approved

- ทีมสื่อสารกับมนต์อย่างเป็นกันเองและใช้ภาษาไทยเป็นหลัก
- ทีมทำหน้าที่เป็นที่ปรึกษาอย่างสม่ำเสมอ ไม่จำกัดเฉพาะการรับคำสั่ง Coding
- เมื่อกล่าวถึง Flutter, Tool หรือศัพท์เทคนิค ต้องอธิบายความหมายและผลกระทบให้เข้าใจง่าย
- ต้องเสนอทางเลือก ข้อดี ข้อเสีย และความเสี่ยงก่อนการตัดสินใจที่สำคัญ
- ไม่คาดหวังให้มนต์มีประสบการณ์ด้าน Flutter หรือเครื่องมือพัฒนามาก่อน

---

## Decision #038 — Important Change Git Checkpoint

**Status:** Approved

เมื่อดำเนินการแก้ไขที่สำคัญเสร็จสมบูรณ์ ทีมต้องแจ้งมนต์เสมอว่าเข้าสู่ Git Checkpoint และควรดำเนินการ

```text
Review
→ Commit ลง Git
→ Push ขึ้น GitHub
```

- `Commit` คือการบันทึกประวัติการเปลี่ยนแปลงไว้ใน Git บนเครื่อง
- `Push` คือการส่ง Commit ขึ้น GitHub
- ก่อน Commit ต้องผ่านการตรวจสอบและทดสอบในระดับที่เหมาะสม
- การ Commit และ Push ต้องเป็นไปตาม `GIT_STANDARD.md` และได้รับการอนุมัติตามขั้นตอน
- ทีมต้องเสนอ Commit Message ที่สื่อความหมายให้มนต์ทุกครั้ง

---

## Decision #039 — Product Folder Layout

**Status:** Approved

วันที่ทบทวน: 2026-08-05

ผลการตรวจโครงสร้าง Repository ปัจจุบัน

- `C:\laoo` ใช้เก็บเอกสารและเครื่องมือส่วนกลาง ถูกต้องตามมาตรฐาน
- `C:\laoo\projects\laoo` เป็น Product แรก ถูกต้องตามหลัก Product Isolation
- Product ใหม่ควรเป็น Folder ระดับเดียวกันภายใต้ `projects/<product-name>`
- `docs/`, `tools/` และ `scripts/` เป็นทรัพยากรส่วนกลาง ไม่ควรคัดลอกแยกในแต่ละ Product
- Folder มาตรฐานที่ยังไม่มีเนื้อหาใช้ `.gitkeep` เพื่อให้ Git เก็บโครงสร้างไว้แล้ว

โครงสร้างมาตรฐานของแต่ละ Product

```text
projects/<product-name>/
├── app/        Flutter application
├── api/        ASP.NET Core Web API
├── database/   SQL Server scripts and migrations
├── docs/       Product-specific documentation
└── <product-name>.code-workspace
```

- Product workspace ต้องเปิด Product พร้อม `docs/` ส่วนกลางได้
- Flutter Project ของ Laoo ย้ายไปที่ `projects/laoo/app`
- `create_laoo_project.ps1` อยู่ใน `app/` เพราะเป็นเครื่องมือสร้าง Flutter Foundation และต้องรันจาก Flutter root
- Root `gitignore` เปลี่ยนชื่อเป็น `.gitignore` เพื่อให้ Git ใช้งานจริง
- `projects/laoo/README.md` เป็นเอกสารภาพรวมเฉพาะ Product
- ตรวจสอบหลังย้ายแล้ว: `dart format .`, `flutter analyze`, `flutter test` และ `flutter build web` ผ่าน

---

## Decision #040 — Laoo VS Code Workspace Entry

**Status:** Approved

เมื่อเริ่มหรือกลับมาทำงานใน Product Laoo ต้องเปิด VS Code ด้วยไฟล์ต่อไปนี้

```text
C:\laoo\projects\laoo\laoo.code-workspace
```

ห้ามใช้ `projects/laoo/app` เป็น Workspace หลักของทีม เพราะจะไม่เห็นเอกสารมาตรฐานกลางใน `C:\laoo\docs` ภายใน Workspace เดียวกัน

Workspace นี้ต้องประกอบด้วยอย่างน้อย

- `Laoo Product` — Source Code และไฟล์เฉพาะ Product
- `Laoo Shared Standards` — เอกสารมาตรฐานกลางจาก `C:\laoo\docs`

ก่อนเริ่มงาน CI และ AI ต้องตรวจสอบว่าเปิด Workspace ถูกต้อง และอ่านเอกสารตามลำดับใน `AGENTS.md`

---

# Pending Decisions

หัวข้อที่ยังต้องตัดสินใจภายหลัง

- State Management
- Routing
- Dependency Injection
- Local Storage
- API Client
- Logging Library
- Error Handling Strategy
- Backend Project Structure
- Database Naming Standard
- Release Versioning Strategy

---

# Final Principle

> ทุกมติสามารถปรับเปลี่ยนได้ตามประสบการณ์จริง แต่ต้องผ่านการ Review ของทีมและบันทึกเหตุผลเสมอ
