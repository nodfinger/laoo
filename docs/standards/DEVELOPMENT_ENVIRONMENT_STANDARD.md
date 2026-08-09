# DEVELOPMENT_ENVIRONMENT_STANDARD.md

# Laoo Development Environment Standard

Version: 1.0

Status: Approved

---

# Purpose

กำหนดมาตรฐานการติดตั้งเครื่องสำหรับนักพัฒนา เพื่อให้ทุกคนสามารถพัฒนา ทดสอบ และ Deploy ระบบได้ด้วยสภาพแวดล้อมเดียวกัน

---

# Operating System

รองรับ

* Windows 11 (แนะนำ)
* Windows 10 (รองรับ)

---

# Source Control

ใช้

* Git
* GitHub

Repository หลักของบริษัท

```
https://github.com/nodfinger/laoo
```

---

# Development Tools

## Visual Studio Code

ใช้สำหรับ

* Flutter
* Markdown
* Git
* AI Assistant

Extension ที่แนะนำ

* Flutter
* Dart
* GitHub Copilot (ถ้ามี)
* GitLens
* Error Lens

---

## Visual Studio 2022

ใช้สำหรับ

* ASP.NET Core Web API
* Backend
* SQL Tools

---

# Flutter

ติดตั้ง Flutter SDK เวอร์ชัน Stable

ตรวจสอบ

```bash
flutter doctor
```

ต้องไม่มี Error ที่มีผลต่อการพัฒนา

---

# Android Studio

ใช้สำหรับ

* Android SDK
* Emulator
* SDK Manager

---

# Android SDK

ต้องติดตั้ง

* Android SDK
* Platform Tools
* Build Tools

---

# Windows Developer Mode

ต้องเปิดใช้งาน

Settings

→ System / Privacy & Security

→ For Developers

→ เปิด

```
Developer Mode
```

เหตุผล

Flutter Plugin หลายตัวใช้ Symbolic Link

เช่น

* shared_preferences
* path_provider
* image_picker
* file_picker
* camera

หากไม่เปิด Developer Mode

อาจพบข้อความ

```
Building with plugins requires symlink support.
```

---

# Git Configuration

ตรวจสอบ

```bash
git --version
```

ตั้งค่า

```bash
git config --global user.name "Your Name"

git config --global user.email "you@example.com"
```

---

# Git Workflow

ใช้ตาม

```
GIT_STANDARD.md
```

---

# Flutter Package

ติดตั้ง Package ทีละตัว

ตัวอย่าง

```bash
flutter pub add flutter_riverpod

flutter pub add shared_preferences
```

ไม่แนะนำให้ติดตั้งหลาย Package พร้อมกันในช่วงเริ่มต้นของ Project

---

# Folder Standard

Workspace

```
C:\laoo
```

Project หลักอยู่ที่ Root โดยตรง

```text
C:\laoo\laoo
C:\laoo\laoo_meeting
C:\laoo\laoo_api
```

ห้ามสร้างหรือย้าย Project กลับไปไว้ใต้ `C:\laoo\projects`

---

# Build Verification

ก่อนเริ่มพัฒนา

ต้องผ่าน

```bash
flutter doctor
```

และ

```bash
flutter run
```

ได้สำเร็จ

---

# Security

ห้ามเก็บข้อมูลต่อไปนี้ใน Git Repository

* Password
* API Key
* Connection String จริง
* Certificate
* Private Key

ใช้ `.gitignore` ตามมาตรฐานของบริษัท

---

# AI Development

สมาชิกทีมและ AI ต้องเริ่มจาก `DOCUMENTATION_GUIDE.md` แล้วอ่านเอกสารบังคับของงานนั้น

---

# Definition of Ready

เครื่องของนักพัฒนาพร้อมใช้งาน เมื่อ

* Git ใช้งานได้
* GitHub เชื่อมต่อได้
* Flutter Doctor ผ่าน
* Flutter Run ผ่าน
* Windows Developer Mode เปิดใช้งาน
* Android SDK พร้อม
* Visual Studio Code พร้อม
* Visual Studio 2022 พร้อม (สำหรับ Backend)

---

# Final Principle

ทุกเครื่องของทีมควรมีสภาพแวดล้อมเดียวกัน เพื่อลดปัญหาที่เกิดจากความแตกต่างของการติดตั้ง และทำให้การพัฒนา การทดสอบ และการ Deploy เป็นไปในมาตรฐานเดียวกัน
