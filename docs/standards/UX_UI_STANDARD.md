# LAOO UX/UI AND SCREEN FLOW STANDARD

**Document Type:** Central Standard
**Scope:** All Laoo Solutions systems and projects
**Status:** Approved Baseline
**Standard Path:** `C:\laoo\docs\standards\UX_UI_STANDARD.md`

เอกสารนี้เป็น Source of Truth เพียงไฟล์เดียวสำหรับ UX/UI และ Flow ของหน้าจอ
รวมกติกาเดิมจาก `CRUD_FLOW_STANDARD.md` และ `UX_UI_STANDARD.md` เพื่อไม่ให้แต่ละเอกสารกำหนดพฤติกรรมขัดกัน

##ถ้า หน้าจอมี DataList
ตารางเต็มพื้นที่ Content
ไม่มีเส้นแนวตั้ง มีเฉพาะเส้นแบ่งแถว

เปลี่ยนหัวคอลัมน์เป็น รหัส, ชื่อ, เรียงลำดับแสดง
คลิกหัวคอลัมน์เพื่อ Sort ได้
เพิ่ม Pagination ด้านล่าง
##ถ้า หน้าจอ CRUD หัว Action อยู่กึ่งกลาง

---

## 1. หลัก UX กลาง

- Menu Caption Source of Truth: Sidebar, List และ Action Form ต้องใช้ Menu Resolver ส่วนกลางเพื่ออ่าน `MenuName` จาก Navigation API/`TDADMainMenu` ด้วย `MenuCode` หรือ `RouteName` ห้ามกำหนดชื่อ fallback แยกกันจนแสดงไม่ตรงกัน

- **Simple First:** แสดงข้อมูลและคำสั่งที่จำเป็นกับงานปัจจุบัน
- **Predictable:** ปุ่มและ Flow เดียวกันต้องทำงานเหมือนกันทุกหน้าจอ
- **Safe by Default:** ป้องกันการกดซ้ำ ข้อมูลสูญหาย และการลบโดยไม่ตั้งใจ
- **Responsive:** รองรับ Web, Windows, Tablet และ Mobile
- **Permission First:** Frontend ซ่อน Action ที่ไม่มีสิทธิ์ และ Backend ต้องตรวจซ้ำทุกครั้ง
- Business Rule และผลลัพธ์สุดท้ายต้องตัดสินที่ API/Backend ไม่ใช่ Flutter

---

## 2. ประเภทหน้าจอ

ก่อนสร้างหน้าจอใหม่ ผู้สั่งงานต้องแจ้ง `MenuCode` และ `ScreenType` ให้ชัดเจน โดยระบบอ่านชื่อหน้าจอจาก `MenuName` หนึ่งหน้าจออาจมี List และ Form แต่ต้องมี ScreenType หลักเพียงแบบเดียว

### 2.1 CRUD

สำหรับหน้าผู้ใช้บริการของ Support ที่ดูข้อมูลข้ามหลาย Partner:

- Caption ของ Shell, List และ Action Screen ต้องใช้ `MenuName` เดียวกันจาก `TDADMainMenu`
- ตารางต้องวางคอลัมน์ `Partner` ถัดจาก `Action` เพื่อระบุเจ้าของผู้ใช้บริการ และต้องมี Partner Filter ด้านบน

ใช้กับข้อมูล Master/Setup ที่ผู้ใช้มีสิทธิ์ **เพิ่ม แก้ไข และลบ**

ต้องมี:

- List พร้อม Search/Filter, Sort และ Pagination
- ปุ่ม `+ เพิ่ม` ตาม Permission
- Action Column อยู่ Column 2 ตามมาตรฐาน List
- Edit และ Delete ตาม Permission
- Form เพิ่ม/แก้ไข พร้อมปุ่ม `ยกเลิก` และ `บันทึก` ด้านบนและล่างชิดขวา
- Dialog ยืนยันการลบก่อนเรียก DELETE API

Flow มาตรฐาน:

```text
List → + เพิ่ม → Add Form → Validate → Save → Success → ล้าง Form → Add Form เดิม
List → Edit → Edit Form → Validate → Save → Success → กลับ List → Refresh
List → Delete → Confirm → DELETE API → Success → กลับ List → Refresh
```

ผลลัพธ์หลัง Action:

