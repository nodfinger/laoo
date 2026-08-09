# บันทึกการประชุม Laoo Solutions

**วันที่:** 9 สิงหาคม 2026  
**หัวข้อ:** โครงสร้าง Project อิสระ มาตรฐานส่วนกลาง และบทบาทของ Laoo Plaza

## มติที่ประชุม

ทุก Project ภายใต้ Laoo Solutions ต้องแยกอิสระจากกันอย่างสมบูรณ์ ทั้งด้าน Application, API, Authentication, Database, ข้อมูลธุรกิจ, Configuration, Server, URL, Version และ Deployment

สิ่งเดียวที่ใช้ร่วมกันระหว่างทุก Project คือ **ข้อกำหนดและมาตรฐานส่วนกลางของ Laoo Solutions** ซึ่งใช้เป็นหลักในการออกแบบ สร้าง และพัฒนา Project แต่ไม่ใช่ระบบกลางที่ Project ต้องเชื่อมต่อขณะทำงานจริง

## แนวทางสร้าง Project ใหม่

เมื่อเริ่ม Project ใหม่ หม่อนจะดำเนินการดังนี้:

1. อ่านและตรวจสอบข้อกำหนดส่วนกลางที่เกี่ยวข้อง
2. ใช้วิธีคัดลอกหรือนำ Project Starter Template ส่วนกลางมาสร้าง Project ใหม่ทันที
3. สร้าง Application, API, Authentication และ Database ให้เป็นของ Project นั้นเอง
4. กำหนดชื่อระบบ, ProjectCode, URL, Database และ Configuration ของ Project ใหม่
5. นำมาตรฐานกลาง เช่น Font, Theme, Layout, Permission และ Flow เพิ่ม–แก้ไข–ลบ ไปใช้ในโค้ดของ Project
6. พัฒนาฟังก์ชันธุรกิจเฉพาะ โดยไม่สร้างการพึ่งพา Project อื่น

## บทบาทของ Laoo Plaza

**Laoo Plaza** เป็นทั้ง:

- Project ใช้งานจริงประเภท Community Commerce Platform
- Project ต้นแบบสำหรับพิสูจน์และพัฒนาข้อกำหนดส่วนกลาง
- แหล่งต้นแบบสำหรับสร้าง Starter Template ของ Project ใหม่ในอนาคต

ระหว่างการพัฒนา Laoo Plaza ทีมจะทำงานสองด้านควบคู่กัน:

1. พัฒนาฟังก์ชันของ Laoo Plaza ให้ใช้งานจริงได้
2. ทบทวน เติมเต็ม และพิสูจน์มาตรฐานส่วนกลางจากการใช้งานจริง

เมื่อพบรูปแบบที่ควรใช้ร่วมกันทุก Project เช่น Font, Theme, Workspace, List/Table, Validation, Permission, Notification หรือ Flow เพิ่ม–แก้ไข–ลบ ให้สรุปเป็นข้อเสนอปรับมาตรฐานส่วนกลางก่อน แล้วจึงนำไปเป็นต้นแบบสำหรับ Project ถัดไป

## ขอบเขตของมาตรฐานส่วนกลาง

มาตรฐานส่วนกลางควรครอบคลุมอย่างน้อย:

- Project Structure และ Naming
- Font และ Typography
- Theme, Color และ Design Tokens
- Workspace, Navigation และ Responsive Layout
- List, Search, Filter, Sort และ Pagination
- Flow เพิ่ม แก้ไข ลบ และยกเลิก
- Required Field, Validation และ Error Handling
- Success/Error Notification
- Authentication, User และ Permission Pattern
- API, Database Naming, Audit และ Security
- Configuration, Version และ Deployment Baseline

## กติกาการควบคุมมาตรฐาน

