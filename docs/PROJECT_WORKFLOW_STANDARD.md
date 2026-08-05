# PROJECT_WORKFLOW_STANDARD

Version: 1.0  
Last Update: 2026-08-05  
Owner: CI / CA / CDO  
Status: Active

---

# Purpose

กำหนดขั้นตอนมาตรฐานสำหรับเริ่ม วิเคราะห์ ออกแบบ พัฒนา และตรวจสอบงานของทุก Project ภายใต้ Laoo Solutions

---

# Core Rule

> ทุกงานต้องเริ่มจาก `PROJECT.md`

`PROJECT.md` คือ Project Manifest และ Source of Truth ของ Project นั้น

---

# Mandatory Workflow

## Step 1 — Identify Project

ระบุให้ชัดว่า Project ปัจจุบันคืออะไร

ตัวอย่าง

```text
C:\laoo\laoo
C:\laoo\laoo_meeting
```

ห้ามทำงานหาก Project Name และ Project Path ไม่ตรงกัน

## Step 2 — Read PROJECT.md

อ่าน

```text
<ProjectRoot>\PROJECT.md
```

ก่อนเอกสารอื่นเสมอ

## Step 3 — Read Required Documents

อ่านเฉพาะไฟล์ที่ระบุในหัวข้อ

```text
Required Documents
```

ของ `PROJECT.md`

## Step 4 — Validate Documents

ตรวจสอบว่า

- Path ถูกต้อง
- ไฟล์มีอยู่จริง
- เอกสารไม่ล้าสมัย
- ไม่มีข้อกำหนดขัดแย้งกัน
- ไม่มี Path เก่า `C:\laoo\projects`

หากไม่ผ่าน ให้แจ้งก่อนและห้ามเดา

## Step 5 — Confirm Scope

สรุปก่อนเริ่มงานว่า

- งานนี้อยู่ใน Scope หรือไม่
- สิ่งใดอยู่ Out of Scope
- ไฟล์ใดจะถูกสร้างหรือแก้ไข
- มีผลกระทบต่อ Project อื่นหรือ Standard กลางหรือไม่

## Step 6 — Inspect Current Source

อ่าน Source Code และ Configuration ปัจจุบันก่อนแก้ไข

ห้ามสร้าง Code ใหม่โดยไม่ตรวจของเดิม

## Step 7 — Design

ออกแบบ Solution ที่เรียบง่ายก่อน

ต้องสอดคล้องกับ

- Project Scope
- Architecture
- Naming
- Security
- QA
- Target Platforms

## Step 8 — Implementation

เมื่อสร้างหรือแก้ไขไฟล์ ต้อง

- ระบุ Full Path
- ส่ง Source Code แบบเต็มไฟล์
- ไม่สร้าง Feature ที่ไม่ได้รับอนุมัติ
- รักษาให้ Project Build และ Run ได้

## Step 9 — Verification

Flutter Project ต้องตรวจอย่างน้อย

```powershell
flutter pub get
flutter analyze
flutter test
```

และ Run บน Platform เป้าหมายตาม Definition of Done

## Step 10 — Documentation Update

อัปเดตเอกสารเมื่อ

- Scope เปลี่ยน
- Requirement เปลี่ยน
- Architecture เปลี่ยน
- เพิ่ม Standard
- เปลี่ยน Path
- มี Decision ใหม่ที่กระทบงานต่อไป

---

# Conflict Handling

หากข้อมูลขัดแย้งกัน

1. แจ้งไฟล์และหัวข้อที่ขัดแย้ง
2. อธิบายผลกระทบ
3. หยุดการเปลี่ยนแปลงที่เกี่ยวข้อง
4. ขอคำตัดสินจากมนต์หรือ CI/CA
5. อัปเดตเอกสารหลังมีมติ

ห้ามแก้ความขัดแย้งด้วยการเดา

---

# Missing Document Handling

หาก `PROJECT.md` อ้างอิงไฟล์ที่ไม่มีอยู่

ให้ตอบว่า

```text
Missing Required Document
```

พร้อมระบุ Full Path

ห้ามแทนที่ด้วยความรู้ทั่วไปโดยไม่แจ้ง

---

# Project Isolation Rule

Requirement ของ Project หนึ่งห้ามไหลไปอีก Project โดยอัตโนมัติ

ตัวอย่าง

- `laoo` ไม่รับ Scope ห้องประชุมจาก `laoo_meeting`
- `laoo_meeting` ไม่รับ Scope Public Portal จาก `laoo`
- Standard กลางใช้ร่วมกันได้
- Project-specific Requirement ใช้เฉพาะ Project ที่ระบุ

---

# Final Principle

> Read the manifest, validate the dependencies, then build.