- เพิ่มสำเร็จ: แสดง `เพิ่มข้อมูล {ชื่อหน้าจอ} สำเร็จ`, ล้าง Form และอยู่หน้า Add Form เดิม
- แก้ไขสำเร็จ: กลับ List, Refresh และแสดง `แก้ไขข้อมูล {ชื่อหน้าจอ} สำเร็จ`
- ลบสำเร็จ: กลับ/คงอยู่ List, Refresh และแสดง `ลบ {ชื่อหน้าจอ} สำเร็จ`
- Save/Delete ไม่สำเร็จ: อยู่หน้าเดิม เก็บค่าที่กรอกไว้ และแสดงเหตุผลที่แก้ไขได้

#### 2.1.1 CRUD Action Screen

มาตรฐานเพิ่มเติม:

- Caption และชุดปุ่ม `ยกเลิก`/`บันทึก` ต้องอยู่บรรทัดเดียวกันเสมอ โดย Caption อยู่ด้านซ้ายและปุ่มอยู่ด้านขวา ทั้งตำแหน่งด้านบนและด้านล่างของ Form หากมีการแสดงซ้ำ
- หลัง Add, Edit, Delete หรือ Action สำเร็จทุกครั้ง ต้องแสดง Success Notification หลังจบรายการ โดยมีไอคอนสำเร็จ ข้อความสรุปผล และปุ่มปิด

`CRUD Action Screen` เป็นหน้าจอลูกที่เปิดจาก Add, Edit, View หรือ Custom Action ของหน้าจอ CRUD ไม่ใช่ ScreenType ตัวที่ 4

กติกา:

- สืบทอด `MenuCode`, `ScreenType` และ Permission Context จากหน้าจอแม่
- Action ที่มี Form, หลาย Field, Table ย่อย หรือ Business Flow ต่อเนื่อง ต้องเปิดเต็มพื้นที่ Content Area ภายใน Shared Workspace
- ต้องคง Sidebar, Top Bar, User Context, Theme และ Favorite ของ Shared Shell เดิม
- ห้ามเปิด Action หลักเป็น Dialog/Popup และห้ามสร้าง Scaffold/Shell ชุดใหม่
- Caption ใช้ `{MenuName} > {Action}` เช่น `Partner > เพิ่ม`, `Partner > แก้ไข`, `Partner > จัดการ Module`
- ปุ่ม Save/Cancel หรือปุ่มของ Action ต้องอยู่ด้านบนและล่างชิดขวาและเรียก Logic เดียวกัน
- Save สำเร็จให้ไปปลายทางตาม Flow ที่กำหนด; ถ้า Feature ไม่ระบุ ให้ใช้ Create อยู่หน้าเดิมและล้าง Form, Edit/Custom Action กลับ List แล้ว Refresh
- Cancel ต้องกลับหน้าก่อนหน้าโดยไม่บันทึก และต้องยืนยันก่อนออกเมื่อมีข้อมูลที่แก้แล้วยังไม่บันทึก
- Dialog ใช้เฉพาะ Confirm Delete, Confirm Action หรือ Lookup ขนาดเล็ก ไม่ใช้แทน Action Screen หลัก
- Action แต่ละรายการต้องมี ActionCode และ Permission ที่ชัดเจน; ถ้าไม่พบข้อกำหนดให้หยุดถามผู้สั่งงานก่อน Coding

### 2.2 UpdateOnly

ใช้กับข้อมูลที่ระบบอนุญาตให้ **แก้ไขข้อมูลเดิมเท่านั้น** ไม่อนุญาตให้สร้างหรือลบจากหน้าจอนี้

ต้องมี:

- List หรือ Form เดียวที่มี Search/Filter และ Pagination เมื่อมีหลายรายการ
- ไม่มีปุ่ม `+ เพิ่ม`
- ไม่มี Delete Action
- มี Edit หรือเปิดให้แก้ไขในแถว/หน้าเดียวตาม Design ที่อนุมัติ
- ปุ่ม `บันทึก` และ `ยกเลิก` ด้านบนและล่างชิดขวาเมื่อใช้ Form

Flow มาตรฐาน:

```text
List → Edit → Update Form → Validate → Save → Success → กลับ List → Refresh
List → Inline Edit → Save → Success → Refresh แถวเดิม
```

ผลลัพธ์:

- บันทึกสำเร็จ: แสดง `แก้ไขข้อมูล {ชื่อหน้าจอ} สำเร็จ` และกลับ List หรือ Refresh แถวเดิมตามรูปแบบที่อนุมัติ
- ยกเลิก: กลับ List หรือคืนค่าก่อนแก้ไข โดยต้องไม่บันทึกข้อมูล
- บันทึกไม่สำเร็จ: อยู่หน้าเดิม เก็บค่าที่กรอกไว้ และแสดง Error

### 2.3 ShowOnly

