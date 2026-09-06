# LAOO Platform

LAOO Platform รวมข้อมูลส่วนกลางและระบบธุรกิจหลายระบบไว้ในพื้นที่ทำงานเดียว โดยลูกค้าแต่ละรายเปิดใช้ระบบได้ไม่เท่ากัน

## Language

**Project**:
ระบบระดับบนสุดที่แบ่งขอบเขตผลิตภัณฑ์ใน Platform เช่น ข้อมูลส่วนกลาง ระบบห้องประชุม และระบบแจ้งซ่อม
_Avoid_: Module, Feature, กลุ่มเมนู

**Core Project**:
Project ข้อมูลส่วนกลางที่ทุก Company ใช้ร่วมกันและไม่ถือเป็นระบบธุรกิจที่ Partner จำหน่ายแยก
_Avoid_: Shared Menu, Common Screen

**Business Project**:
Project ระบบธุรกิจที่ Partner สามารถเปิดหรือปิดให้แต่ละ Company ได้
_Avoid_: Core Project, Feature

**Menu Group**:
หมวดเมนูภายใน Project ซึ่งรวมหน้าจอที่เกี่ยวข้องและยุบหรือขยายได้
_Avoid_: Project, System

**Main Menu**:
หน้าจอปลายทางภายใน Menu Group ซึ่งมี MenuCode และ Permission ของตนเอง
_Avoid_: Menu Group, Project

**Company Project Entitlement**:
สิทธิ์ระดับ Company ที่ระบุว่า Partner เปิด Business Project ใดให้ลูกค้าใช้งาน
_Avoid_: User Permission, Menu Permission

**User Project Access**:
สิทธิ์ระดับ User ที่ระบุว่าผู้ใช้เข้า Project ใดได้ ภายใต้ Project ที่ Company ได้รับสิทธิ์แล้ว
_Avoid_: Company Project Entitlement

**Canonical Workspace**:
Git repository `laoo` ที่เป็นแหล่งโค้ดจริงเพียงแห่งเดียวของ LAOO Core, Business Project และ Shared Package
_Avoid_: สำเนา Project ภายนอก, Shared Folder

**Project Application**:
แอป Flutter ของ Business Project ที่อยู่ใต้ `projects/<project>` ภายใน Canonical Workspace
_Avoid_: Repository แยก, สำเนา Core

**Legacy Project Copy**:
โฟลเดอร์หรือ repository เดิมที่เก็บไว้เพื่อกู้คืนหรือเทียบประวัติเท่านั้น และห้ามใช้พัฒนา Feature ใหม่
_Avoid_: Active Project, Source of Truth
