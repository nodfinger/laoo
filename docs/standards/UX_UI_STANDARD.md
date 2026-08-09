# LAOO SOLUTIONS --- UX/UI STANDARD

**Document Type:** Central Standard\
**Scope:** All Laoo Solutions systems and projects\
**Version:** 1.0\
**Status:** Approved Baseline (Merged)\
**Standard Path:** `C:\laoo\docs\standards\UX_UI_STANDARD.md`

------------------------------------------------------------------------

## 1. Purpose

เอกสารนี้กำหนดมาตรฐาน UX/UI กลางสำหรับทุกระบบของ Laoo Solutions เพื่อให้ทุก
Project และทุก Feature มีพฤติกรรมที่สอดคล้องกัน
ผู้ใช้สามารถคาดเดาได้ว่าปุ่มแต่ละชนิดทำอะไร กดแล้วไปที่ใด บันทึกสำเร็จแล้วเกิดอะไรขึ้น
และเมื่อเกิดข้อผิดพลาดระบบต้องตอบสนองอย่างไร

มาตรฐานนี้ใช้กับทุกระบบ เช่น `laoo`, `laoo_meeting` และ Project/Solution
ที่พัฒนาเพิ่มในอนาคต เว้นแต่มีข้อกำหนดเฉพาะของ Project ที่ได้รับอนุมัติอย่างชัดเจน

------------------------------------------------------------------------

## 2. Core UX Principles

1.  **Simple First** --- แสดงเฉพาะข้อมูลและคำสั่งที่จำเป็นกับงานปัจจุบัน
2.  **Predictable** --- ปุ่มและ Flow เดียวกันต้องทำงานเหมือนกันทุกระบบ
3.  **Safe by Default** --- งานที่มีผลต่อข้อมูลต้องป้องกันการกดซ้ำ การสูญหาย
    และการลบโดยไม่ตั้งใจ
4.  **Responsive** --- รองรับ Web, Windows, Tablet และ Mobile
5.  **Permission Aware** --- สิ่งที่ผู้ใช้ไม่มีสิทธิ์ต้องซ่อนเป็นค่าเริ่มต้น
6.  **Reusable** --- ใช้ Theme, Component และ Shared Widget กลาง
    หลีกเลี่ยงการสร้าง Style ซ้ำในแต่ละ Feature
7.  **Clear Feedback** --- ทุก Action ต้องมีผลตอบกลับที่ผู้ใช้เข้าใจได้

------------------------------------------------------------------------

## 3. Standard Screen Structure

หน้าจอจัดการข้อมูลมาตรฐานแบ่งเป็น:

-   Page Header
    -   ชื่อหน้าจอ
    -   คำอธิบายสั้นเมื่อจำเป็น
    -   Primary Action เช่น `+ เพิ่ม`
-   Search / Filter Area เมื่อจำเป็น
-   Main Content
    -   Table / List / Card / Form ตามประเภทงาน
-   Action Area
    -   ปุ่มหลักและปุ่มรองตามมาตรฐานนี้
-   Feedback Area
    -   Loading / Empty / Error / Success

บน Mobile สามารถปรับตำแหน่งองค์ประกอบตามพื้นที่ แต่ความหมายและ Flow ต้องเหมือน
Desktop/Web

------------------------------------------------------------------------

## 4. List / Management Screen Standard

หน้าจอรายการข้อมูล เช่น Partner, Company, Branch, User หรือข้อมูล Master อื่น
ใช้แนวทางเดียวกัน

### 4.1 Standard Actions

  Action         Label แนะนำ                   ผลลัพธ์
  -------------- ----------------------------- -------------------------------
  Create         `+ เพิ่ม` หรือ `+ เพิ่ม{ชื่อข้อมูล}`   เปิดหน้า/ฟอร์มสร้างรายการใหม่
  View           `ดู`                           เปิดรายละเอียดแบบอ่านข้อมูล
  Edit           `แก้ไข`                        เปิดฟอร์มแก้ไขรายการที่เลือก
  Delete         `ลบ`                          เปิด Confirmation ก่อนลบ
  Search         `ค้นหา`                        กรองรายการโดยไม่เปลี่ยนหน้าหลัก
  Clear Filter   `ล้าง`                         คืนค่าการค้นหา/Filter เป็นค่าเริ่มต้น
  Refresh        `รีเฟรช`                       โหลดข้อมูลใหม่โดยอยู่หน้าเดิม

