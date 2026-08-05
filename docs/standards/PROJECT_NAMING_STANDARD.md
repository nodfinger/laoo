# PROJECT_NAMING_STANDARD

Version: 1.0

Last Update: 2026-08-05

Owner: CA / CI

------------------------------------------------------------------------

# Purpose

กำหนดมาตรฐานการตั้งชื่อของทุก Project ภายใต้ Laoo Solutions เพื่อให้มีรูปแบบเดียวกัน
สามารถใช้งานร่วมกับ Flutter, Git, Android, iOS และเครื่องมือ AI (ChatGPT,
Codex, Gemini, Claude เป็นต้น) ได้อย่างถูกต้อง

------------------------------------------------------------------------

# Naming Convention

## Flutter Project / Package

ใช้รูปแบบ **snake_case**

ตัวอย่าง

``` text
laoo
laoo_meeting
laoo_market
laoo_pos
laoo_hr
laoo_stock
laoo_crm
laoo_erp
```

ห้ามใช้

``` text
laoo-meeting
LaooMeeting
Laoo_Meeting
```

------------------------------------------------------------------------

## Project Folder

ใช้ชื่อเดียวกับ Flutter Project

``` text
C:\laoo\projects\laoo
C:\laoo\projects\laoo_meeting
C:\laoo\projects\laoo_market
```

------------------------------------------------------------------------

## Display Name

ใช้ Title Case

``` text
Laoo
Laoo Meeting
Laoo Market
Laoo POS
Laoo HR
```

------------------------------------------------------------------------

## Android Package

``` text
com.laoo.meeting
com.laoo.market
com.laoo.pos
```

------------------------------------------------------------------------

## iOS Bundle Identifier

ใช้รูปแบบเดียวกับ Android

``` text
com.laoo.meeting
com.laoo.market
com.laoo.pos
```

------------------------------------------------------------------------

## Documentation

มาตรฐานกลางเก็บไว้ที่

``` text
C:\laoo\docs
```

Project ทุกตัวต้องอ้างอิงจากตำแหน่งนี้

ห้ามคัดลอกไฟล์มาตรฐานไปไว้ในแต่ละ Project

------------------------------------------------------------------------

## Project Structure

``` text
C:\laoo
│
├── docs
│
└── projects
    ├── laoo
    ├── laoo_meeting
    ├── laoo_market
    ├── laoo_pos
    ├── laoo_hr
    └── ...
```

------------------------------------------------------------------------

## Project Files

แต่ละ Project สามารถมีไฟล์

``` text
project.md
README.md
AGENTS.md
```

------------------------------------------------------------------------

## AI Compatibility

มาตรฐานนี้สามารถใช้ร่วมกับ

-   ChatGPT
-   Codex
-   Gemini
-   Claude
-   AI Coding Assistant อื่น ๆ

------------------------------------------------------------------------

# Summary

  Item              Standard
  ----------------- ------------------------------
  Flutter Project   snake_case
  Flutter Package   snake_case
  Project Folder    snake_case
  Display Name      Title Case
  Android Package   com.laoo.projectname
  iOS Bundle        com.laoo.projectname
  Documentation     C:`\laoo`{=tex}`\docs`{=tex}