ใช้กับข้อมูลที่ผู้ใช้มีสิทธิ์ดูเท่านั้น ไม่มีการเปลี่ยนข้อมูลจากหน้าจอ

ต้องมี:

- List/Detail พร้อม Search/Filter, Sort และ Pagination เมื่อเหมาะสม
- ไม่มี `+ เพิ่ม`, Edit, Delete, Save หรือ Change Status
- อาจมี Copy, Export หรือเปิดเอกสารได้ ถ้าเป็น Read-only และได้รับอนุมัติ

Flow มาตรฐาน:

```text
Open → Load → Search / Filter / Sort / Pagination → View
```

---

## 3. โครงสร้างหน้าจอร่วม

ทุกหน้าจอหลัง Login ใช้ Shared Workspace เดียวกัน:

- Logo อยู่ซ้ายบน, User อยู่ขวาบน, Sidebar อยู่ซ้ายบน Desktop/Web
- Content และ Action Screen ใช้เต็มความกว้างตามพื้นที่ที่เหลือภายใน Shared Workspace
- Caption อ่านจาก `MenuName` และ Action ใช้รูปแบบ `{MenuName} > {Action}`
- ระยะ Caption ถึง Form กระชับประมาณ `8px`
- สี Caption, Border, Header และ Action มาจาก Theme/Design Token กลาง
- Font และ Typography ใช้ `LaooTypography`, `LaooTheme` และ `WorkspaceThemePreset`

### 3.1 List

- ต้องมีช่อง Filter แบบ TextBox สำหรับพิมพ์ค้นหา
- ไม่ใช้ Auto Search เป็นค่าเริ่มต้น เพราะอาจเรียก API ถี่และทำให้ระบบช้า
- ช่อง Filter ต้องมีไอคอนแว่นขยายอยู่ด้านซ้าย และไอคอนลูกศรค้นหาอยู่ด้านขวาสุด
- ให้ค้นหาเมื่อผู้ใช้กดไอคอนลูกศร หรือกด `Enter` เท่านั้น
- เมื่อ Filter เป็นค่าว่าง ให้โหลดข้อมูลทั้งหมดตาม Sort และ Pagination ปัจจุบันเมื่อสั่งค้นหา
- ปุ่ม Refresh ต้องเรียกข้อมูลใหม่ทันทีโดยใช้ Filter, Sort และ Pagination ปัจจุบัน
- ช่อง Filter ต้องมีความกว้างกระชับ และไม่ยืดเต็มแถวโดยไม่จำเป็น
- มีปุ่ม `ล้าง Filter` และ Refresh ตามความเหมาะสม
- ข้อมูลต้องแสดงเป็น Table และใช้เส้นขอบ สีพื้น Header สีเส้นแบ่งแถว และระยะห่างตาม User Style/Theme ที่ผู้ใช้เลือก
- Table ต้องมีเส้นบรรทัดแบ่งแถวและคอลัมน์ให้เห็นชัดเจนเสมอ เพื่อให้ผู้ใช้จับคู่ Header กับข้อมูลได้ถูกต้อง
- อักษรที่หัวคอลัมน์ต้องเป็นตัวหนา และใช้สีหลักตาม Style/Theme ที่ผู้ใช้เลือก
- รูปดินสอสำหรับแก้ไขต้องใช้สีหลักตาม Style/Theme ที่ผู้ใช้เลือก ห้ามกำหนดสีตายตัวเฉพาะหน้าจอ
- ห้ามกำหนดสี Table แบบตายตัวเฉพาะหน้าจอ
- ลำดับ Column มาตรฐาน: Column 1 = `ID`, Column 2 = `Action`, จากนั้นจึงเป็น Column ข้อมูล
- `ID` ใน List ใช้เลข Run ลำดับ 1, 2, 3 ตามข้อมูลที่แสดงในหน้า/หน้า Pagination ไม่ใช่ Database Key
- หัว Column ใช้สีตัวอักษรจาก User Style/Theme, ตัวหนา และ Column ที่รองรับต้อง Sort ได้เมื่อกดหัว Column
- หัว `ID` และ `Action` ไม่ต้อง Sort เว้นแต่ Feature Specification ระบุเป็นกรณีพิเศษ
- Empty State แยก `ยังไม่มีข้อมูล` กับ `ไม่พบข้อมูลตามเงื่อนไข`
- ใช้ Pagination ตามมาตรฐาน `RowSTD` เมื่อระบบกำหนดไว้

#### 3.1.1 Action Column

