# ROUTING_STANDARD

Version: 1.1\
Last Update: 2026-08-05

Project: Laoo Solutions

Primary Flutter Project: `laoo`

Status: Approved

------------------------------------------------------------------------

# Purpose

กำหนดมาตรฐานการจัดการ Routing สำหรับทุกแอป Flutter ของ Laoo Solutions
เพื่อให้ทุก Feature ใช้รูปแบบเดียวกัน รองรับการขยายระบบ และสามารถใช้งานร่วมกับ AI
หลายแพลตฟอร์มได้

------------------------------------------------------------------------

# Scope

ใช้กับ

-   Flutter Mobile
-   Flutter Tablet
-   Flutter Desktop
-   Flutter Web

------------------------------------------------------------------------

# Objectives

-   มาตรฐานเดียวกันทั้งองค์กร
-   แยก Routing ออกจาก UI
-   รองรับ Deep Link
-   รองรับ Guest และ Login แบบ Optional
-   รองรับ Route Guard และ Permission

------------------------------------------------------------------------

# Approved Router

มาตรฐานของ Laoo Solutions

-   go_router

------------------------------------------------------------------------

# Routing Architecture

Landing

↓

Login (เมื่อจำเป็น)

↓

Protected Feature

------------------------------------------------------------------------

# Route Naming Standard

  Route         Path
  ------------- ----------------
  Landing       `/`
  Marketplace   `/marketplace`
  Login         `/login`
  Product       `/product/:id`
  Cart          `/cart`
  Checkout      `/checkout`
  Profile       `/profile`
  Admin         `/admin`

ใช้ตัวพิมพ์เล็กทั้งหมด และใช้ `-` คั่นคำเมื่อจำเป็น

------------------------------------------------------------------------

# Route Guard

ระดับการเข้าถึง

-   Guest
-   Customer
-   Merchant
-   Admin
-   POS Device

Guest สามารถเข้าหน้า Marketplace และ Product ได้

สำหรับ Product Laoo หน้า Landing เป็น Guest Route และต้องเปิดโดยตรงเมื่อเข้า `/` โดยไม่มี Splash, Welcome หรือ Redirect อัตโนมัติไป Login

Marketplace เป็น Feature ทางธุรกิจในอนาคตและไม่ใช่ Landing Page ของ Product Laoo

------------------------------------------------------------------------

# Navigation Rules

ใช้

-   go() สำหรับเปลี่ยนหน้าปกติ
-   push() สำหรับเปิดหน้าซ้อน
-   pop() สำหรับย้อนกลับ
-   replace() เมื่อไม่ต้องการกลับหน้าก่อน

------------------------------------------------------------------------

# Deep Link Standard

รองรับ

-   Product Link
-   Store Link
-   QR Code
-   Campaign Link
-   Invitation Link

------------------------------------------------------------------------

# Permission Integration

ใช้ร่วมกับ

-   AUTHENTICATION_STANDARD.md
-   PERMISSION_STANDARD.md

Route ที่ต้อง Login ต้องตรวจสอบสิทธิ์ก่อนเปิดเสมอ

------------------------------------------------------------------------

# AI Compatibility Rules

AI ทุกตัวต้องสร้าง Route ตามมาตรฐานนี้

ห้ามสร้าง Route ใหม่โดยไม่เพิ่มในเอกสารนี้ก่อน

------------------------------------------------------------------------

# Related Documents

-   PROJECT_CONTEXT.md
-   ARCHITECTURE.md
-   STATE_MANAGEMENT_STANDARD.md
-   AUTHENTICATION_STANDARD.md
-   PERMISSION_STANDARD.md
-   API_STANDARD.md

------------------------------------------------------------------------

# Version History

  Version   Date         Description
  --------- ------------ -----------------
  1.0       2026-08-05   Initial Release
  1.1       2026-08-05   Set Laoo Landing as initial route and defer Splash and Welcome