### 4.2 เมื่อกด "เพิ่ม"

Default Flow:

`List → Add Form`

กฎ: - เปิดฟอร์มใหม่ที่ไม่มีข้อมูลเดิม - Focus ช่องแรกที่เหมาะสมเมื่อ Platform รองรับ -
ปุ่มหลักคือ `บันทึก` - ปุ่มรองคือ `ยกเลิก` - ห้ามสร้างข้อมูลใน Database จนกว่าผู้ใช้กด
`บันทึก`

### 4.3 บันทึกข้อมูลใหม่สำเร็จ

Default Flow:

`Add Form → Save → Success → Clear Form → Add Form`

หลังบันทึกสำเร็จ: 1. แสดง Notification ด้านบนของ Content Area 2. ใช้ข้อความ
`เพิ่มข้อมูล {ชื่อหน้าจอ} สำเร็จ` 3. ล้างค่าข้อมูลใน Form 4. อยู่หน้า Add เดิม
เพื่อให้ผู้ใช้เพิ่มข้อมูลรายการถัดไปได้ทันที 5. ห้ามกลับ List อัตโนมัติสำหรับ Master Data
Standard

**Exception:** ถ้า Feature มี Workflow เฉพาะ เช่น Wizard หรือ Transaction
หลายขั้น สามารถไปขั้นถัดไปได้ แต่ต้องกำหนดไว้ใน Feature Specification

### 4.4 เมื่อกด "แก้ไข"

Default Flow:

`List → Edit Form`

-   โหลดข้อมูลรายการที่เลือก
-   แสดง Loading ระหว่างโหลด
-   หากไม่พบข้อมูล ให้แจ้ง Error และให้กลับ List
-   ปุ่มหลัก `บันทึก`
-   ปุ่มรอง `ยกเลิก`

### 4.5 บันทึกการแก้ไขสำเร็จ

Default Flow:

`Edit Form → Save → Success → List`

หลังสำเร็จให้กลับ List และ Refresh ข้อมูลล่าสุด

ถ้า Feature ถูกเปิดมาจาก Detail Screen และ UX ของ Feature กำหนดชัดเจน
สามารถกลับ Detail Screen เดิมแทน List ได้

------------------------------------------------------------------------

## 5. Form Standard

### 5.1 Standard Buttons

ฟอร์มสร้าง/แก้ไขข้อมูลใช้: - `บันทึก` --- Primary - `ยกเลิก` --- Secondary

ไม่ควรใช้คำหลายแบบสำหรับความหมายเดียวกัน เช่น `ตกลง`, `Submit`, `Save`
สลับกันโดยไม่มีเหตุผล

### 5.2 Required Fields

-   ช่องบังคับต้องระบุให้ชัดเจน
-   Label ใช้สีปกติ และให้เฉพาะเครื่องหมาย `*` เป็นสีแดง
-   เมื่อ Validation ไม่ผ่าน ให้แสดงข้อความใต้ Field
-   ไม่ทำให้ Label ทั้งข้อความเป็นสีแดงโดยไม่จำเป็น
-   Validation ต้องบอกว่าผิดตรงไหนและต้องแก้อย่างไร
-   Validation ที่ตรวจได้บน Client ควรตรวจโดยไม่ต้องรอ API
-   Validation ฝั่ง Server/API ยังต้องมีเสมอสำหรับ Business Rule และ Security

### 5.3 เมื่อกดบันทึก

ลำดับมาตรฐาน:

`Validate → Loading → API/Service → Result`

ระหว่างบันทึก: - ป้องกัน Double Submit - ปุ่มบันทึกต้องไม่ส่งคำขอซ้ำ - แสดง Loading
ที่เห็นได้ชัด - ห้ามล้างข้อมูลในฟอร์มก่อนทราบผลจาก Server

### 5.4 บันทึกไม่สำเร็จ

เมื่อ API/Database Error: - อยู่หน้า Form เดิม - เก็บค่าที่ผู้ใช้กรอกไว้ - แสดงข้อความ
Error ที่เข้าใจได้ - เปิดให้ผู้ใช้แก้ไขและกดบันทึกใหม่ - ห้ามกลับ List อัตโนมัติ - ห้ามแสดง
Technical Stack Trace ต่อ End User

