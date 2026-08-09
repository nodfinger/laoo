# Authentication Structure

Version: 1.0  
Updated: 2026-08-09

## Login UX

หน้า Login มีเฉพาะ Username, Password, ลืมรหัสผ่าน, เข้าสู่ระบบ และกลับไปหน้าแรก ไม่ให้ผู้ใช้เลือก Partner, Company, Branch หรือ Project ตอน Login

## User Types

| User type | Scope |
|---|---|
| Laoo Support | ตาม Permission ของ Laoo; จัดการได้หลาย Partner/Customer |
| Partner User | Partner เดียว; Customer ภายใต้ Partner นั้นเท่านั้น |
| Company User | Company/Branch ที่ได้รับมอบหมายเท่านั้น |

Username ต้องไม่ซ้ำทั้งฐานข้อมูลที่ใช้งานอยู่ และใช้ Normalized Username ในการเปรียบเทียบ

## Login Flow

1. API Normalize Username และตรวจ User ที่ Active
2. ตรวจ Password ตาม Password Policy
3. ระบุ User Type จาก Server-side data
4. สร้าง Session/JWT ที่มีตัวระบุผู้ใช้และ Context ที่จำเป็น
5. Flutter เรียก Post-login Context
6. API คืน Scope, Module, Permission และ UI Context ที่ตรวจแล้ว

## Support Access

ใช้ Login As User ตาม Permission ไม่ใช้ Master Password ต้องระบุเหตุผล แสดง Support banner เก็บ Actual User และ Target User และสร้าง Audit Log ทุกครั้ง

## Partner User

- Partner User สังกัด Partner เดียว
- API ใช้ Partner จาก Login Context และห้ามเชื่อ Partner ที่ Client ส่งมาเพื่อขยาย Scope
- Partner User จัดการ Customer หรือ Module ได้เมื่อมี Permission และ Customer อยู่ใต้ Partner ของตน

## Company User

- เข้าถึงเฉพาะ Company/Branch ที่ได้รับมอบหมาย
- ไม่มีสิทธิ์เปิดหรือปิด Company Module

## Security

- เก็บเฉพาะ Password Hash ยกเว้น Password Direct ที่เป็นนโยบายเฉพาะและต้องป้องกัน/ตรวจสอบตาม Security Review
- API ตรวจ User active, Customer active, Module effective, Permission, Data Scope และ Record Ownership ทุก Request
- การซ่อน UI ไม่ทดแทน Authorization ฝั่ง API
- Login, Logout, Login As, Module state, Laoo lock และ Permission change ต้องมี Log/Audit ตามประเภท

