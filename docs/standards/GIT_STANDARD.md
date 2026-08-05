# GIT_STANDARD.md

# Laoo Git Standard

Version: 1.0

---

# Purpose

กำหนดมาตรฐานการใช้งาน Git และ GitHub ของทีม Laoo

วัตถุประสงค์

* ให้ทุก Project ใช้มาตรฐานเดียวกัน
* ทำให้ประวัติการพัฒนาอ่านง่าย
* สามารถย้อนกลับไปตรวจสอบได้
* รองรับการทำงานร่วมกันของทีม

---

# Git Workflow

```text
Requirement
    ↓
Development
    ↓
Review
    ↓
Checkpoint (CA)
    ↓
Commit
    ↓
Push
```

---

# CA Checkpoint

ก่อน Commit ทุกครั้ง

CA จะเป็นผู้ตรวจสอบว่า

* Feature ทำงานครบ
* ผ่านการ Review
* ผ่านการทดสอบในระดับที่เหมาะสม
* เอกสารที่เกี่ยวข้องได้รับการอัปเดต (ถ้าจำเป็น)

เมื่อผ่านแล้ว CA จะประกาศ

> ✅ Checkpoint Approved

จึงสามารถ Commit ได้

---

# Commit Policy

Commit เมื่อ

* จบ Milestone
* จบ Feature
* จบ Bug Fix
* จบ Refactoring ที่มีความหมาย
* จบการแก้ไขเอกสารมาตรฐานที่สำคัญ

ไม่ควร Commit เมื่อ

* กำลังทดลอง
* Code ยัง Compile ไม่ผ่าน
* งานยังไม่สมบูรณ์
* แก้ไขเล็กน้อยระหว่างการพัฒนา

เมื่อการแก้ไขที่สำคัญเสร็จสมบูรณ์ AI ต้องแจ้งทีมว่าเข้าสู่ Git Checkpoint พร้อมสรุปผลการตรวจสอบและเสนอ Commit Message ที่เหมาะสม

---

# Commit Message Standard

ใช้ข้อความที่สื่อความหมายชัดเจน

ตัวอย่าง

Initialize Laoo Platform Repository

Add platform foundation documents

Create Flutter project

Implement login module

Add permission engine

Improve dashboard layout

Fix authentication validation

Update security standard

---

# Branch Strategy

Main Branch

* main

Development Branch

* develop

Feature Branch

* feature/<feature-name>

Bug Fix Branch

* fix/<bug-name>

Release Branch (ใช้เมื่อจำเป็น)

* release/<version>

---

# Push Policy

Push เมื่อ

* Commit ผ่านการตรวจสอบแล้ว
* CA อนุมัติให้ Push
* พร้อมแชร์ให้ทีมใช้งาน

หลัง Commit สำเร็จ AI ต้องเตือนให้ Push ขึ้น GitHub เสมอ โดยยังคงต้องได้รับการอนุมัติตามขั้นตอนของทีม

---

# Documentation Policy

หากมีการเปลี่ยนแปลงมาตรฐานของ Platform

ต้องอัปเดต Documentation ที่เกี่ยวข้องก่อนหรือพร้อมกับการ Commit

---

# Repository Policy

Repository ต้องไม่เก็บ

* Password
* API Key
* Connection String จริง
* Certificate
* Private Key
* ไฟล์ Build
* Cache
* ไฟล์ชั่วคราว

ใช้ `.gitignore` ตามมาตรฐานของ Laoo

---

# Release Tag

เมื่อมีการ Release

ใช้ Tag เช่น

v0.1.0

v1.0.0

v1.1.0

---

# Final Principle

Git คือประวัติการพัฒนาของบริษัท

ทุก Commit ควรมีความหมาย

ทุก Commit ควรสามารถอธิบายได้ว่าทีมได้พัฒนาอะไรสำเร็จ
