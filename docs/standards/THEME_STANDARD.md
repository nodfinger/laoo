# Theme Standard

Version: 1.0  
Updated: 2026-08-09

| Range | Group | Rule |
|---|---|---|
| STYLE01–10 | Hybrid Soft Dark | Sidebar dark/colored ได้; Workspace, Content และ Title Bar สีขาว |
| STYLE11–20 | Light/Colored | Style 11,14,16,17,18,19 ใช้ Submenu สีดำ |
| STYLE21–30 | Dark | ตัวอักษรเมนูสีขาว/อ่อน |
| STYLE31–40 | White Menu | Main menu ใช้สี Theme; Submenu สีดำ |

Default คือ `STYLE01` การสลับรหัส Group ไม่เปลี่ยนค่าสีของ Theme เดิม

พื้นขาวใช้ตัวอักษรดำหรือสีโทนที่อ่านชัด พื้น Dark ใช้ตัวอักษรขาวหรือสีอ่อน Card/Container ใช้เส้นกรอบตาม Theme และ Action สีตาม Theme ยกเว้น Delete เป็นสีแดง

## Implemented UI Baseline (2026-08-09)

- `STYLE01` เป็นค่าเริ่มต้นของ Workspace
- สีทั้งหมดของ Sidebar, Menu, Selected State, Card, Border, Button และ Pagination ต้องอ่านจาก Theme/Design Token กลาง
- ห้ามกำหนดสีเฉพาะ Role หรือ Module แบบ hard-coded
- การเปลี่ยน Theme ต้องมีผลกับ Support, Partner และ Company โดยคงโครงสร้างและ spacing เดียวกัน
