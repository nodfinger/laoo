# LAOO UX/UI Standard

ไฟล์นี้เป็นมาตรฐาน UX/UI กลางของ Project `laoo` และเป็นจุดเริ่มต้นก่อนอ่านมาตรฐานเฉพาะประเภทหน้าจอ

## Required Reading by Screen Type

- หน้า List หรือ Card: อ่าน `LIST_CARD_UI_STANDARD.md` และ `PAGINATION_UI_STANDARD.md`
- หน้าจอ CRUD ที่ต้องการเทียบต้นแบบ: อ่าน `MASTER_DATA_CRUD_UI_STANDARD.md` เพิ่มเติม โดยใช้หน้า `05002 รหัสพื้นฐาน` เป็น Visual Reference
- หน้า Action (Add/Edit/View): อ่าน `ACTION_UI_STANDARD.md`; สำหรับ `ScreenType = 1` (CRUD) ต้องใช้ Action Style ตามเอกสารนี้เสมอ ทั้งพื้นผิวสีขาว มุมกรอบและปุ่ม `4px`, Caption สีดำ, Icon ตาม User Style และ TextBox/ComboBox มีกรอบมุมโค้ง `4px`
- Popup, Dialog, Alert และ Confirm: อ่าน `POPUP_UI_STANDARD.md`
- งานที่เกี่ยวกับข้อความหรือขนาดตัวอักษร: อ่าน `TYPOGRAPHY_STANDARD.md`
- ถ้างานครอบคลุมหลายประเภท ต้องอ่านทุกไฟล์ที่เกี่ยวข้องก่อนแก้ไข

## Common Design Tokens

- พื้นหลังทุกหน้าจอใช้ `LaooColors.background` (`#F8F9FB`)
- สีหลักและสีสถานะใช้งานอ่านจาก `workspaceThemeController.value.primary` หรือ `WorkspaceThemePreset.primary` ของ User ที่ Login
- Card ใช้พื้นสีขาว ไม่มีเส้นกรอบสี และมุมโค้ง `LaooRadius.xs` (`4px`)
- Margin รอบ Content ใช้ `LaooLayout.cardMargin` (`10px`)
- Padding ภายใน Card ใช้ `LaooLayout.cardPadding` (`10px`)
- ระยะทั่วไประหว่าง Card/Section ใช้ `LaooLayout.cardSpacing` (`10px`); หน้าจอ List/CRUD ใช้ `LaooLayout.listSectionSpacing` (`6px`) และ Card รายการใช้ `LaooLayout.listItemSpacing` (`6px`)
- เส้นคั่นใช้ `LaooColors.border` สีเทาอ่อนและบาง
- TextBox และ ComboBox ทุกหน้าจอ โดยเฉพาะภายใน Popup ต้องเป็นกรอบรอบช่องแบบ `OutlineInputBorder` เส้นสีเทาจางจาก Neutral/Border Token กลาง และมุมโค้ง `LaooRadius.xs` (`4px`) เสมอ ห้ามใช้เฉพาะเส้นใต้ ห้ามไม่มีกรอบ และห้ามใช้สี Primary เป็นกรอบในสถานะปกติ
- สีที่สื่อการโต้ตอบหรือเอกลักษณ์ของผู้ใช้ เช่น Focus Border, Floating Label ขณะ Focus, Cursor, Selected Item, Icon และปุ่ม Action ต้องอ่านจาก `workspaceThemeController.value`/User Profile Theme ผ่าน Semantic Token กลาง ห้าม hardcode สีรายหน้าจอ
- สีพื้นขาว สีเทากลาง และสีสถานะ Error/Delete/Warning เป็น Semantic Color ตามมาตรฐาน ไม่ถูกแทนด้วยสี Primary ของ User; สถานะ Disabled ต้องใช้ Disabled/Neutral Token และยังคงกรอบเทาจางกับมุม `4px`
- Caption หลักของหน้า `List`, `Card`, `Action` และ `Popup/Dialog` ใช้ `fontSize: 18`, `fontWeight: FontWeight.w700` และ `LaooColors.pageCaption` ซึ่งต้องเป็นสีดำ ส่วน Icon ใช้สีหลักของ User Style; ยกเว้น Popup ยืนยันลบ ให้ Caption และ Icon ใช้สี Error/Delete ตาม `alertdelete.md`
- ห้ามใช้ `Colors.green`, `Colors.blue` หรือสีหลักแบบ hardcode; สีแดงใช้ได้เฉพาะ Error, Delete, Offline หรือสถานะไม่ใช้งานตามข้อกำหนด
- เมื่อ User เปลี่ยน Style สีทุกส่วนที่อิง User Styleต้องเปลี่ยนทันทีและต้องไม่กระทบ User คนอื่น

