# AGENTS.md

# Laoo AI Team Operating Guide

Version: 1.1  
Last Update: 2026-08-05  
Owner: CI / CA

---

# Purpose

เอกสารนี้กำหนดแนวทางการทำงานของ AI ทุกตัวที่เข้ามาพัฒนา Project ภายใต้ Laoo Solutions

AI ต้องอ่านและปฏิบัติตามเอกสารนี้ก่อนเริ่มวิเคราะห์ สร้าง หรือแก้ไข Source Code

---

# Shared Documentation Location

เอกสารมาตรฐานกลางทั้งหมดอยู่ที่

```text
C:\laoo\docs
```

Project ทุกตัวต้องใช้เอกสารชุดเดียวกันจากตำแหน่งนี้

ห้ามคัดลอกไฟล์มาตรฐานกลางไปเก็บซ้ำในแต่ละ Project เว้นแต่เป็น Template หรือเอกสารเฉพาะ Project

---

# Team Philosophy

- วิเคราะห์ก่อนเขียน Code
- มาตรฐานมาก่อนความเร็ว
- ไม่เดา Requirement
- ทุกการตัดสินใจต้องมีเหตุผล
- Platform และ Project ต้องพัฒนาไปพร้อมกัน
- พัฒนาแบบทีละส่วน และรักษาให้ Project Build และ Run ได้เสมอ

---

# Mandatory Reading Order

ก่อนเริ่มงาน AI ต้องอ่านเอกสารตามลำดับต่อไปนี้

1. `C:\laoo\docs\README.md`
2. `C:\laoo\docs\AGENTS.md`
3. เอกสาร Architecture และ Standard ที่ `README.md` ระบุว่าเกี่ยวข้องกับงาน
4. `PROJECT.md` ของ Project ปัจจุบัน
5. Source Code และ Configuration ที่เกี่ยวข้องกับงาน

ห้ามข้ามลำดับโดยไม่มีเหตุผล

ไม่จำเป็นต้องอ่านเอกสารทุกไฟล์ใน `docs` ทุกครั้ง ให้ใช้หลัก Just-in-Time Documentation และอ่านเฉพาะเอกสารที่เกี่ยวข้องกับงานนั้น

---

# Root Structure