### 5.5 ยกเลิก

ถ้าไม่มีการแก้ไข: `Cancel → Previous/List`

ถ้ามี Unsaved Changes: `Cancel/Back → Confirm Discard → Previous/List`

ข้อความแนะนำ: `มีข้อมูลที่ยังไม่ได้บันทึก ต้องการออกจากหน้านี้หรือไม่?`

ปุ่ม: - `อยู่หน้านี้` - `ออกโดยไม่บันทึก`

------------------------------------------------------------------------

## 6. Back Navigation Standard

ปุ่ม Back ต้องกลับไปยังหน้าที่สมเหตุสมผลใน Workflow ไม่ควรส่งผู้ใช้ไปหน้า Login หรือ
Landing โดยไม่เกี่ยวข้อง

Priority: 1. กลับ Parent/Previous Screen ของ Feature 2. กลับ List ของ
Feature 3. กลับ Module Home 4. ใช้ Browser/System Back เฉพาะเมื่อไม่ทำให้ Flow
ผิด

ถ้ามี Unsaved Changes ต้องใช้ Confirmation ก่อนออก

------------------------------------------------------------------------

## 7. Delete Standard

การลบเป็น Destructive Action และต้องไม่ลบทันทีจากการกดครั้งแรก

Flow:

`Delete → Confirmation → Delete Request → Success → Refresh List`

Confirmation ต้อง: - ระบุสิ่งที่กำลังจะลบเมื่อทำได้ - ใช้ปุ่ม `ลบ` เป็น Danger
Action - มีปุ่ม `ยกเลิก` - Default focus ไม่ควรอยู่ที่ปุ่มลบเมื่อมีความเสี่ยงจากการกด
Enter

ลบสำเร็จ: - ปิด Dialog - แจ้ง `ลบข้อมูลเรียบร้อย` - อยู่หน้า List - Refresh List

ลบไม่สำเร็จ: - ไม่เอารายการออกจากหน้าจอแบบหลอกว่าลบแล้ว -
แจ้งเหตุผลที่ผู้ใช้เข้าใจได้ - หากติด Referential/Business Rule
ให้แจ้งว่ารายการถูกใช้งานอยู่เมื่อเหมาะสม

------------------------------------------------------------------------

## 8. Detail Screen Standard

Detail Screen ใช้เมื่อข้อมูลมีรายละเอียดมากหรือไม่เหมาะกับการแก้ไขทันที

Standard Actions: - `กลับ` - `แก้ไข` ถ้ามีสิทธิ์ - `ลบ` ถ้ามีสิทธิ์และ Feature อนุญาต

Flow: - `List → Detail` - `Detail → Edit → Save → Detail`
เป็นรูปแบบที่อนุญาต - ถ้าลบจาก Detail สำเร็จ → กลับ List

------------------------------------------------------------------------

## 9. Search, Filter and Pagination

-   หน้าจอ List ต้องรองรับ Pagination
-   Default Page Size ต้องอ่านจาก Setup ส่วนกลาง เช่น `RowSTD` ไม่ Hard-code
    ในแต่ละหน้าจอ
-   Page Size Option ควรกำหนดจากมาตรฐาน/Setup กลางตามที่ระบบอนุมัติ
-   Search ต้องไม่ล้าง Filter อื่นโดยไม่แจ้ง
-   Clear Filter คืนค่า Filter ทั้งหมดเป็น Default
-   เมื่อเปิด Add/Edit แล้วกลับ List ควรรักษา Search/Filter/Page เดิมถ้าทำได้
-   เมื่อ Filter เปลี่ยนและใช้ Pagination ให้กลับ Page 1
-   Empty Result ต้องแยกระหว่าง:
    -   ยังไม่มีข้อมูล
    -   ไม่พบข้อมูลจากเงื่อนไขค้นหา

ตัวอย่าง: - `ยังไม่มีข้อมูล Partner` - `ไม่พบข้อมูลตามเงื่อนไขที่ค้นหา`

------------------------------------------------------------------------

## 10. Loading Standard

ทุก Operation ที่รอข้อมูลต้องมี Loading State

### Page Loading

ใช้เมื่อเปิดหน้าที่ต้องโหลดข้อมูลหลัก

### Inline Loading

ใช้เมื่อโหลดเฉพาะบางส่วน

### Action Loading

