# LAOO PROJECT

Version: 1.1  
Last Update: 2026-08-05  
Status: Active

---

# Project Information

Project Name:

```text
laoo
```

Display Name:

```text
Laoo
```

Project Type:

```text
Flutter Application
```

Project Path:

```text
C:\laoo\laoo
```

---

# Meaning Agreement

เมื่อใช้คำว่า `laoo` ให้หมายถึง Flutter Project นี้เท่านั้น

เมื่อใช้คำว่า `Laoo Solutions` ให้หมายถึง Platform และ Ecosystem ทั้งหมด

---

# Purpose

`laoo` เป็น Public Portal สำหรับแสดงข้อมูลเบื้องต้นและเป็นจุดเริ่มต้นเข้าสู่ Product ต่าง ๆ ของ Laoo Solutions

ในอนาคตโครงสร้างเดียวกันสามารถใช้เป็น Customer Portal ที่มี Domain และ Branding ของลูกค้าได้

---

# Current Objective

สร้างหน้า Portal แบบเรียบง่ายที่ Build และ Run ได้จริง

---

# Version Scope

- แสดงชื่อ `Laoo`
- มีปุ่ม `Login` ด้านบน
- มีข้อความแนะนำสั้น ๆ
- มี Product Card ตัวอย่าง
- รองรับ Layout หลายขนาด

---

# Out of Scope

- Login จริง
- Authentication
- API
- SQL Server
- Permission
- Product Routing จริง
- Customer Domain Configuration
- Dynamic Branding

---

# Required Documents

## Core

- `C:\laoo\docs\README.md`
- `C:\laoo\docs\AGENTS.md`
- `C:\laoo\docs\PROJECT_CONTEXT.md`
- `C:\laoo\docs\PROJECT_WORKFLOW_STANDARD.md`

## Architecture

- `C:\laoo\docs\platform\ARCHITECTURE.md`

## Standards

- `C:\laoo\docs\standards\TECH_STACK_STANDARD.md`
- `C:\laoo\docs\standards\ROUTING_STANDARD.md`
- `C:\laoo\docs\standards\STATE_MANAGEMENT_STANDARD.md`
- `C:\laoo\docs\standards\PROJECT_NAMING_STANDARD.md`
- `C:\laoo\docs\standards\COMPANY_PARTNER_BRANCH_STANDARD.md`

## Project Specific

None

---

# Target Platforms

- Windows
- Web
- Android
- iOS

---

# Development Rules

- พัฒนาทีละส่วน
- ต้องรักษาให้ Build และ Run ได้
- ไม่สร้าง Feature ที่อยู่นอก Scope
- ไม่เชื่อม API หรือ Database จนกว่าจะได้รับอนุมัติ
- ต้องระบุ Full Path ของไฟล์
- ต้องตรวจด้วย `flutter analyze`
- ต้องทดสอบ Web เมื่อ Feature สำคัญเสร็จ

---

# Definition of Done

- `flutter pub get` ผ่าน
- `flutter analyze` ผ่าน
- `flutter test` ผ่าน
- `flutter run -d windows` ผ่าน
- หน้าแรกแสดงชื่อ `Laoo`
- มีปุ่ม `Login`
- มี Product Card ตัวอย่าง
- ไม่มี Error

# PROJECT.md UPDATE FOR LAOO

ให้นำรายการต่อไปนี้ไปเพิ่มในหัวข้อ `Required Documents` ของ

```text
C:\laoo\laoo\PROJECT.md
```

## API

- `C:\laoo\docs\api\SYSTEM_INFO_API.md`
- `C:\laoo\docs\api\API_ERROR_STANDARD.md`

## Standards

ตรวจสอบว่ามีรายการนี้อยู่แล้ว

- `C:\laoo\docs\standards\API_STANDARD.md`

ถ้าไฟล์ `API_STANDARD.md` ยังไม่มีจริง ให้แจ้งเป็น Missing Required Document และยังไม่เดาเนื้อหาแทน
