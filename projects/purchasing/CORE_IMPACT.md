# Purchasing Core Impact (69002)

โมดูลจัดซื้อถูกเตรียมแยกไว้ใน `projects/purchasing/**` แล้ว แต่ยังไม่เปิดใช้งานผ่านระบบกลางจนกว่า Core จะลงทะเบียนรายการต่อไปนี้เป็นชุดเดียว:

- MenuCode `69002` ชื่อเมนูคำขอจัดซื้อ และ `ScreenType = 4`
- Route name/path ตาม Core Contract: `mySystemPurchaseScRequest`, `/company/my-system/purchase-sc-request`
- Permission actions `VIEW`, `CREATE`, `EDIT`, `DELETE`, `UPLOAD`
- Project registration และ Company menu activation
- Root Flutter package/route/feature-host wiring
- Root API project reference และ MVC ApplicationPart ของ `Laoo.Purchasing.Module`

ห้ามแก้ `AGENTS.md`, Root Router, Shared UI, Permission กลาง หรือ Core Database จากฝั่งโมดูลนี้โดยอัตโนมัติ

## ลิงก์อ้างอิงต่อรายการ (69002)

- Project เพิ่ม ReferenceUrl1–ReferenceUrl3 ใน dbo.TDAPPurchaseRequestDetail ผ่าน migration ของ purchasing โดยคอลัมน์ใหม่ยอมให้ว่างและรักษาข้อมูลเดิม
- API ของ Project รองรับสร้าง อ่าน และแก้ไขแบบร่าง พร้อมตรวจสิทธิ์และรักษารายการและไฟล์แนบเดิม Core ควรตรวจ contract และ migration เมื่อรับ PR

## ตัวแสดงวันที่ของบริษัท

- `my-ui` กำหนดให้ใช้ `CompanyDateFormatter` แต่ตัว formatter อยู่ใต้ Root `lib/core/company_setup/` และไม่ได้เปิดผ่าน Project host หรือ shared package
- ขอ Core เปิด read contract สำหรับรูปแบบวันที่ให้ Project ใช้ร่วมกัน ปัจจุบันหน้าจัดซื้ออ่าน `yearFormat` จาก runtime และแสดง `dd/MM/yyyy` ตามค่าบริษัทโดยคงค่า ISO สำหรับ API ระหว่างรอ contract กลาง

## การตั้งค่าคอลัมน์ 69002

- Core ต้องเพิ่มเมนู 69002 และทะเบียนคอลัมน์ที่อนุญาตใน laoo_api/Controllers/UserListDisplayController.cs และหน้าตั้งค่าผู้ใช้ เพื่อเชื่อมการแสดงและจัดเรียงคอลัมน์ของ Project รวม divisionName, departmentName และ requesterName โดยรักษาค่าตั้งเดิมของผู้ใช้
- หลัง Core เปิด contract แล้ว Project ต้องเชื่อมการอ่านค่าจริงทั้ง List และ Card ปัจจุบันแสดงคอลัมน์ตามค่าเริ่มต้น

## การแนบไฟล์ 69002

- ตามคำสั่งผู้ใช้ การแนบไฟล์ในแบบร่างใช้สิทธิ์ CREATE สำหรับใบที่ผู้ใช้สร้างเอง หรือ EDIT ภายในขอบเขตข้อมูล โดยไม่ต้องมี UPLOAD แยก; API ยังคงตรวจบริษัทและสถานะ ให้ Core ทราบเมื่อทบทวน contract