ใช้เมื่อ Save/Delete/Submit

กฎ: - ห้ามปล่อยให้ผู้ใช้กด Action ซ้ำขณะ Request เดิมยังไม่เสร็จ - ไม่ควร Block
ทั้งหน้าถ้า Request กระทบเพียง Component เดียว

------------------------------------------------------------------------

## 11. Action Result Notification Standard

ทุก Action เมื่อทำรายการเสร็จต้องแจ้งผลให้ผู้ใช้ทราบ โดยแสดงบริเวณด้านบนของ Content
Area/หน้าจอปัจจุบัน และไม่ใช้ Popup `OK` สำหรับผลสำเร็จทั่วไป

### 11.1 Success Message Format

-   Add: `เพิ่มข้อมูล {ชื่อหน้าจอ} สำเร็จ`
-   Edit: `แก้ไขข้อมูล {ชื่อหน้าจอ} สำเร็จ`
-   Delete: `ลบ {ชื่อหน้าจอ} สำเร็จ`

ตัวอย่างหน้า Partner: - `เพิ่มข้อมูล Partner สำเร็จ` -
`แก้ไขข้อมูล Partner สำเร็จ` - `ลบ Partner สำเร็จ`

### 11.2 Notification Behavior

-   Add สำเร็จ → Notification ด้านบน → ล้าง Form → อยู่หน้า Add เดิม
-   Edit สำเร็จ → กลับ List → Refresh → Notification ด้านบน
-   Delete สำเร็จ → กลับ/คงอยู่หน้า List → Refresh → Notification ด้านบน
-   Error → อยู่หน้าปัจจุบันและคงข้อมูลที่ผู้ใช้กรอกไว้เมื่อเหมาะสม
-   Warning/Validation → แสดงข้อความที่สัมพันธ์กับสิ่งที่ต้องแก้
-   Notification ทั่วไปสามารถ Auto-hide ได้
-   เวลา Auto-hide ควรอ่านจาก Setup ส่วนกลาง เช่น `TimeAlert`
-   Error สำคัญควรคงอยู่จนผู้ใช้รับรู้หรือแก้ไข

### 11.3 Semantic Color

-   Success = สีเขียว
-   Warning = สีเตือน
-   Error = สีแดง
-   Info = สีข้อมูลมาตรฐานของระบบ
-   Semantic Color ไม่เปลี่ยนตาม Theme จนทำให้ความหมายสับสน

------------------------------------------------------------------------

## 12. Error Message Standard

ข้อความ Error สำหรับผู้ใช้ต้องตอบอย่างน้อยหนึ่งเรื่อง: - เกิดอะไรขึ้น - ผู้ใช้ควรทำอะไรต่อ

ตัวอย่าง: - `ไม่สามารถบันทึกข้อมูลได้ กรุณาตรวจสอบข้อมูลแล้วลองอีกครั้ง` -
`ไม่สามารถเชื่อมต่อระบบได้ กรุณาลองใหม่` - `Session หมดอายุ กรุณาเข้าสู่ระบบใหม่`

Technical Error, Exception, SQL Error และ Stack Trace ให้บันทึกใน Log
ตามมาตรฐานระบบ ไม่แสดงต่อ End User

------------------------------------------------------------------------

## 13. Confirmation Standard

ใช้ Confirmation เฉพาะ Action ที่: - ลบข้อมูล - ยกเลิกงานที่มี Unsaved Changes -
เปลี่ยนสถานะสำคัญ - ส่ง/อนุมัติ/ยืนยัน Transaction ที่ย้อนกลับไม่ได้หรือมีผลธุรกิจ

ไม่ใช้ Confirmation กับ Action ปกติทุกครั้ง เพราะทำให้ UX ช้าโดยไม่จำเป็น

------------------------------------------------------------------------

## 14. Permission UX Standard

กฎกลางของ Laoo Solutions:

> ถ้าผู้ใช้ไม่มีสิทธิ์ ให้ซ่อน Menu / Button / Action นั้นเป็นค่าเริ่มต้น

-   ไม่ใช้ Disabled เพื่อบอกว่าไม่มีสิทธิ์ เว้นแต่ Feature Specification
    อนุมัติเป็นกรณีพิเศษ
-   Frontend Permission เป็น UX Layer ไม่ใช่ Security Layer
-   API/Backend ต้องตรวจ Permission ซ้ำเสมอ
-   Direct URL/Route ต้องไม่สามารถข้าม Permission ได้

