# LAOO UX/UI Standard

ไฟล์นี้เป็นมาตรฐาน UX/UI กลางของ Project `laoo` และเป็นจุดเริ่มต้นก่อนอ่านมาตรฐานเฉพาะประเภทหน้าจอ

## Required Reading by Screen Type

- หน้า List หรือ Card: อ่าน `LIST_CARD_UI_STANDARD.md` และ `PAGINATION_UI_STANDARD.md`
- หน้า Action (Add/Edit/View): อ่าน `ACTION_UI_STANDARD.md`
- Popup, Dialog, Alert และ Confirm: อ่าน `POPUP_UI_STANDARD.md`
- งานที่เกี่ยวกับข้อความหรือขนาดตัวอักษร: อ่าน `TYPOGRAPHY_STANDARD.md`
- ถ้างานครอบคลุมหลายประเภท ต้องอ่านทุกไฟล์ที่เกี่ยวข้องก่อนแก้ไข

## Common Design Tokens

- พื้นหลังทุกหน้าจอใช้ `LaooColors.background` (`#F8F9FB`)
- สีหลักและสีสถานะใช้งานอ่านจาก `workspaceThemeController.value.primary` หรือ `WorkspaceThemePreset.primary` ของ User ที่ Login
- Card ใช้พื้นสีขาว ไม่มีเส้นกรอบสี และมุมโค้ง `LaooRadius.xs` (`4px`)
- Margin รอบ Content ใช้ `LaooLayout.cardMargin` (`10px`)
- Padding ภายใน Card ใช้ `LaooLayout.cardPadding` (`10px`)
- ระยะทั่วไประหว่าง Card/Section ใช้ `LaooLayout.cardSpacing` (`10px`) ยกเว้น Card รายการใน Card Mode ซึ่งกำหนดไว้ที่ `6px`
- เส้นคั่นใช้ `LaooColors.border` สีเทาอ่อนและบาง
- Caption หลักใช้ `LaooColors.pageCaption` สีดำ ส่วน Icon ใช้สีหลักของ User Style
- ห้ามใช้ `Colors.green`, `Colors.blue` หรือสีหลักแบบ hardcode; สีแดงใช้ได้เฉพาะ Error, Delete, Offline หรือสถานะไม่ใช้งานตามข้อกำหนด
- เมื่อ User เปลี่ยน Style สีทุกส่วนที่อิง User Styleต้องเปลี่ยนทันทีและต้องไม่กระทบ User คนอื่น

## Common Behavior

- Caption และชื่อเมนูต้องอ่านจาก Navigation API/`TDADMainMenu.MenuName` ผ่าน Resolver กลาง ห้าม hardcode แยกจาก Sidebar
- ทุกหน้าจอต้องเต็ม Content Area ภายใน Shared Workspace และไม่สร้าง Shell ซ้อน
- เมื่อ Content Area แคบกว่า `900px` ต้องใช้ Responsive Layout ที่ไม่เกิด Overflow
- Action ทุกชนิดต้องตรวจทั้ง `ScreenType` และ Permission ของ User; Backend ต้องตรวจซ้ำ
- แก้ UX/UI โดยไม่เปลี่ยน API, SQL, Repository หรือ Business Logic เว้นแต่คำสั่งระบุชัดเจน
- หลังแก้ต้องตรวจ Responsive, Overflow, `dart format` และ `dart analyze` พร้อมสรุปไฟล์ที่แก้

## Prompt กลางสำหรับส่งให้ AI

```text
ปรับหน้าจอใน Project C:\laooplatform\laoo_service โดยอ่าน AGENTS.md และ docs/standards/UX_UI_STANDARD.md ก่อน จากนั้นอ่านมาตรฐานเฉพาะประเภทหน้าจอที่เกี่ยวข้อง ห้ามแก้ API, SQL, Repository หรือ Business Logic ให้ใช้ LaooColors, LaooLayout, LaooRadius, LaooTypography และ Workspace Theme จากส่วนกลางเท่านั้น ตรวจ Permission, Responsive, Overflow, dart format และ dart analyze แล้วสรุปไฟล์ที่แก้
```

