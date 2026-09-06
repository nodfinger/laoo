# REPOSITORY_STANDARD

Version: 1.0  
Last Update: 2026-08-05  
Owner: CI / CA / CDO  
Status: Active

---

# Purpose

กำหนดมาตรฐานโครงสร้าง Repository ของ Laoo Solutions เพื่อให้ทุก Project จัดเก็บไฟล์ได้ตรงตำแหน่ง ลดไฟล์ซ้ำ ลดความสับสน และรองรับการขยายในอนาคต

---

# Root Structure

```text
C:\laooplatform
│
├── docs
├── scripts
├── tools
├── laoo
├── laoo_meeting_api
├── laoo_meeting
└── ...
```

Project ใหม่ต้องอยู่ภายใต้ `C:\laooplatform` โดยตรง

ห้ามสร้าง Project ใหม่ภายใต้

```text
C:\laooplatform\projects
```

---

# Folder Responsibilities

## docs

Path:

```text
C:\laooplatform\docs
```

ใช้เก็บเอกสารและมาตรฐานกลาง เช่น

```text
README.md
AGENTS.md
PROJECT_CONTEXT.md
PROJECT_WORKFLOW_STANDARD.md
api/
deployment/
meeting/
platform/
qa/
security/
standards/
templates/
```

กฎ:

- เป็น Single Source of Truth
- ห้ามคัดลอก Standard ไปซ้ำในแต่ละ Project
- ทุก Project อ้างอิงเอกสารผ่าน `PROJECT.md`
- `AGENTS.md` ต้องอยู่ที่นี่
- ห้ามเก็บ Source Code ของ Application

---

## scripts

Path:

```text
C:\laooplatform\scripts
```

ใช้เก็บ Script กลาง เช่น

```text
backup.ps1
build_all.ps1
clean_all.ps1
create_project.ps1
deploy.ps1
```

กฎ:

- ห้ามเก็บ Password, API Key หรือ Connection String จริง
- Script กลางอยู่ที่นี่
- Script เฉพาะ Project ให้อยู่ใน Project นั้น

---

## tools

Path:

```text
C:\laooplatform\tools
```

ใช้เก็บเครื่องมือกลางและ Utility

ตัวอย่าง:

```text
README.md
.gitkeep
project_generator/
validators/
```

กฎ:

- `README.md` เก็บได้เพื่ออธิบายเครื่องมือ
- ไม่ควรมี `AGENTS.md`
- ไม่ควรเก็บเอกสาร Platform หรือ Project Context
- ถ้ายังไม่มีเครื่องมือ ให้เก็บ `.gitkeep`

---

## laoo

Path:

```text
C:\laooplatformplatform\laoo
```

Flutter Project หลัก

กฎ:

- ต้องมี `pubspec.yaml`
- ต้องมี `PROJECT.md`
- Source Code อยู่ใน `lib`
- Asset อยู่ใน `assets`
- `build` และ `.dart_tool` ต้องไม่ Commit

---

## laoo_meeting_api

Path:

```text
C:\laooplatformplatform\laoo\laoo_meeting_api
```

ASP.NET Core Web API

กฎ:

- ต้องมี `.csproj`
- Connection String จริงอยู่ใน `appsettings.Local.json`
- `appsettings.Local.json` ต้องถูก Ignore
- `bin` และ `obj` ต้องไม่ Commit
- ห้ามเก็บ Secret ใน `appsettings.json`
- Production ใช้ Environment Variable หรือ Secret Store

---

## laoo_meeting

Path:

```text
C:\laooplatformplatform\laoo_meeting
```

Flutter Project ระบบห้องประชุม

กฎ:

- ต้องมี `pubspec.yaml`
- ต้องมี `PROJECT.md`
- Requirement ต้องไม่ปะปนกับ `laoo`
- ใช้มาตรฐานกลางจาก `docs`

---

# Root Files

