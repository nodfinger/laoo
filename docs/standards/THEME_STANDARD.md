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

พื้นที่แสดงข้อมูลหลักของระบบ เช่น Content, DataTable, List, Card, Form และ Dialog ต้องเป็นพื้นสีขาวเสมอทุก STYLE เพื่อให้อ่านข้อมูลได้ชัดเจน สีของ STYLE ให้ใช้กับ Sidebar, Menu, Selected State, Border และ Action ตาม Theme ส่วนตัวอักษรในพื้นที่ข้อมูลต้องเป็นสีเข้มที่อ่านชัด ยกเว้น Delete/Error ใช้สีแดง

## Implemented UI Baseline (2026-08-09)

- `STYLE01` เป็นค่าเริ่มต้นของ Workspace
- สีทั้งหมดของ Sidebar, Menu, Selected State, Card, Border, Button และ Pagination ต้องอ่านจาก Theme/Design Token กลาง
- ห้ามกำหนดสีเฉพาะ Role หรือ Module แบบ hard-coded
- การเปลี่ยน Theme ต้องมีผลกับ Support, Partner และ Company โดยคงโครงสร้างและ spacing เดียวกัน
- ทุก STYLE ต้องคง Content Workspace, DataTable, List, Card, Form และ Dialog เป็นสีขาวเหมือนกัน
- Dark STYLE เปลี่ยนได้เฉพาะ Navigation Chrome และ Accent ไม่เปลี่ยนพื้นหรือสีตัวอักษรของข้อมูลหลัก