------------------------------------------------------------------------

## 15. Authentication Navigation Standard

### Not Logged In

-   Public/Landing Screen ใช้งานตามสิทธิ์ Guest
-   Protected Screen → Redirect Login

### Login Success

ระบบต้องอ่าน Session/User Context และกำหนดปลายทางตาม
Role/Project/Permission ที่ได้รับ ไม่ hard-code ให้ทุก User
ไปหน้าเดียวหากระบบกำหนด Home ต่างกัน

### Session Expired

-   ยุติ Protected Session
-   แจ้งผู้ใช้แบบเหมาะสม
-   Redirect Login
-   ไม่แสดง Protected Data ต่อ

### Logout

-   Clear Auth State/Token/Session ที่เกี่ยวข้อง
-   Redirect ไปยัง Landing หรือ Login ตาม Application Flow ที่กำหนด
-   Router และ Authentication State ต้องใช้ Source of Truth เดียวกัน

------------------------------------------------------------------------

## 16. Button Hierarchy

### Primary

ใช้กับ Action หลักของหน้าจอ เช่น: - บันทึก - เข้าสู่ระบบ - เพิ่ม - ยืนยัน

หนึ่ง Action Area ควรมี Primary ที่เด่นเพียงหนึ่งตัวเมื่อเป็นไปได้

### Secondary

เช่น: - ยกเลิก - กลับ - ล้าง Filter

### Danger

เช่น: - ลบ - ยกเลิก Transaction สำคัญ

### Icon Button

ใช้เมื่อความหมายเป็นมาตรฐานและเข้าใจง่าย หากอาจกำกวมต้องมี Tooltip/Label

------------------------------------------------------------------------

## 17. Standard Action Matrix

  -----------------------------------------------------------------------
  Current Screen    User Action       Success           Failure
                                      Destination       Destination
  ----------------- ----------------- ----------------- -----------------
  List              เพิ่ม               Add Form          List

  Add Form          บันทึก              Add Form เดิม      Add Form เดิม

  Add Form          ยกเลิก             List/Previous     Add Form
                                                        ถ้ายังไม่ยืนยัน
                                                        discard

  List              แก้ไข              Edit Form         List

  Edit Form         บันทึก              List หรือ Detail   Edit Form เดิม
                                      ตาม Flow          

  Edit Form         ยกเลิก             List/Previous     Edit Form
                                                        ถ้ายังไม่ยืนยัน
                                                        discard

  List              ดู                 Detail            List

  Detail            แก้ไข              Edit Form         Detail

  Detail            ลบ                List              Detail

  List              ลบ                List + Refresh    List

  Any Protected     Session Expired   Login             Current screen
  Screen                                                only until
                                                        redirect

  Login             Login Success     Authorized Home   Login

  Protected Screen  Logout            Landing/Login     Current screen
                                                        until logout
                                                        result
  -----------------------------------------------------------------------

ตารางนี้เป็น Default Behavior ของทุก Project หาก Feature ใดต้องต่างจากนี้
ต้องบันทึกเหตุผลใน Feature Specification

------------------------------------------------------------------------

## 17.1 Approved Workspace / List / Action Layout

### Workspace

-   Logo อยู่ซ้ายบน
-   User อยู่ขวาบน
-   Title Bar มีปุ่มกลับหน้าหลัก, Favorite และ Theme
-   Sidebar อยู่ซ้ายและคงอยู่เมื่อเข้าแต่ละเมนูบน Desktop/Web
-   กลุ่มเมนู Expand/Collapse ได้
-   ระยะห่างเมนูกระชับ
-   หัวกลุ่มเมนูไม่ใช้ตัวหนา
-   Caption ชื่อหน้าจอแสดงใน Content Area ไม่แสดงซ้ำบน Title Bar

### List

-   Search และ Dropdown Filter อยู่ด้านบนตามความเหมาะสมของหน้าจอ
-   ปุ่ม `เพิ่ม` อยู่มุมขวาบน และซ่อนเมื่อไม่มี Permission
-   Action Column อยู่ซ้ายสุด
-   หัว Column ไม่ใช้ตัวหนา
-   หัว Column ใช้สีตาม Theme
-   Column ที่เหมาะสมรองรับ Sort และแสดงทิศทางการ Sort

