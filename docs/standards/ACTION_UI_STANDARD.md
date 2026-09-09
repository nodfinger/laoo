# LAOO Action Screen Standard

มาตรฐานนี้ใช้กับหน้า Add, Edit และ View ที่เป็น Action Screen ลูกของหน้า CRUD (`ScreenType = 1`) โดยต้องออกแบบตาม Action Style นี้เสมอ

## ScreenType 1: Required Action Style

- หน้า Add/Edit/View ใช้ Action Screen ภายใน Content Area ของ Shared Workspace; ใช้ Header Card และ Form Card ตามข้อกำหนดนี้ ไม่ใช้ Popup เป็นค่าเริ่มต้น
- พื้นผิวกรอบหน้า Action, Header Card และ Form Card เป็นสีขาว ขอบมุมโค้ง `LaooRadius.xs` (`4px`); พื้นที่ Workspace รอบนอกยังใช้ Theme กลาง
- Caption เป็นสีดำตาม `LaooColors.pageCaption` และมี Icon ด้านหน้าใช้สี Primary ของ User ที่ Login
- ปุ่ม Action ทุกปุ่มต้องกำหนดมุมโค้ง `LaooRadius.xs` (`4px`) อย่างชัดเจน ห้ามใช้มุมทรงแคปซูลหรือค่าเริ่มต้นของ Widget ที่ต่างจากมาตรฐาน
- TextBox และ ComboBox ทุกช่องต้องมี `OutlineInputBorder` เส้นสี `LaooColors.border` มุมโค้ง `LaooRadius.xs` (`4px`); เมื่อ Focus ใช้สี Primary ของ User และคงมุมโค้ง `4px` ในทุกสถานะ รวม Disabled และ Validation Error
- หน้า View ใช้รูปแบบเดียวกัน โดยแสดงข้อมูลแบบอ่านอย่างเดียวและแสดง Action ตาม Permission
- การสร้างหรือแก้หน้า Action ต้องตรวจข้อกำหนดชุดนี้ทุกครั้ง; ข้อยกเว้นเฉพาะหน้าต้องมีคำสั่งจากพ่อระบุชัดเจน

## Flow

- Action Screen ต้องสืบทอด `MenuCode`, `ScreenType` และ Permission Context จากหน้าจอแม่
- งาน Form หลาย Field ต้องเปิดเต็ม Content Area ภายใน Shared Workspace ห้ามใช้ Popup และห้ามสร้าง Shell ใหม่
- ตรวจ ActionCode, Flow และปลายทางหลัง Save/Cancel จาก Feature Specification ก่อนแก้ไข
- ปุ่มและความสามารถต้องแสดงตาม ScreenType และ Permission

## Header Card

- Header เป็น Card สีขาวเต็มความกว้าง ไม่มีเส้นกรอบ และมุมโค้ง `4px`
- Icon ดาวอยู่ซ้ายสุดและใช้สี Primary; Caption อยู่ชิดถัดจากดาว
- Caption ใช้รูปแบบ `{MenuName} > {Action}` และใช้มาตรฐานกลาง `fontSize: 18`, `fontWeight: FontWeight.w700`, `color: Colors.black` ตาม `TYPOGRAPHY_STANDARD.md`
- ปุ่ม `ยกเลิก` และ `บันทึก` อยู่ขวาของ Caption ในบรรทัดเดียวกัน
- ปุ่มยกเลิกเป็น Outlined Primary; ปุ่มบันทึกเป็น Filled Primary; มุมโค้ง `4px`
- แสดงปุ่ม Action เฉพาะด้านบนของ Form เท่านั้น ห้ามมีชุดปุ่มบันทึก/ยกเลิกซ้ำด้านล่าง
- มีเส้น `LaooColors.border` ยาวใต้ Header ภายใน Card พอดี

## Form Card

- Form อยู่ใน Card สีขาว มุมโค้ง `LaooRadius.xs` (`4px`) เต็มความกว้างและจัดติดกับ Header Card โดยใช้เส้นสีเทาอ่อนคั่น
- Padding ใช้ `LaooLayout.cardPadding`; ระยะห่างระหว่างแถว Field เท่ากับ `12px`
- หัวข้อย่อยเป็นสีดำ ส่วน Icon ของหัวข้อใช้ Primary ตาม User Style
- ช่อง `สถานะ` อยู่บนสุดก่อน Field อื่น และข้อความกับ Switch อยู่ติดกัน
- TextBox/ComboBox ทุกช่องใช้ `OutlineInputBorder` ตาม Required Action Style ด้านบน ไม่ใช้เพียงเส้นใต้
- Field ในแถวเดียวกันต้องกว้างสมดุล; เมื่อหน้าจอแคบให้ย้ายลงบรรทัดใหม่โดยไม่ Overflow
- Field บังคับมี `*`; เมื่อข้อมูลว่างหรือไม่ถูกต้องให้แสดงข้อความ Validation สีแดงใต้ Field ห้ามใช้ Alert กลางจอแทน Field Validation
- Label และ Focus Border ใช้ Primary ตาม User Style

## Buttons and Result

- ปุ่มใช้ Font `13px`, สูง `48px` จาก `LaooTypography.buttonHeight` และจัด Icon/ข้อความกึ่งกลางแนวตั้ง
- หลังทำรายการสำเร็จต้องแสดง Success Notification ตาม `POPUP_UI_STANDARD.md` และคง Flow เดิม
- Error ต้องแสดง `message` และ `description` จาก API หากมี ห้ามเหลือเพียง `ApiException(500)`

## Prompt สำหรับส่งให้ AI

```text
ปรับหน้า Action นี้ตาม docs/standards/UX_UI_STANDARD.md, ACTION_UI_STANDARD.md และ TYPOGRAPHY_STANDARD.md ใช้ Header Card และ Form Card สีขาวเต็มความกว้างและจัดติดกัน Caption เป็น {MenuName} > {Action} สีดำ 18px ดาวอยู่ซ้าย ปุ่มยกเลิก/บันทึกอยู่ด้านขวาเฉพาะด้านบนเท่านั้น Form ใช้ TextBox/ComboBox มุมโค้ง 4px ระยะระหว่างแถว 12px แสดง Validation สีแดงใต้ Field และใช้สี Primary ตาม User Style ห้ามแก้ API, SQL, Repository หรือ Business Logic ตรวจ Responsive, Overflow, dart format และ dart analyze
```
