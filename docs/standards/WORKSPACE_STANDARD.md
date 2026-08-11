# WORKSPACE STANDARD

## Single Shared Shell Rule

- ผู้ใช้ทุกประเภท `LAOO_SUPPORT`, `PARTNER_USER` และ `COMPANY_USER` ต้องใช้ Workspace Shell ตัวเดียวกัน
- ห้ามสร้าง `Scaffold`, Top Bar, Sidebar, Theme Selector, Favorite หรือ User Menu แยกตาม Role
- Role และ Permission เปลี่ยนได้เฉพาะข้อมูลกลุ่มเมนู เมนูย่อย เส้นทาง และ Content
- ทุกหน้าหลัง Login ต้องคง Shell ไว้เมื่อเปลี่ยนเมนู
- หน้าจอ Add/Edit/View/Custom Action ต้องเปิดเต็มพื้นที่ Content Area ภายใน Shell เดิม ไม่เปิดเป็น Dialog สำหรับ Form หลักและไม่สร้าง Shell ซ้ำ

## Visual Baseline

- ใช้หน้าจอของ `LAOO_SUPPORT` เป็น UX/UI Baseline
- Default Theme คือ `STYLE01`
- Font ใช้ `LaooTypography`
- Sidebar กว้าง 220px บน Desktop และเปลี่ยนเป็น Drawer เมื่อความกว้างต่ำกว่า 900px
- Brand Header สูง 72px, Top Bar สูง 64px และ Menu Item สูง 30px
- Menu Group และ Submenu ต้องใช้ spacing, visual density และ selected state จาก Shared Shell เท่านั้น

## Permission Rule

- ไม่มีสิทธิ์ต้องไม่ render เมนู
- เข้า URL ตรงโดยไม่มีสิทธิ์ต้องถูก redirect กลับหน้าที่ได้รับอนุญาต
- Admin เห็นทุกเมนูภายในประเภท Login ของตัวเองโดยอัตโนมัติ
- Partner/Company menu ต้องมาจาก Permission API; config ชั่วคราวต้องแยกจาก Shell และถอดออกเมื่อ API พร้อม

## Acceptance

- ทดสอบบัญชี `t`, `p`, `c` ด้วย `STYLE01` และ Theme อื่นอย่างน้อยหนึ่งชุด
- ตรวจ Wide Desktop และความกว้างต่ำกว่า 900px
- Top Bar, Sidebar, Font, Spacing, Theme, Favorite และ User Menu ต้องเหมือนกันทั้งสาม Role

## Implemented Baseline (2026-08-09)

- `t` ใช้ `LAOO_SUPPORT`, `p` ใช้ `PARTNER_USER`, `c` ใช้ `COMPANY_USER` สำหรับการทดสอบปัจจุบัน
- ทุก Role ใช้ Shared Workspace Shell เดียวกัน; เปลี่ยนได้เฉพาะ menu scope, active route และ content
- Partner menu เริ่มต้น: จัดการบริษัท (ข้อมูลบริษัท/ข้อมูลสาขา) และจัดการผู้ใช้งาน (ผู้ใช้งานบริษัท)
- Company menu เริ่มต้น: ระบบสินค้า (ข้อมูลสินค้า) และระบบขาย (ข้อมูลลูกค้า)
- หน้า module ต้องคง Sidebar และ Top Bar ไว้ทุก route ไม่สร้าง Shell ซ้ำในแต่ละหน้า
- Route ของ CRUD Action Screen ต้องคง Sidebar, Top Bar, Theme และ User Context เดิม และเปลี่ยนเฉพาะ Content Area
- ชื่อผู้ใช้/ประเภทผู้ใช้/บริบท Partner หรือ Company ต้องแสดงจาก Auth Session จริง ห้าม hard-code ชื่อ Support

## Onboarding Workflow

`LAOO Support สร้าง Partner → Partner สร้าง Customer/Company → Company สร้าง Branch และ User → Company ใช้งาน Modules`

คำว่า Customer เป็นคำทางธุรกิจ ส่วน `Company` เป็น entity หลักในฐานข้อมูลและ API