### Action / Form

-   Caption ต้องบอก Action ปัจจุบัน เช่น `Partner > เพิ่ม`, `Partner > แก้ไข`
-   Form แบ่งเป็น Card ตามกลุ่มข้อมูล
-   Border และ Caption ของ Card ใช้สีตาม Theme
-   ปุ่ม Action ใช้สีตาม Theme ยกเว้น Delete ใช้สีแดง
-   หน้า Add/Edit มี `ยกเลิก` และ `บันทึก` ทั้งด้านบนขวาและด้านล่างขวา
-   ปุ่มบนและล่างต้องเรียก Logic เดียวกัน

### Favorite

-   Favorite อยู่บน Title Bar และเข้าถึงได้ทุกหน้าหลัง Login
-   Caption ของหน้าจอมี `☆ / ★` สำหรับเพิ่ม/นำหน้าปัจจุบันออกจาก Favorite
-   Favorite เป็นของแต่ละ User
-   Favorite ต้องเคารพ Permission และห้ามแสดงหน้าที่ User ไม่มีสิทธิ์

------------------------------------------------------------------------

## 18. Responsive Standard

### Desktop / Web Wide

-   ใช้พื้นที่ได้เต็มประสิทธิภาพ
-   Table และ Side Navigation ใช้ได้เมื่อเหมาะสม

### Tablet

-   ลดความกว้าง Sidebar หรือเปลี่ยนเป็น Drawer
-   Form ไม่ควรกว้างจนอ่านยาก

### Mobile

-   Layout เป็นแนวตั้ง
-   Action สำคัญต้องกดง่าย
-   Table ที่มีหลาย Column ควรใช้ Responsive List/Card หรือ Horizontal
    Strategy ที่ออกแบบไว้
-   ห้ามลดขนาดตัวอักษรจนอ่านยากเพื่อยัดข้อมูลลงหน้าจอ

Business Flow ต้องเหมือนกันทุก Platform

------------------------------------------------------------------------

## 19. Theme and Styling

สีต้องมาจาก Theme/Design Token กลาง หลีกเลี่ยง Hard-coded Color ใน Feature

### 19.1 Theme Preset Version 1

Theme ใช้ Preset สำเร็จรูป ผู้ใช้ไม่เลือกสีทีละองค์ประกอบ

-   `STYLE01–STYLE10` = Hybrid Soft Dark (Workspace/Content/Title Bar เป็นพื้นขาว)
-   `STYLE11–STYLE20` = Light / Colored Sidebar
-   `STYLE21–STYLE30` = Dark
-   `STYLE31–STYLE40` = White Menu
-   `STYLE01` เป็น Default Theme ของ Laoo Solutions
-   การสลับรหัส Theme Group ไม่เปลี่ยนค่าสีเดิมของแต่ละชุด
-   White Menu ใช้สี Theme กับ Main Menu และใช้สีดำกับ Submenu
-   Light/Colored Style 11, 14, 16, 17, 18 และ 19 ใช้สีดำกับ Submenu
-   Dark Style 21–30 ใช้ตัวอักษรเมนูสีขาวหรือสีอ่อน
-   โครงสร้าง Theme ต้องเพิ่ม STYLE31 เป็นต้นไปได้โดยไม่แก้ Logic หลัก

Theme Selector Flow:

`เลือก Style → Preview → ใช้ Theme นี้ / ยกเลิก`

-   Preview ต้องเปลี่ยนหน้าจอจริงทันที
-   กด `ใช้ Theme นี้` จึง Apply ค่า
-   กด `ยกเลิก` ต้องกลับ Theme เดิม
-   เมื่อมี User Preference จริง ให้บันทึก Theme ต่อ User

### 19.2 Theme Tokens

Preset ควรกำหนดค่ากลางสำหรับองค์ประกอบ เช่น: - Primary/Accent -
Background/Surface - Sidebar Background/Text - Selected Menu - Page
Caption - Card Border/Caption - Table Header/Text - Primary/Action
Button - Input Focus - Favorite Active

ทุก Hybrid Style 01–10 ต้องใช้ Workspace, Content และ Title Bar เป็นพื้นสีขาว สี Theme ใช้กับ Sidebar และเส้นกรอบ Card/Container เป็นหลัก ส่วน Style ที่ไม่ใช่ Dark ให้ Content / Action / Form ใช้พื้นสีขาวเป็นหลัก

