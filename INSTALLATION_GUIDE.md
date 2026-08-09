# Installation Guide

ชุดนี้ใช้แทน `C:\laoo\docs` เดิม

## ขั้นตอนที่ปลอดภัย

1. ปิดโปรแกรมที่กำลังแก้ไฟล์ใน `C:\laoo\docs`
2. สำรองโฟลเดอร์เดิม เช่น `C:\laoo\archive\docs_before_baseline_2026-08-09`
3. ตรวจว่า Backup เปิดอ่านได้
4. นำโฟลเดอร์ `docs` จากชุดนี้ไปวางเป็น `C:\laoo\docs`
5. เปิด `C:\laoo\docs\DOCUMENTATION_GUIDE.md`
6. Commit เอกสารเป็น Checkpoint แยกจาก Code

อย่าลบตารางฐานข้อมูลหรือ Code ที่ยังอ้าง Project model เพียงเพราะเอกสารถูกยกเลิก ต้องตรวจ Dependency และทำ Migration/Backup/Rollback plan ก่อน

