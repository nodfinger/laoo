# CRUD_FLOW_STANDARD

**Document Type:** Central Standard  
**Scope:** All Laoo Solutions systems and projects  
**Status:** Approved Baseline  
**Standard Path:** `C:\laoo\docs\standards\CRUD_FLOW_STANDARD.md`

---

## 1. Purpose

เอกสารนี้กำหนดมาตรฐาน CRUD (Create, Read, Update, Delete) กลางของ Laoo Solutions
สำหรับหน้าจอประเภท Master Data, Setup Data และข้อมูลรายการที่ใช้รูปแบบ List/Form

เป้าหมายคือให้ทุก Module ใช้ Flow เดียวกัน ผู้ใช้สามารถคาดเดาพฤติกรรมของระบบได้
และ Frontend / API / Database ทำงานสอดคล้องกัน

---

## 2. CRUD Definition

- **Create** = เพิ่มข้อมูลใหม่
- **Read** = แสดงรายการ / ค้นหา / เปิดดูข้อมูล
- **Update** = แก้ไขข้อมูลเดิม
- **Delete** = ลบข้อมูล โดยต้องตรวจ Permission และ Referential Integrity ก่อนเสมอ

CRUD UI ต้องไม่ทำ Business Rule เองแทน API  
API/Backend เป็นผู้ตัดสินสิทธิ์และความถูกต้องของข้อมูลขั้นสุดท้าย

---

## 3. Standard Master Data Flow

### 3.1 Create

`List → + เพิ่ม → Add Form → Validate → Save → Success → Clear Form → Add Form`

หลังบันทึกสำเร็จ:

1. แสดง Success Message ด้านบน Content Area
2. ใช้ข้อความรูปแบบ `เพิ่มข้อมูล {ชื่อหน้าจอ} สำเร็จ`
3. ล้างค่าฟอร์ม
4. อยู่หน้า Add Form เดิม เพื่อให้เพิ่มรายการถัดไปได้ทันที
5. ห้ามกลับ List อัตโนมัติสำหรับ Master Data Standard

ตัวอย่าง:

`Partner List → + เพิ่ม → Partner > เพิ่ม → บันทึก → เพิ่มข้อมูล Partner สำเร็จ → ล้างฟอร์ม`

### 3.2 Read

`Open List → Load → Search / Filter / Sort / Pagination`

กฎ:

- ต้องมี Loading State
- Empty State ต้องแยก `ยังไม่มีข้อมูล` กับ `ไม่พบข้อมูลตามเงื่อนไข`
- Search/Filter ต้องไม่แก้ข้อมูล
- Sort ต้องไม่เปลี่ยน Business Data
- Pagination ใช้ RowSTD จาก Setup กลางเมื่อระบบกำหนดไว้
- Table/List ต้อง Refresh หลัง Action ที่เปลี่ยนข้อมูลสำเร็จ

### 3.3 Update

`List → Edit → Edit Form → Save → Success → List → Refresh`

หลังแก้ไขสำเร็จ:

1. กลับ List
2. Refresh ข้อมูลล่าสุด
3. แสดงข้อความ `แก้ไขข้อมูล {ชื่อหน้าจอ} สำเร็จ`

ถ้า Save ไม่สำเร็จ:

- อยู่หน้า Edit เดิม
- เก็บค่าที่ผู้ใช้กรอก
- แสดง Error
- เปิดให้แก้ไขและ Save ใหม่

### 3.4 Delete

`List → Delete → Confirm → DELETE API → Result`

ถ้าสำเร็จ:

`Delete Success → Close Dialog → Refresh List → Success Message`

ข้อความแนะนำ:

`ลบ {ชื่อหน้าจอ} สำเร็จ`

ถ้าไม่สำเร็จ:

`Delete Failed → Keep Record → Show Reason`

ห้ามนำรายการออกจาก List ก่อน API ยืนยันว่าลบสำเร็จ

---

## 4. List Action Column Standard

หน้าจอ List/Table ที่รองรับ CRUD ต้องมี **Action Column อยู่ซ้ายสุด**

### 4.1 Header

- Caption = `Action`
- Header ของ Action Column ต้องจัดกึ่งกลาง
- Action Column ไม่ใช้ Sort

### 4.2 Direct CRUD Icons

Action ที่ใช้บ่อยและเข้าใจได้ทันทีให้แสดงเป็น Icon โดยตรง:

- **Edit** = รูปดินสอ
- **Delete** = รูปถังขยะสีแดง

กฎ:

- Edit ใช้สี Primary ของ Theme
- Delete ใช้ Semantic Danger Color = สีแดง
- ทุก Icon ต้องมี Tooltip
- Edit/Delete ไม่ควรถูกซ่อนไว้ในเมนู `...` หากมีพื้นที่เพียงพอ
- Action icon ของแต่ละแถวควรจัดกึ่งกลางใน Action Column

