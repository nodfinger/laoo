# DEVELOPMENT ROADMAP

Version: 2.0

Project: Laoo Solutions

Status: Approved

Last Update: 2026-08-05

---

# Purpose

กำหนดลำดับการพัฒนาระบบของ Laoo Solutions

เป้าหมายหลักคือ

สร้างระบบที่สามารถใช้งานจริงได้เร็วที่สุด
โดยใช้เอกสารมาตรฐาน (Standards) เป็นแนวทาง
แต่ไม่สร้างเอกสารมากเกินไปจนขาดการทดลองใช้งานจริง

---

# Development Principle

การพัฒนาทุก Feature ต้องใช้หลักการดังนี้

Standard

↓

Implementation

↓

Run

↓

Review

↓

Update Standard

ไม่สร้าง Standard ต่อเนื่องจำนวนมาก
โดยไม่มีการทดลองใช้งานจริง

---

# Current Roadmap

## Phase 1

Foundation

- PROJECT_CONTEXT.md
- ARCHITECTURE.md
- STATE_MANAGEMENT_STANDARD.md
- ROUTING_STANDARD.md

Status

Completed

---

## Phase 2

Flutter Foundation

- Project Structure
- Riverpod
- Go Router
- Theme
- Splash
- Login Screen

Status

In Progress

---

## Phase 3

Backend API

สร้าง ASP.NET Core Web API

ประกอบด้วย

- Authentication API
- Authenticated Business Context API
- Current User API
- Health Check API

เชื่อมต่อ

SQL Server

ใช้

Dapper

---

## Phase 4

Flutter Login

Flutter

↓

REST API

↓

SQL Server

สามารถ

- Login
- ระบุ Partner, Customer และ Employee Context
- รับ JWT / Token
- อ่านข้อมูล Current Employee
- Logout

---

## Phase 5

Marketplace

- Home
- Product
- Category
- Search
- Cart

---

## Phase 6

Order

- Checkout
- Payment
- Order History

---

## Phase 7

Admin

- Dashboard
- Product Management
- Customer Management
- Reports

---

# Documentation Rule

สร้าง Standard เพิ่ม
เมื่อเริ่มพัฒนา Module นั้น

ตัวอย่าง

เริ่ม Login

↓

AUTHENTICATION_STANDARD.md

เริ่ม API

↓

API_STANDARD.md

เริ่ม Permission

↓

PERMISSION_STANDARD.md

ไม่จำเป็นต้องสร้างเอกสารทุกไฟล์
ก่อนเริ่มเขียนโปรแกรม

---

# Current Target

เป้าหมายปัจจุบัน

Project แรกชื่อ Laoo และใช้ Landing Page เป็นหน้าเริ่มต้นของระบบหลัก

Landing Page

↓

Flutter Login

↓

ASP.NET Core Web API

↓

SQL Server

หลัง Login ต้องระบุ Business Context ได้ครบ

```text
Laoo
→ Partner
→ Customer
→ Employee
```

Flutter ห้ามเชื่อมต่อ SQL Server โดยตรง และต้องไม่เก็บ Connection String จริงไว้ในแอปหรือ Git Repository

หน้าสมัครสมาชิกไม่อยู่ในขอบเขตปัจจุบัน

ก่อนออกแบบ Login และ Database Table ต้องได้รับข้อสรุปการออกแบบข้อมูลจากมนต์

---

# Success Criteria

ถือว่า Foundation สำเร็จ เมื่อ

- Flutter Run ได้
- API Run ได้
- SQL Server เชื่อมต่อได้
- Laoo เปิด Landing Page เป็นหน้าเริ่มต้นได้
- Login ผ่าน API ได้
- หลัง Login ระบุ Partner, Customer และ Employee ได้ถูกต้อง
- Customer แต่ละรายเห็นเฉพาะข้อมูลตาม Tenant และ Data Scope ของตนเอง
- รหัสผ่านไม่ถูกจัดเก็บเป็นข้อความปกติ (Plain Text)
- Connection String จริงไม่อยู่ใน Git Repository

หลังจากนั้น

เริ่มพัฒนา Product Navigation, Permission และ Feature ทางธุรกิจต่อไป
