# STATE_MANAGEMENT_STANDARD

Version: 1.1\
Last Update: 2026-08-05

Project: Laoo Solutions

Primary Flutter Project: `laoo`

Status: Approved

------------------------------------------------------------------------

# Purpose

กำหนดมาตรฐานการจัดการ State สำหรับทุกแอปพลิเคชัน Flutter ของ Laoo Solutions
โดยเป็นมาตรฐานกลางที่สามารถใช้งานร่วมกับ AI หลายแพลตฟอร์มได้ เช่น ChatGPT, Codex,
Claude, Gemini, Copilot และ Cursor

------------------------------------------------------------------------

# Scope

ใช้กับ

-   Flutter Mobile
-   Flutter Tablet
-   Flutter Desktop
-   Flutter Web

------------------------------------------------------------------------

# Objectives

-   ใช้มาตรฐานเดียวกันทั้งองค์กร
-   แยก UI ออกจาก Business Logic
-   รองรับ Clean Architecture
-   รองรับ Riverpod รุ่นปัจจุบัน
-   ทดสอบได้ง่าย
-   ลดการ Rebuild ที่ไม่จำเป็น
-   รองรับการขยายระบบในอนาคต

------------------------------------------------------------------------

# Table of Contents

1.  Purpose
2.  Scope
3.  Objectives
4.  Approved State Management
5.  Installation
6.  Application Root
7.  State Categories
8.  Provider Types
9.  Widget Standard
10. AsyncValue Standard
11. Immutable State
12. Feature Folder Structure
13. Naming Convention
14. Dependency Direction
15. Authentication State
16. Theme State
17. Customer Context
18. State Persistence
19. Sensitive Data
20. Error Handling
21. Loading Standard
22. Provider Lifetime
23. Refresh Standard
24. Testing Standard
25. Coding Rules
26. Initial Providers
27. Implementation Order
28. Definition of Done
29. State Lifecycle
30. Provider Decision Matrix
31. Provider Dependency Rules
32. Performance Guideline
33. AI Compatibility Rules
34. Related Documents
35. Version History

------------------------------------------------------------------------

# 29. State Lifecycle

ทุก Provider ควรมีวงจรชีวิตดังนี้

Created

↓

Initialized

↓

Loading

↓

Ready

↓

Updated

↓

Disposed

Provider ระดับ Application ควรมีอายุเท่ากับ Application

Provider สำหรับหน้าจอหรือข้อมูลชั่วคราวควรใช้ AutoDispose ตามความเหมาะสม

------------------------------------------------------------------------

# 30. Provider Decision Matrix

  กรณี              มาตรฐาน
  ---------------- -----------------------
  Configuration    Provider
  Theme            NotifierProvider
  Authentication   AsyncNotifierProvider
  Product List     AsyncNotifierProvider
  Shopping Cart    NotifierProvider
  App Version      FutureProvider
  WebSocket        StreamProvider

------------------------------------------------------------------------

# 31. Provider Dependency Rules

ลำดับการเรียกใช้งาน

UI

↓

Provider / Notifier

↓

Repository

↓

Service / API

↓

External System

ห้าม

-   UI → API โดยตรง
-   UI → Database โดยตรง
-   Repository → Widget
-   Service → Widget

------------------------------------------------------------------------

# 32. Performance Guideline

-   ใช้ ConsumerWidget ให้เล็กที่สุด
-   ใช้ ref.watch() เฉพาะข้อมูลที่ต้อง Rebuild
-   ใช้ ref.read() สำหรับ Action
-   ใช้ ref.listen() สำหรับ Side Effect
-   ใช้ select() เมื่อต้องการฟังเฉพาะบาง Property
-   หลีกเลี่ยงการ Rebuild ทั้งหน้าจอ

------------------------------------------------------------------------

# 33. AI Compatibility Rules

เอกสารนี้เป็นมาตรฐานกลางของ Laoo Solutions

AI ทุกตัวต้องใช้มาตรฐานนี้เป็นค่าเริ่มต้น หาก Requirement ไม่ได้ระบุเป็นอย่างอื่น

หาก AI จำเป็นต้องแตกต่างจากมาตรฐาน ต้องอธิบายเหตุผลทุกครั้ง

------------------------------------------------------------------------

# 34. Related Documents

-   PROJECT_CONTEXT.md
-   ARCHITECTURE.md
-   ROUTING_STANDARD.md
-   API_STANDARD.md
-   AUTHENTICATION_STANDARD.md
-   PERMISSION_STANDARD.md
-   THEME_STANDARD.md

------------------------------------------------------------------------

# 35. Version History

  -----------------------------------------------------------------------
  Version                Date            Description
  ---------------------- --------------- --------------------------------
  1.0                    2026-08-05      Initial Release

  1.1                    2026-08-05      เพิ่ม Scope, AI Compatibility,
                                         State Lifecycle, Provider
                                         Decision Matrix, Dependency
                                         Rules, Performance Guideline,
                                         Related Documents และ Version
                                         History
  -----------------------------------------------------------------------