### 4.3 More Menu

เมนู `...` ใช้สำหรับ Action รองที่ไม่ใช่ CRUD หลัก เช่น:

- เปลี่ยนสถานะ
- Duplicate
- Export เฉพาะรายการ
- Action ธุรกิจเฉพาะ Feature

ห้ามใส่ Edit/Delete ซ้ำใน More Menu เมื่อมีปุ่มตรงใน Action Column แล้ว

---

## 5. Delete Confirmation Standard

Delete เป็น Destructive Action ต้องมี Confirmation ก่อนส่ง DELETE Request

Confirmation ต้องแสดง:

- หัวข้อ เช่น `ยืนยันการลบ Partner`
- รหัสหรือ Key ของข้อมูล เมื่อมี
- ชื่อข้อมูลที่กำลังลบ
- ข้อความเตือนว่าการลบไม่สามารถย้อนกลับจากหน้าจอได้
- ปุ่ม `ยกเลิก`
- ปุ่ม `ลบ` สีแดง

### 5.1 Visual Standard

Confirmation Dialog ควร:

- มีขนาดกระชับ
- ใช้ Font Size เล็กกว่าหน้าฟอร์มเล็กน้อย แต่ยังอ่านง่าย
- ใช้พื้น Surface ของ Theme
- ใช้กรอบ/Accent สีแดงอ่อนสำหรับ Danger Context
- หัวข้อและ Delete Icon ใช้สีแดง
- ข้อมูล Key/Code สามารถใช้ Primary Color เพื่ออ่านง่าย
- ปุ่ม `ลบ` ใช้พื้นสีแดงและตัวอักษรสีขาว
- Default Focus ไม่ควรอยู่ที่ปุ่มลบ

---

## 6. Delete API Standard

Endpoint มาตรฐาน:

`DELETE /api/{module}/{resource}/{id}`

ตัวอย่าง:

`DELETE /api/support/partners/{partnerId}`

API ต้อง:

1. ตรวจ Authentication
2. ตรวจ Scope
3. ตรวจ Permission
4. ตรวจ Business Rule
5. ตรวจ Referential Integrity
6. ลบข้อมูล
7. ตอบ HTTP Status ที่เหมาะสม

---

## 7. Referential Integrity Standard

**ห้ามปลด Foreign Key หรือเปิด Cascade Delete แบบเหมารวมเพื่อให้ลบผ่าน**

ก่อนลบข้อมูลที่อาจถูกใช้งาน ระบบต้องตรวจความสัมพันธ์ก่อน

ตัวอย่าง Partner:

- `TDADCompany.PartnerID`
- `TDSTCompanySetUp.PartnerID`
- ตารางอื่นที่มี Foreign Key ไปยัง Partner

ถ้าข้อมูลถูกอ้างอิง:

- API ต้องไม่ลบ Parent Record
- คืน `409 Conflict`
- Frontend ต้องคงรายการไว้
- แสดงข้อความที่ผู้ใช้เข้าใจได้

ตัวอย่าง:

`ไม่สามารถลบ Partner ได้ เนื่องจากข้อมูลถูกใช้งานอยู่`

หากสามารถระบุจำนวนข้อมูลที่อ้างอิงได้ ควรแสดง เช่น:

`ไม่สามารถลบ Partner ได้ เนื่องจากมี Company ใช้งานอยู่ 3 รายการ`

---

## 8. HTTP Result Standard

### 200 / 204

Action สำเร็จ

สำหรับ DELETE แนะนำ `204 No Content`

### 400

ข้อมูล Request ไม่ถูกต้อง

### 401

ไม่ได้ Login / Token ไม่ถูกต้อง

### 403

ไม่มี Permission

### 404

ไม่พบข้อมูล

### 409

ข้อมูลขัดกับ Business Rule หรือ Referential Integrity

### 500

Unexpected Server Error

Technical Error / SQL Exception / Stack Trace ห้ามแสดงตรงต่อ End User

---

## 9. Permission Standard

Frontend:

- ถ้าไม่มีสิทธิ์ ให้ซ่อน Action
- ไม่ใช้ Disabled เป็นค่าเริ่มต้นเพื่อแทนการไม่มีสิทธิ์

Backend:

- ต้องตรวจ Permission ซ้ำทุก Action
- ห้ามเชื่อ Permission จาก Flutter
- Direct API Call ต้องข้าม Permission ไม่ได้

Permission ที่ควรรองรับ:

- VIEW
- CREATE
- EDIT
- DELETE
- CHANGE_STATUS

ระหว่าง Development อาจใช้ Permission เดิมชั่วคราวได้เฉพาะเมื่อทีมอนุมัติ
แต่ Production Standard ต้องแยก DELETE Permission ให้ชัดเจน