## Common Behavior

- Shared Workspace Header ต้องใช้พื้นที่แนวตั้งอย่างประหยัด: Desktop สูง `52px` และ Mobile สูง `56px`
- Desktop ต้องวางปุ่มหน้าแรก เมนูลัด และเมนูผู้ใช้ในแถวเดียวกัน; แสดงเมนูลัดโดยตรงได้สูงสุด `5` รายการตามพื้นที่ และรวมรายการที่เกินไว้ใน Popup `เพิ่มเติม`
- Mobile แสดงเมนูลัดทั้งหมดผ่าน Popup รูปดาว และใช้ User Menu แบบ Compact; คำอธิบายสิทธิ์/ประเภทผู้ใช้แสดงภายใน User Menu ไม่วางเป็นบรรทัดที่สองบน Header
- คำสั่งออกจากระบบอยู่ภายใน User Menu เพียงตำแหน่งเดียว ห้ามวางปุ่มซ้ำบน Workspace Header
- Caption และชื่อเมนูต้องอ่านจาก Navigation API/`TDADMainMenu.MenuName` ผ่าน Resolver กลาง ห้าม hardcode แยกจาก Sidebar
- ทุกหน้าจอที่ผูก MenuCode ต้องมีปุ่ม Icon ดาวอยู่ถัดจาก Caption เพื่อเพิ่ม/นำออกจากเมนูลัดของผู้ Login และสถานะต้องเชื่อมกับเมนูลัดส่วนกลางทันที
- ทุกหน้าจอต้องเต็ม Content Area ภายใน Shared Workspace และไม่สร้าง Shell ซ้อน
- เมื่อ Content Area แคบกว่า `900px` ต้องใช้ Responsive Layout ที่ไม่เกิด Overflow
- Action ทุกชนิดต้องตรวจทั้ง `ScreenType` และ Permission ของ User; Backend ต้องตรวจซ้ำ
- Error ทุกหน้าจอต้องแสดงข้อความหลักพร้อม `รายละเอียดเพิ่มเติม` ที่บอกสาเหตุหรือสิ่งที่ผู้ใช้ควรทำต่อ ตาม `POPUP_UI_STANDARD.md`; ห้ามแสดงข้อความ API แบบกว้างเพียงบรรทัดเดียว
- แก้ UX/UI โดยไม่เปลี่ยน API, SQL, Repository หรือ Business Logic เว้นแต่คำสั่งระบุชัดเจน
- หลังแก้ต้องตรวจ Responsive, Overflow, `dart format` และ `dart analyze` พร้อมสรุปไฟล์ที่แก้

## Prompt กลางสำหรับส่งให้ AI

```text
ปรับหน้าจอใน Project C:\laooplatform\laoo โดยอ่าน AGENTS.md และ docs/standards/UX_UI_STANDARD.md ก่อน จากนั้นอ่านมาตรฐานเฉพาะประเภทหน้าจอที่เกี่ยวข้อง ห้ามแก้ API, SQL, Repository หรือ Business Logic ให้ใช้ LaooColors, LaooLayout, LaooRadius, LaooTypography และ Workspace Theme จากส่วนกลางเท่านั้น TextBox/ComboBox ต้องมีกรอบเทาจางแบบ Outline มุม 4px ทุกสถานะ และสีโต้ตอบต้องอ่านจาก User Profile Theme ตรวจ Permission, Responsive, Overflow, dart format และ dart analyze แล้วสรุปไฟล์ที่แก้
```
