# LAOO Popup, Dialog and Alert Standard

มาตรฐานนี้ใช้กับ Popup, Dialog, Lookup, Confirm และ Notification ทุกหน้าจอ

## Scope

- ใช้ Popup เฉพาะงานสั้น เช่น Confirm Delete, Confirm Action, Lookup หรือจัดการ Master ขนาดเล็กที่ได้รับอนุมัติ
- ห้ามใช้ Popup แทน Action Screen ที่มี Form หลาย Field เว้นแต่พ่ออนุมัติหน้าจอนั้นโดยตรง

## Popup Layout

- Popup ใช้พื้นผิว Theme กลาง ไม่มี `BorderSide` หรือเส้นกรอบรอบนอกเฉพาะหน้า
- ระยะขอบ Popup ใช้ `LaooLayout.dialogInsetPadding`; Padding ภายในใช้ `LaooLayout.cardPadding`
- Caption ใช้มาตรฐานกลาง `fontSize: 18`, `fontWeight: FontWeight.w700`, `color: Colors.black` ตาม `TYPOGRAPHY_STANDARD.md`; Icon หน้า Caption ใช้ Primary ตาม User Style
- ใช้เส้น `LaooColors.border` สีเทาอ่อนใต้ Caption และก่อนส่วนปุ่มด้านล่าง
- Context Bar ที่แสดงรายการแม่/ห้อง/อาคารที่เลือก ใช้พื้น Primary แบบโปร่งแสงและข้อความขนาด `16px`
- TextBox/ComboBox ใช้กรอบมาตรฐาน มุมโค้ง `4px`; Label และ Focus Border ใช้ Primary
- ปุ่มด้านล่างใช้ Font `13px`, สูง `48px`, มุมโค้ง `4px`; ยกเลิกใช้ Text/Outlined Primary และบันทึกใช้ Filled Primary
- เมื่อ Popup แคบต้องจัด Field ลงบรรทัดใหม่โดยไม่ Overflow

## Validation and Notification

- Validation ค่าว่างหรือข้อมูลไม่ถูกต้องต้องแสดงข้อความสีแดงใต้ Field ที่เกี่ยวข้อง
- Success/Error Notification ต้องลอยมุมขวาบนของ Content Area ไม่ดัน Layout และไม่บังพื้นที่ข้อมูลหลัก
- Notification ต้องหายอัตโนมัติตาม `TDSTCompanySetUp.TimeAlert` ผ่าน `CompanySetupController` และกดปิดเองได้
- พื้นหลัง Notification ใช้ Primary ของ User Style ความทึบ `50%`; Error ใช้สีแดงได้
- Error ต้องแสดงทั้ง `message` และ `description` ที่ API ส่งกลับมาเมื่อมีค่า

## Delete Confirmation

- ใช้ Pattern เดียวกันทั้งระบบ: Icon ถังขยะสีแดง, Caption ใช้มาตรฐานกลางสีดำ `18px`/`FontWeight.w700`, กล่องข้อความพื้นแดงอ่อนที่แสดง Key/ชื่อรายการ และข้อความว่าเรียกคืนไม่ได้
- ปุ่ม `ยกเลิก` เป็น TextButton สี Primary ของ User Style
- ปุ่ม `ลบ` เป็น Filled สีแดงพร้อม Icon ถังขยะ
- Popup ยืนยันลบไม่มีเส้นกรอบรอบนอก

## Prompt สำหรับส่งให้ AI

```text
ปรับ Popup/Dialog/Alert นี้ตาม docs/standards/UX_UI_STANDARD.md, POPUP_UI_STANDARD.md และ TYPOGRAPHY_STANDARD.md เอาเส้นกรอบรอบนอกออก Caption สีดำ 18px Icon ใช้สี Primary มีเส้นเทาอ่อนใต้ Caption และก่อนปุ่ม TextBox/ComboBox มุมโค้ง 4px Validation สีแดงใต้ Field ปุ่มด้านล่างสูง 48px มุมโค้ง 4px และใช้สี User Style ส่วน Delete Confirm ใช้ Pattern สีแดงกลางของระบบ Notification ต้องลอยมุมขวาบนและหายตาม TimeAlert ห้ามแก้ API, SQL, Repository หรือ Business Logic ตรวจ Responsive, Overflow, dart format และ dart analyze
```