---

## 10. Status Change vs Delete

**Change Status ไม่ใช่ Delete**

Change Status ใช้เมื่อข้อมูลยังต้องอยู่ในระบบ แต่ต้องการเปิด/ระงับการใช้งาน

Flow:

`List → Change Status → API → Success → Refresh`

Delete ใช้เมื่อข้อมูลต้องถูกนำออกจากฐานข้อมูลจริง และผ่าน Referential Integrity แล้ว

ห้ามใช้ Delete แทน Inactive โดยไม่มี Business Requirement รองรับ

---

## 11. Action Result Notification

Success Message แสดงด้านบน Content Area โดยไม่ใช้ Popup OK ทั่วไป

มาตรฐานข้อความ:

- Create: `เพิ่มข้อมูล {ชื่อหน้าจอ} สำเร็จ`
- Edit: `แก้ไขข้อมูล {ชื่อหน้าจอ} สำเร็จ`
- Delete: `ลบ {ชื่อหน้าจอ} สำเร็จ`
- Status: `แก้ไขสถานะ {ชื่อหน้าจอ} สำเร็จ`

Error:

- อยู่หน้าปัจจุบัน
- ไม่ล้างข้อมูลที่ผู้ใช้กรอกโดยไม่จำเป็น
- แสดงเหตุผลที่แก้ไขได้
- Error สำคัญไม่ควรหายก่อนผู้ใช้รับรู้

---

## 12. Loading and Double Action Protection

ทุก Request ที่เปลี่ยนข้อมูลต้องป้องกันการกดซ้ำ

Create/Update/Delete ต้อง:

- Disable/lock Action ชั่วคราวระหว่าง Request
- แสดง Loading ที่เหมาะสม
- ห้ามยิง Request ซ้ำจากการ Double Click
- รอ Server Result ก่อนปรับ UI เป็นสถานะสำเร็จ

---

## 13. Responsive CRUD Standard

Desktop/Web:

- ใช้ Table เมื่อเหมาะสม
- Action Column อยู่ซ้าย
- Edit/Delete แสดงเป็น Icon โดยตรง

Mobile:

- สามารถเปลี่ยน Table เป็น Card/List
- ต้องยังเข้าถึง Edit/Delete ได้โดยตรง
- ความหมาย Icon และ Semantic Color ต้องเหมือน Desktop

Business Flow ต้องเหมือนกันทุก Platform

---

## 14. Partner Reference Implementation

Partner เป็น Reference Implementation แรกของ CRUD Standard นี้

Flow ที่อนุมัติ:

### Create
`Partner List → เพิ่ม → Add Form → Save → Success → Clear Form`

### Edit
`Partner List → Pencil Icon → Edit Form → Save → Partner List → Refresh`

### Delete
`Partner List → Red Trash Icon → Confirm → DELETE API`

ผลลัพธ์:

- ไม่มีข้อมูลอ้างอิง → Delete → Refresh → `ลบ Partner สำเร็จ`
- มีข้อมูลอ้างอิง → HTTP 409 → ไม่ลบ → แสดงเหตุผล

Action Column:

`[ Edit Pencil ] [ Red Delete Trash ]`

More Menu:

- ไม่ใส่ Edit
- ไม่ใส่ Delete
- ใช้เฉพาะ Action รอง เช่น Change Status เมื่อ Feature ต้องการ

---

## 15. Source-First Development Rule

เมื่อ Implement CRUD:

- ต้องอ่าน Source Code ล่าสุดก่อนแก้
- ห้ามเดา Method / Class / Endpoint / File Structure
- ถ้า Script หา Marker/Pattern ไม่เจอ ให้หยุด
- ขอ Source จริงจากเจ้าของ Project ก่อนดำเนินการต่อ
- การแก้หลาย Layer ต้องตรวจไฟล์ที่เกี่ยวข้องให้ครบ เช่น:
  - UI
  - Repository
  - API Client
  - HTTP Service
  - Controller
  - Database Relationship

หลักการ:

**Source First — No Guessing**

---

## 16. Standard Governance

เอกสารนี้เป็น Central Standard ของ Laoo Solutions

Feature ใหม่ที่ใช้ CRUD ต้องตรวจเอกสารนี้ก่อน Coding

หาก Feature ต้องใช้ Flow ต่างจากมาตรฐาน:

1. ระบุเหตุผล
2. บันทึกใน Feature Specification
3. ขออนุมัติก่อนเปลี่ยน UX/Business Flow
4. หาก Pattern ใหม่ใช้ได้หลาย Feature ให้พิจารณายกระดับเป็น Central Standard

---

**Laoo Solutions**  
*Simple Today. Ready Tomorrow.*