- `Action` อยู่ Column ที่ 2 และจัดปุ่มให้อยู่กึ่งกลางทั้งแนวนอนและแนวตั้ง
- ปุ่ม `Edit` ใช้ไอคอนรูปดินสอ สี Primary/สีหลักจาก User Style
- ปุ่ม `Delete` ใช้ไอคอนรูปถังขยะ สีแดงเสมอ
- ทั้ง Edit และ Delete ต้องมี Tooltip หรือ Semantic Label
- ไม่มี Permission `EDIT` ให้ซ่อนปุ่ม Edit
- ไม่มี Permission `DELETE` ให้ซ่อนปุ่ม Delete
- การซ่อน Action ต้องคำนวณจากสิทธิ์ของผู้ใช้ที่ Login แล้ว ไม่ใช่ซ่อนเพียงที่ UI; Backend ต้องตรวจ Permission ซ้ำ
- ถ้าไม่มี Action ที่ผู้ใช้มีสิทธิ์ ให้แสดง Cell ว่างตาม Layout และยังคงลำดับ Column มาตรฐาน

### 3.2 Form

- Form แบ่ง Card ตามกลุ่มข้อมูล
- Label, Hint, Validation และ Button ใช้ Typography กลาง
- ปุ่มชุดเดียวกันสูง `LaooTypography.buttonHeight` เดียวกัน (`48px`)
- ปุ่ม `ยกเลิก` จัดข้อความกึ่งกลางและใช้ความสูงเดียวกับ `บันทึก`
- Required Field แสดง `*` และตรวจซ้ำที่ API
- เพิ่ม/แก้ไขต้องมี Caption และสถานะ Action ชัดเจน

---

## 4. Action และ Permission

Permission หลัก:

- `VIEW` แสดงหน้าจอ
- `CREATE` เพิ่มข้อมูล
- `EDIT` แก้ไขข้อมูล
- `DELETE` ลบข้อมูล
- `CHANGE_STATUS` เปลี่ยนสถานะ

กฎ:

- ไม่มี Permission ให้ซ่อน Action ใน Frontend
- Backend ต้องตรวจ Authentication, Scope, Permission และ Business Rule ซ้ำ
- Double Click ต้องไม่ส่ง Request ซ้ำ
- Edit ใช้สี Primary/สีหลักของ Theme
- Delete ใช้สีแดงเสมอและมี Tooltip
- Change Status ไม่ใช่ Delete; ถ้าข้อมูลยังต้องอยู่ระบบให้ใช้ Status

### 4.1 Delete Confirmation

Pattern บังคับของ Delete Confirmation:

- แสดงไอคอนถังขยะสีแดงด้านบนและหัวข้อโทนสีแดง
- แสดงข้อความรายการในกล่องพื้นแดงอ่อน โดยต้องมี Key/รหัสและชื่อรายการ
- แสดงข้อความเตือนว่าข้อมูลที่ลบแล้วไม่สามารถเรียกคืนได้
- ปุ่ม `ยกเลิก` เป็น TextButton และปุ่ม `ลบ` เป็นสีแดงพร้อมไอคอนถังขยะ
- Action Form ต้องวางช่อง `สถานะ` ไว้ด้านบนสุดก่อน Field อื่น โดยวางข้อความกับตัวเลื่อนเปิด/ปิดไว้ติดกันในกลุ่มเดียวกัน และใช้ระยะห่างระหว่างแถว TextBox ประมาณ `12px` เพื่อไม่ให้ช่องกรอกชิดกันเกินไป

ต้องแสดงชื่อ/Key ของข้อมูล ข้อความเตือน ปุ่ม `ยกเลิก` และปุ่ม `ลบ` สีแดง

- หัวข้อและกรอบใช้โทนแดง
- ปุ่มลบต้องไม่เป็น Default Focus
- ห้ามนำรายการออกจาก List ก่อน API ยืนยันสำเร็จ
- ถ้ามี Referential Integrity ให้ API คืน `409 Conflict` และคงรายการไว้

---

## 5. API และสถานะการทำงาน

ทุก Request ต้องมี Loading, Error, Empty และ Success State ที่เหมาะสม

HTTP Result มาตรฐาน:

- `200/204` สำเร็จ
- `400` Request ไม่ถูกต้อง
- `401` ไม่ Login/Token ไม่ถูกต้อง
- `403` ไม่มี Permission
- `404` ไม่พบข้อมูล
- `409` ขัดกับ Business Rule หรือ Referential Integrity
- `500` Unexpected Error; ห้ามแสดง SQL Exception/Stack Trace ให้ผู้ใช้

Success Notification ใช้กล่องด้านบน Content Area โทนเขียวอ่อน มีไอคอนสำเร็จ ข้อความสรุป และปุ่มปิด