- ทุก Project ต้องอ่านและปฏิบัติตามมาตรฐานส่วนกลางในช่วงออกแบบและพัฒนา
- Project ต้องไม่เชื่อมต่อหรืออ่านไฟล์มาตรฐานส่วนกลางใน Runtime
- แต่ละ Project ต้องมีโค้ดและค่าที่จำเป็นอยู่ภายในตัวเอง เพื่อให้ติดตั้งแยกได้
- ห้ามแก้ไขมาตรฐานส่วนกลางโดยอัตโนมัติจากการแก้เฉพาะ Project
- หาก Laoo Plaza พบความต้องการใหม่ ให้เสนอและพิจารณาก่อนว่าเป็นมาตรฐานกลางหรือเป็น Requirement เฉพาะ Project
- การแก้ข้อกำหนดส่วนกลางต้องได้รับการอนุมัติจากพ่อก่อน

## ข้อสรุปหลัก

> **Shared Standards, Fully Independent Projects**  
> ทุก Project แยกอิสระอย่างสมบูรณ์ และใช้มาตรฐานส่วนกลางร่วมกันเฉพาะในกระบวนการออกแบบและพัฒนา

> **Laoo Plaza คือ Reference Project**  
> ใช้พัฒนาและพิสูจน์ทั้งระบบ Laoo Plaza และมาตรฐานส่วนกลาง ก่อนนำมาตรฐานกับต้นแบบที่สมบูรณ์แล้วไปสร้าง Project ใหม่

## มติเพิ่มเติม: Partner, Customer และ Module

- ภายใน Laoo Plaza ไม่มี Project Master ส่วนกลาง เพราะ Application, API, Authentication และ Database เป็นของ Laoo Plaza เอง
- โครงสร้างธุรกิจคือ `Laoo → Partner → Customer/Company → Branch → User`
- Partner User แยกจาก Laoo Support User และ Company User และทำงานได้เฉพาะภายใต้ Partner ของตน
- Laoo Support สร้าง Customer โดย Login ด้วยบัญชี Laoo ของตนเอง ไม่ Login แทน Partner
- ทางเข้าหลักคือ `ข้อมูล Partner → ลูกค้าของ Partner → เพิ่มลูกค้า` ระบบผูก Partner ให้อัตโนมัติ
- หากเพิ่มจากหน้ารวม Customer ผู้ใช้ Laoo Support ต้องเลือก Partner ก่อนบันทึก
- Partner User ไม่มีช่องเลือก Partner; API ใช้ Partner จาก Login Context เท่านั้น
- Laoo Support และ Partner User ที่มี Permission สามารถเปิด–ปิด Module ให้ Customer ในขอบเขตของตนได้
- Laoo มีสิทธิ์ Lock Module เพื่อไม่ให้ Partner เปิดกลับหรือเปลี่ยนสถานะจนกว่า Laoo จะปลด Lock
- Company Admin และ Company User ไม่มีสิทธิ์เปิด–ปิด Module
- การใช้งานจริงต้องผ่านทั้งสถานะ Customer, สถานะ Module, Laoo Lock, User Active, Permission, Data Scope และ Record Ownership
- ปิด Module แล้วไม่ลบ Role/Permission เดิม และทุกการเปลี่ยนสถานะต้องเก็บ Audit Log

## มติการออกแบบฐานข้อมูลและ Data Dictionary

- หม่อน/Coding Expert สามารถตั้งชื่อ Table และ Field ได้เองโดยไม่ต้องรออนุมัติชื่อทีละรายการ
- ชื่อ Table ต้องใช้ `TD + ModuleCode + ความหมายของ Table` เขียนแบบ PascalCase และไม่มี underscore
- ทุกงานสร้างหรือแก้โครงสร้างฐานข้อมูลต้องส่งเป็นชุดเดียวกัน ได้แก่ SQL, Excel Data Dictionary และ PDF Data Dictionary
- Data Dictionary ต้องมีคำอธิบายหน้าที่แบบย่อของทุก Table และทุก Field
- Excel และ PDF ต้องใช้ข้อมูล Schema ชุดเดียวกัน เพื่อให้ชื่อ ชนิดข้อมูล Key, Null, Default และคำอธิบายตรงกัน
- SQL ของ Laoo Plaza ต้องเริ่มด้วย `USE [DBTDLaoo]` และ `GO`