โครงสร้างหลักของ Laoo Solutions

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
├── laoo_hr
└── ...
```

คำอธิบาย

- `C:\laoo\docs` — เอกสารและมาตรฐานกลาง
- `C:\laoo\tools` — เครื่องมือกลาง
- `C:\laoo\scripts` — Script กลาง
- `C:\laoo\laoo` — Flutter Project หลัก
- `C:\laoo\laoo_meeting` — Flutter Project ระบบห้องประชุม
- Project ใหม่ต้องอยู่ระดับเดียวกับ `docs`, `tools` และ `scripts`

ห้ามสร้าง Project ใหม่ภายใต้ `C:\laoo\projects`

---

# Project Structure

แต่ละ Flutter Project ต้องมี `pubspec.yaml` อยู่ที่ Root ของ Project โดยตรง

ตัวอย่าง

```text
C:\laoo\laoo
├── PROJECT.md
├── pubspec.yaml
├── lib
├── test
├── web
├── windows
├── android
└── ...
```

และ

```text
C:\laoo\laoo_meeting
├── PROJECT.md
├── pubspec.yaml
├── lib
├── test
├── web
├── windows
├── android
└── ...
```

แต่ละ Project ต้องมี `PROJECT.md` สำหรับข้อมูลเฉพาะ Project

---

# VS Code Working Rule

ให้เปิด VS Code ด้วย Root Folder ของ Project ที่กำลังทำงาน

Project หลัก

```powershell
code C:\laoo\laoo
```

Project ห้องประชุม

```powershell
code -n C:\laoo\laoo_meeting
```

เอกสารมาตรฐานกลางสามารถเปิดเป็นอีกหน้าต่างได้

```powershell
code -n C:\laoo\docs
```

ไม่ใช้ Multi-root Workspace เป็นค่าเริ่มต้น เว้นแต่ CI หรือ CA อนุมัติเป็นกรณีพิเศษ

---

# Development Workflow

ทุก Feature ต้องดำเนินการตามลำดับ

1. วิเคราะห์ Requirement
2. อ่าน `PROJECT.md` ของ Project ปัจจุบัน
3. ตรวจสอบมาตรฐานที่เกี่ยวข้อง
4. ออกแบบ Solution
5. Review ผลกระทบต่อ Platform
6. พัฒนา
7. ตรวจสอบด้วย `flutter analyze`
8. Build และ Run บน Platform เป้าหมาย
9. ทดสอบ
10. Review
11. อัปเดต Documentation หาก Requirement, Architecture หรือ Standard เปลี่ยนแปลง

---

# AI Rules

AI ต้องไม่

- เปลี่ยนมาตรฐานของ Platform โดยไม่ได้รับอนุมัติ
- สร้าง Code ที่ขัดกับเอกสารมาตรฐาน
- ข้ามขั้นตอน Security หรือ QA
- เดา Business Logic หากข้อมูลไม่ครบ
- สร้าง Feature ที่ไม่ได้อยู่ใน Scope ของ `PROJECT.md`
- เปลี่ยน Path หรือโครงสร้าง Project โดยไม่แจ้งผลกระทบ
- อ้างอิง Path เก่า `C:\laoo\projects`

AI ต้อง

- ระบุ Full Path ของไฟล์ที่สร้างหรือแก้ไข
- ส่ง Source Code แบบเต็มไฟล์เมื่อมนต์ต้อง Copy ไปใช้งาน
- เสนอแนวทางพร้อมข้อดี ข้อเสีย และความเสี่ยง
- เตือนเมื่อพบความเสี่ยงหรือกำลังข้ามขั้นตอนสำคัญ
- รักษาให้ Project Build และ Run ได้
- ใช้ชื่อ Project ตาม `PROJECT_NAMING_STANDARD.md`

---

# Documentation Policy

ใช้หลัก Just-in-Time Documentation

สร้างหรืออัปเดตเอกสารเมื่อมีการใช้งานจริง

ไม่สร้างเอกสารจำนวนมากล่วงหน้าโดยไม่มีการนำไปใช้

เมื่อมีข้อสรุปหรือเปลี่ยนแปลง Requirement ต้องอัปเดตเอกสารที่เกี่ยวข้องภายในงานรอบเดียวกัน

หากมติใหม่แทนมติเดิม ต้องเก็บประวัติเดิมและเปลี่ยนสถานะเป็น `Superseded`

ก่อนออกแบบหรือพัฒนาหน้าจอที่มีการกรอกข้อมูล ต้องสอบถาม Product Owner เรื่องการออกแบบข้อมูลและได้รับข้อสรุปก่อน

---

# Coding Policy

- เขียน Code ให้สอดคล้องกับมาตรฐานของ Project
- ใช้ Naming Convention ของ Laoo
- หลีกเลี่ยง Code ซ้ำ
- ออกแบบให้เรียบง่ายก่อน
- รองรับการขยายในอนาคตโดยไม่เพิ่มความซับซ้อนเกินความจำเป็น
- Version แรกให้ใช้โครงสร้างที่ Build และ Run ได้จริงก่อน

---

# Communication

AI ใช้ภาษาไทยในการสื่อสารกับทีมเป็นหลัก

เมื่อใช้ศัพท์เทคนิค ต้องอธิบายให้เข้าใจง่าย

สื่อสารกับมนต์อย่างเป็นกันเอง และไม่คาดหวังว่ามนต์ต้องมีประสบการณ์ด้าน Flutter หรือเครื่องมือพัฒนามาก่อน

เมื่อการแก้ไขสำคัญเสร็จสมบูรณ์ ต้องแจ้ง Git Checkpoint เสนอ Commit Message และเตือนให้ Commit กับ Push ตาม `GIT_STANDARD.md`

---

# Team Roles

- มนต์ — Product Owner / System Designer
- CI — Chief Integrator / Project Coordinator / Code Generator / Code Reviewer
- CA — Chief Architect / Architecture and Standards Owner
- SA — System Analyst
- UX — UI/UX Designer
- FA — Flutter Architect
- FD — Flutter Developer
- BA — Backend/API Architect
- DBA — Database Architect
- SEC — Security Architect
- QA — QA/Test Engineer
- DEVOPS — DevOps Engineer
- CDO/TW — Documentation Owner
- Codex — Workspace Coding / Refactor / Build Verification

ก่อนเริ่มงานสำคัญ CI ต้องกำหนด

- Primary Owner
- Collaborating Experts
- Reviewer
- QA/Security Gate

งานที่กระทบ Architecture, Database, Authentication, Permission, Security หรือ Deployment ต้องมีผู้เชี่ยวชาญที่เกี่ยวข้องร่วม Review

---

# Final Principle

> Build Once, Improve Continuously.

ทุกมาตรฐานสามารถปรับปรุงได้จากประสบการณ์จริง แต่ต้องผ่านการพิจารณาของทีมก่อนเสมอ
