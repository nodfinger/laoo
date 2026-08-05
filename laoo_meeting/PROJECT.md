# LAOO MEETING PROJECT

Version: 1.1  
Last Update: 2026-08-05  
Status: Active

---

# Project Information

Project Name:

```text
laoo_meeting
```

Display Name:

```text
Laoo Meeting
```

Project Type:

```text
Flutter Application
```

Project Path:

```text
C:\laoo\laoo_meeting
```

---

# Purpose

ระบบสำหรับหน้าจอหรืออุปกรณ์ที่ติดตั้งหน้าห้องประชุม เพื่อแสดงข้อมูลห้อง สถานะ และตารางการใช้งาน

Project นี้ใช้ทดสอบว่าหลาย Project สามารถใช้ Standard กลางชุดเดียวกันได้โดย Scope ไม่ปะปนกัน

---

# Current Objective

สร้าง UI หน้า Login แบบเรียบง่าย และรักษาให้ Project Build และ Run ได้

---

# Version Scope

- หน้า Login
- ช่องชื่อผู้ใช้
- ช่องรหัสผ่าน
- ปุ่มแสดงหรือซ่อนรหัสผ่าน
- ตัวเลือกจดจำการเข้าสู่ระบบ
- ปุ่มเข้าสู่ระบบ
- Responsive Layout

---

# Out of Scope

- Authentication จริง
- API
- SQL Server
- Permission
- Validation เชิงธุรกิจ
- Routing หลัง Login
- ระบบจองห้อง
- ระบบจัดการหลังบ้าน

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

- `C:\laoo\docs\meeting\MEETING_STANDARD.md`

---

# Target Platforms

- Windows
- Web
- Android Tablet

Primary Display Mode:

```text
Landscape
```

---

# Development Rules

- พัฒนาทีละส่วน
- Version แรกต้องเรียบง่าย
- ไม่เชื่อม API หรือ Database จนกว่าจะได้รับอนุมัติ
- UI สำหรับหน้าห้องต้องอ่านง่ายจากระยะไกล
- ต้องระบุ Full Path ของไฟล์
- ต้องตรวจด้วย `flutter analyze`
- ต้องทดสอบ Web และ Windows เมื่อ Feature สำคัญเสร็จ

---

# Definition of Done

- `flutter pub get` ผ่าน
- `flutter analyze` ผ่าน
- `flutter test` ผ่าน
- `flutter run -d windows` ผ่าน
- หน้า Login แสดงได้
- Responsive Layout ทำงาน
- ไม่มี Error
