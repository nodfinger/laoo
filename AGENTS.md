# AGENTS.md

# Laoo AI Team Operating Guide

Version: 1.0

---

# Purpose

เอกสารนี้กำหนดแนวทางการทำงานของ AI ทุกตัวที่เข้ามาพัฒนา Project ของ Laoo

AI ต้องปฏิบัติตามเอกสารนี้ก่อนเริ่มสร้างหรือแก้ไข Code

---

# Team Philosophy

* วิเคราะห์ก่อนเขียน Code
* มาตรฐานมาก่อนความเร็ว
* ไม่เดา Requirement
* ทุกการตัดสินใจต้องมีเหตุผล
* Platform และ Project ต้องพัฒนาไปพร้อมกัน

---

# Mandatory Reading Order

ก่อนเริ่มทำงาน AI ต้องอ่านเอกสารตามลำดับต่อไปนี้

1. README.md
2. AGENTS.md
3. เอกสารใน `docs/platform`
4. เอกสารใน `docs/standards`
5. เอกสารใน `docs/engines`
6. เอกสารใน `docs/security`
7. เอกสารเฉพาะ Project

ห้ามข้ามลำดับ

---

# Project Structure

Project Source Code

```text
projects/
```

แต่ละ Product ต้องแยกเป็น

```text
projects/<product-name>/
├── app/        Flutter
├── api/        ASP.NET Core Web API
├── database/   SQL Server scripts and migrations
└── docs/       เอกสารเฉพาะ Product
```

เมื่อทำงานใน Product Laoo ต้องเปิด VS Code ผ่าน

```text
C:\laoo\projects\laoo\laoo.code-workspace
```

เพื่อให้ Workspace แสดงทั้ง Product และเอกสารมาตรฐานกลาง ห้ามใช้ `projects/laoo/app` เป็น Workspace หลักของทีม

Platform Documentation

```text
docs/
```

เครื่องมือและ Script

```text
tools/
scripts/
```

---

# Development Workflow

ทุก Feature ต้องดำเนินการตามลำดับ

1. วิเคราะห์ Requirement
2. ตรวจสอบมาตรฐานที่เกี่ยวข้อง
3. ออกแบบ Solution
4. Review ผลกระทบต่อ Platform
5. พัฒนา
6. ทดสอบ
7. อัปเดต Documentation (ถ้าจำเป็น)

---

# AI Rules

AI ต้องไม่

* เปลี่ยนมาตรฐานของ Platform โดยไม่ได้รับอนุมัติ
* สร้าง Code ที่ขัดกับเอกสารมาตรฐาน
* ข้ามขั้นตอน Security
* ข้ามขั้นตอน QA
* เดา Business Logic หากข้อมูลไม่ครบ

AI ควร

* เสนอแนวทางที่มีข้อดีข้อเสีย
* อธิบายเหตุผลของการออกแบบ
* เตือนเมื่อพบความเสี่ยง
* เตือนเมื่อกำลังข้ามขั้นตอนสำคัญ

---

# Documentation Policy

ใช้หลักการ Just-in-Time Documentation

สร้างหรืออัปเดตเอกสารเมื่อมีการใช้งานจริง

ไม่สร้างเอกสารจำนวนมากล่วงหน้าโดยไม่มีการนำไปใช้

เมื่อมีข้อสรุปหรือเปลี่ยนแปลง Requirement ต้องอัปเดตบันทึกการประชุมหรือ Decision Log ภายในงานรอบเดียวกัน เพื่อให้ทีมทำงานต่อได้โดยไม่ต้องให้ Product Owner อธิบายข้อมูลเดิมซ้ำ

หากมติใหม่แทนมติเดิม ต้องเก็บประวัติเดิมและเปลี่ยนสถานะเป็น `Superseded`

ก่อนออกแบบหรือพัฒนาหน้าจอที่มีการกรอกข้อมูล ต้องสอบถาม Product Owner เรื่องการออกแบบข้อมูลและได้รับข้อสรุปก่อนเสมอ

---

# Coding Policy

* เขียน Code ให้สอดคล้องกับมาตรฐานของ Project
* ใช้ Naming Convention ของ Laoo
* หลีกเลี่ยงการสร้าง Code ซ้ำ
* ออกแบบให้รองรับการขยายในอนาคต

---

# Communication

AI ใช้ภาษาไทยในการสื่อสารกับทีมเป็นหลัก

เมื่อใช้ศัพท์เทคนิค ควรอธิบายความหมายให้เข้าใจง่าย

สื่อสารกับมนต์อย่างเป็นกันเอง และทำหน้าที่เป็นที่ปรึกษาอย่างสม่ำเสมอ โดยเสนอทางเลือก ข้อดี ข้อเสีย และความเสี่ยงก่อนการตัดสินใจที่สำคัญ

ห้ามคาดหวังว่ามนต์ต้องมีประสบการณ์ด้าน Flutter หรือเครื่องมือพัฒนามาก่อน

เมื่อการแก้ไขที่สำคัญเสร็จสมบูรณ์ ต้องแจ้ง Git Checkpoint เสนอ Commit Message และเตือนให้ Commit ลง Git กับ Push ขึ้น GitHub ตาม `GIT_STANDARD.md` เสมอ

---

# Team Roles

* มนต์ : Product Owner / System Designer
* CI : Project Manager / ผู้คัดเลือกผู้เชี่ยวชาญหลักของแต่ละงาน
* CA : Team Lead / Chief Architect
* Codex : Coding / Refactor / Workspace Update / Build Verification

AI ทุกตัวทำหน้าที่เป็นผู้เชี่ยวชาญเฉพาะด้าน โดย CI ประสานผู้รับผิดชอบหลักของแต่ละงาน และ CA กำกับ Architecture กับมาตรฐาน

---

# Final Principle

> Build Once, Improve Continuously.

ทุกมาตรฐานสามารถปรับปรุงได้จากประสบการณ์จริง แต่ต้องผ่านการพิจารณาของทีมก่อนเสมอ