### 19.3 Semantic Colors

สีที่มีความหมายเฉพาะไม่ควรถูก Theme เปลี่ยน: - Delete / Error = สีแดง - Success =
สีเขียว - Warning = สีเตือน - Required `*` = สีแดง

### 19.4 General Styling

-   Typography ใช้มาตรฐานกลาง
-   Spacing, Radius, Border และ Shadow ใช้ Shared Standard
-   Brand Default ใช้ภาพลักษณ์ Laoo Solutions

------------------------------------------------------------------------

## 20. Shared Components Rule

เมื่อ Pattern ถูกใช้ซ้ำตั้งแต่ 2--3 จุดขึ้นไป ให้พิจารณาสร้าง Shared Component เช่น: -
Primary Button - Confirm Dialog - Loading Indicator - Empty State -
Error State - Search Bar - Standard Form Field - Page Header - Data
List/Table Wrapper

ไม่ควรสร้าง Shared Component ก่อนมี Use Case จริงเพียงเพื่อคาดการณ์อนาคต

------------------------------------------------------------------------

## 21. Accessibility and Usability

-   ข้อความต้องอ่านได้ชัดเจน
-   Contrast ต้องเพียงพอ
-   Interactive Element ต้องมีพื้นที่กดเหมาะสม
-   Keyboard Navigation ควรทำงานบน Desktop/Web
-   Error ต้องไม่สื่อด้วยสีเพียงอย่างเดียว
-   Icon ที่กำกวมต้องมี Tooltip หรือ Label

------------------------------------------------------------------------

## 22. UX Change Control

ก่อนสร้างหรือแก้ UX/UI ของ Feature ใหม่: 1. สรุป Purpose 2. สรุป Layout 3. ระบุ
Controls / Inputs 4. ระบุ User Flow 5. ระบุ Validation / States 6. ระบุ
Responsive Behavior 7. ตรวจเทียบกับ `UX_UI_STANDARD.md` 8. ขออนุมัติก่อน
Coding เมื่อเป็นการเปลี่ยน UX

ถ้า Feature ใช้ Standard Flow เดิมทั้งหมด ไม่จำเป็นต้องออกแบบ Pattern ใหม่

------------------------------------------------------------------------

## 23. Coding Responsibility

Mhon เป็น Coding Expert หลักของทีมในการนำมาตรฐานนี้ไปใช้ใน Code โดย: - ตรวจว่ามี
Shared Component เดิมหรือไม่ก่อนสร้างใหม่ - หลีกเลี่ยง Style และ Navigation Logic
ซ้ำ - Review ว่า Save/Cancel/Delete/Back ทำงานตาม Standard - ไม่เปลี่ยน
Business Flow หรือ UX ที่อนุมัติแล้วโดยพลการ - แก้เฉพาะส่วนที่จำเป็นเมื่อเป็น Bug Fix

------------------------------------------------------------------------

## 24. Reference Flow --- Master Data

มาตรฐานเริ่มต้นสำหรับ Master Data ทุกประเภท:

`List` → กด `+ เพิ่ม` → `Add Form` → Validate → Save → Success Message →
ล้าง Form → อยู่ `Add Form` เพื่อเพิ่มรายการต่อ

การแก้ไข:

`List` → `แก้ไข` → `Edit Form` → Save → Success Message → กลับ `List` →
Refresh

การลบ:

`List/Detail` → `ลบ` → Confirm → Delete → Success Message → กลับ/คงอยู่
`List` → Refresh

------------------------------------------------------------------------

## 25. Standard Governance

เอกสารนี้เป็น **Central UX/UI Standard** ของ Laoo Solutions

Project-specific UX สามารถเพิ่มเติมได้ แต่: -
ห้ามขัดกับมาตรฐานกลางโดยไม่มีการอนุมัติ - ถ้า Pattern ใหม่มีประโยชน์กับหลาย Project
ให้ยกระดับกลับมาเป็น Central Standard - การแก้มาตรฐานกลางต้องพิจารณาผลกระทบต่อทุก
Project - ทุก Feature ใหม่ควรตรวจเอกสารนี้ก่อนออกแบบและ Coding

------------------------------------------------------------------------

**Laoo Solutions**\
*Simple Today. Ready Tomorrow.*