Root Repository ควรมีเฉพาะไฟล์ที่เกี่ยวกับทั้ง Repository เช่น

```text
.gitignore
LICENSE
```

README หลักปัจจุบันอยู่ที่

```text
C:\laooplatform\docs\README.md
```

ห้ามเก็บไฟล์ชั่วคราวที่ Root เช่น

```text
README_LOCAL_CONFIGURATION.md
UPDATE_GUIDE.md
PROJECT_UPDATE_REQUIRED_DOCUMENTS.md
```

เมื่อใช้งานเสร็จให้ลบออก

---

# Git Rules

ไฟล์ต่อไปนี้ต้องไม่ Commit

```text
appsettings.Local.json
.env
.env.*
bin/
obj/
build/
.dart_tool/
.vs/
*.log
```

ก่อน Commit ต้องตรวจ

```powershell
git status
git diff --cached --name-status
git grep --cached -n -I -E "Password=|User Id=|ApiKey|Api_Key|AccessToken|Bearer "
```

ห้าม Commit

- Password
- Connection String จริง
- API Key
- Access Token
- Private Key
- Certificate Private Key

---

# File Placement Rules

| File Type | Location |
|---|---|
| Standard `.md` | `C:\laooplatform\docs\standards` |
| API Contract | `C:\laooplatform\docs\api` |
| Deployment Plan | `C:\laooplatform\docs\deployment` |
| QA Checklist | `C:\laooplatform\docs\qa` |
| Flutter Code | `<ProjectRoot>\lib` |
| ASP.NET Core Code | `C:\laooplatformplatform\laoo\laoo_meeting_api` |
| Shared Script | `C:\laooplatform\scripts` |
| Shared Tool | `C:\laooplatform\tools` |
| Project Manifest | `<ProjectRoot>\PROJECT.md` |
| Local Secret | `<ProjectRoot>\appsettings.Local.json` |

---

# Duplication Rules

ห้ามมีไฟล์มาตรฐานชื่อเดียวกันหลายตำแหน่ง เช่น

```text
C:\laooplatform\docs\AGENTS.md
C:\laooplatform\tools\AGENTS.md
C:\laooplatform\AGENTS.md
```

ให้ยึดไฟล์จริงเพียงตำแหน่งเดียว:

```text
C:\laooplatform\docs\AGENTS.md
```

ถ้าพบไฟล์ซ้ำ:

1. ตรวจว่าไฟล์ใดใหม่ที่สุด
2. รวมเนื้อหาที่จำเป็น
3. ลบไฟล์ซ้ำ
4. อัปเดต Path ที่อ้างอิง
5. Commit พร้อมคำอธิบาย

---

# Temporary Release Files

ไฟล์ส่งมอบชั่วคราว เช่น

```text
UPDATE_GUIDE.md
CHANGELOG.md
README_LOCAL_CONFIGURATION.md
```

ไม่ควรคัดลอกเข้า Repository เว้นแต่ระบุชัดว่าเป็นเอกสารระยะยาว

Release Pack ควรมี

```text
docs/
files/
CHANGELOG.md
```

โดย

- `docs` = เอกสารที่ต้องเก็บ
- `files` = ไฟล์ที่ต้อง Copy
- `CHANGELOG.md` = เอกสารประกอบ Release

---

# Project Migration Rule

เมื่อย้าย Project จาก Path เดิมไป Path ใหม่ ต้อง

1. สำรองข้อมูล
2. ย้าย Project
3. ล้าง Build Cache
4. ทดสอบ Build และ Run
5. อัปเดต Path ใน Markdown
6. ตรวจ Git ว่าเป็นการย้าย ไม่ใช่ไฟล์หาย
7. ลบโครงสร้างเก่าหลังยืนยัน
8. Commit เป็น Milestone

---

# Final Principle

> One file, one responsibility, one correct location.

เอกสารนี้เป็นมาตรฐานกลางและใช้กับทุก Project ภายใต้ Laoo Solutions
