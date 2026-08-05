# PROJECT_NAME

Version: 1.0  
Last Update: YYYY-MM-DD  
Status: Draft

---

# Project Information

Project Name:

```text
project_name
```

Display Name:

```text
Project Display Name
```

Project Type:

```text
Flutter Application
```

Project Path:

```text
C:\laoo\project_name
```

---

# Meaning Agreement

กำหนดความหมายของชื่อ Project เพื่อป้องกันความสับสน

---

# Purpose

อธิบายหน้าที่หลักของ Project

---

# Current Objective

อธิบายเป้าหมายงานปัจจุบันที่ต้องทำให้เสร็จก่อน

---

# Version Scope

Version ปัจจุบันต้องทำ

- Item 1
- Item 2

---

# Out of Scope

Version ปัจจุบันยังไม่รวม

- Item 1
- Item 2

---

# Required Documents

## Core

- `C:\laoo\docs\README.md`
- `C:\laoo\docs\AGENTS.md`
- `C:\laoo\docs\PROJECT_CONTEXT.md`
- `C:\laoo\docs\PROJECT_WORKFLOW_STANDARD.md`

## Architecture

- ระบุเฉพาะเอกสารที่เกี่ยวข้องจริง

## Standards

- ระบุเฉพาะ Standard ที่ Project ต้องใช้

## Project Specific

- ระบุเอกสารเฉพาะ Project ถ้ามี
- หากไม่มีให้เขียน `None`

---

# Target Platforms

- Windows
- Web
- Android
- iOS

ลบ Platform ที่ไม่ใช้จริงออก

---

# Development Rules

- พัฒนาทีละส่วน
- ต้องรักษาให้ Build และ Run ได้
- ห้ามสร้าง Feature ที่อยู่นอก Scope
- ต้องระบุ Full Path ของไฟล์
- ต้องตรวจด้วย `flutter analyze`
- ต้องอัปเดตเอกสารเมื่อ Requirement เปลี่ยน

---

# Definition of Done

- `flutter pub get` ผ่าน
- `flutter analyze` ผ่าน
- `flutter test` ผ่าน
- Run บน Platform เป้าหมายผ่าน
- UI/Feature ตรงตาม Scope
- ไม่มี Error ที่ทราบและยังไม่ได้บันทึก