---

## 6. Responsive และ Accessibility

- Desktop/Web ใช้ Table และ Sidebar เมื่อเหมาะสม
- Tablet ลด Sidebar เป็น Drawer ได้ และไม่ให้ Form กว้างจนอ่านยาก
- Mobile ใช้ Card/List หรือ Horizontal Table Strategy ได้ แต่ Business Flow ต้องเหมือน Desktop
- Action สำคัญต้องกดง่ายและยังเห็น Edit/Delete ตามสิทธิ์
- Contrast ต้องอ่านได้ชัด
- Icon ที่ไม่ชัดต้องมี Tooltip หรือ Label
- Error ห้ามสื่อด้วยสีเพียงอย่างเดียว
- Desktop/Web ควรรองรับ Keyboard Navigation

---

## 7. Authentication Navigation

- Sidebar อ่าน Menu Group/Menu Item จาก Navigation API ซึ่งคัดจาก `TDADMainMenu` ตาม `user_type`, Project และสิทธิ์ `VIEW` เท่านั้น ห้ามเติมรายการ hard-code เมื่อ API ผิดพลาด
- ใช้ `MenuCode` เป็น Primary Identity สำหรับจับคู่เมนูกับ Route Registry ส่วนกลาง; `RouteName` จากฐานข้อมูลเป็น metadata และไม่ส่งเข้า Router โดยตรง
- Menu cache ต้องผูกกับ Session/User และต้องถูกสร้างใหม่เมื่อเปลี่ยนผู้ Login เพื่อไม่ให้สิทธิ์หรือรายการเมนูรั่วข้ามบัญชี

```text
Not Logged In → Landing/Login
Login Success → Authorized Home
Session Expired → Login
Logout → Landing/Login
```

Protected Screen ต้องไม่เปิดข้อมูลเมื่อไม่มี Session หรือ Permission

---

## 8. Shared Components และ Theme

### 8.1 TDSTMaster ComboBox และ MasterGroupCode

- ComboBox ที่อ่านข้อมูลจาก `TDSTMaster` ต้องมีปุ่มเปิด Popup สำหรับเพิ่ม แก้ไข และลบข้อมูลตาม Permission ของผู้ใช้ โดย Backend ต้องตรวจสอบ Permission ซ้ำทุก Action
- การอ่านข้อมูลจาก `TDSTMaster` ต้องระบุ `MasterGroupCode` ผ่านตัวแปรกลาง ห้ามฝังรหัสเป็น String ในหน้าจอหรือ Repository
- ตัวแปรกลางของ Master Group ต้องใช้ Prefix `Ms` ตามความหมาย เช่น `001 = MsProv` และ `002 = MsUnit`; เมื่อเรียกใช้ข้อมูลหน่วยบรรจุต้องอ้าง `MsUnit` เพื่อได้ `MasterGroupCode='002'`

เมื่อรูปแบบ UX ถูกใช้ซ้ำตั้งแต่ 2–3 จุด ให้พิจารณาใช้ Shared Component เช่น Search Bar, Form Field, Confirm Dialog, Loading, Empty State, Error State, Page Header และ DataTable Wrapper

Theme กลางต้องควบคุม:

- Primary/Accent, Surface, Background และ Border
- Sidebar, Selected Menu และ Page Caption
- Table Header, Card, Button, Input Focus และ Semantic Colors
- Delete/Error = แดง, Success = เขียว, Warning = สีเตือน

ห้ามกำหนดสีหรือ Font ตายตัวใน Feature โดยไม่จำเป็น

---

## 9. Development และ Governance

ก่อน Coding ต้องตรวจ Source ล่าสุดและระบุ Screen Mode (`CRUD`, `UpdateOnly`, `ShowOnly`)

ถ้า Feature ต้องใช้ Flow ต่างจากเอกสารนี้:

1. ระบุเหตุผลและผลกระทบ
2. บันทึกใน Feature Specification
3. ขออนุมัติก่อนเปลี่ยน UX/Business Flow
4. ถ้าเป็นรูปแบบ UX/ScreenType ที่ใช้ได้หลาย Feature ให้ยกระดับกลับมาแก้ Standard นี้

เอกสารนี้เป็น Source of Truth เพียงไฟล์เดียว ห้ามสร้างกติกาซ้ำในไฟล์ Standard อื่น

---

**Laoo Solutions**
*Simple Today. Ready Tomorrow.*

- Alert ทุกหน้าจอต้องใช้ค่า TimeAlert จาก CompanySetupContext เป็นเวลาหายอัตโนมัติ และต้องมีปุ่มปิดเอง
