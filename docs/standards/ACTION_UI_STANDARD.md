# LAOO Action Screen Standard

มาตรฐานนี้ใช้กับหน้า Add, Edit และ View ที่เป็น Action Screen ลูกของหน้า CRUD (`ScreenType = 1`) โดยต้องออกแบบตาม Action Style นี้เสมอ

## Date display

- วันที่ใน Action Form ต้องแสดงเป็น `dd/MM/yyyy` ผ่าน `CompanyDateFormatter` โดยอ่าน `yearFormat` จาก `CompanySetupController`: ตั้งค่า `BE` แสดง พ.ศ. และค่าอื่นแสดง ค.ศ.
- ค่าที่ส่งหรือรับกับ API/Database ยังคงเป็น ISO `yyyy-MM-dd`; ห้ามส่งข้อความวันที่ที่แสดงบนหน้าจอไปแทนค่า Date จริง
- Date Picker ต้องใช้ Locale ให้สอดคล้องกับ `yearFormat` ของ Company Setup

## ScreenType 1: Required Popup Action Style

- หน้า Add/Edit/View ของ CRUD (`ScreenType = 1`) ต้องเปิดเป็น Popup Action Form เหนือหน้า List; ห้ามเปลี่ยนไปเป็นหน้าเต็ม Content Area เว้นแต่พ่ออนุมัติหน้าจอนั้นโดยตรง
- พื้นผิวกรอบหน้า Action, Header Card และ Form Card เป็นสีขาว ขอบมุมโค้ง `LaooRadius.xs` (`4px`); พื้นที่ Workspace รอบนอกยังใช้ Theme กลาง
- Caption เป็นสีดำตาม `LaooColors.pageCaption` และมี Icon ด้านหน้าใช้สี Primary ของ User ที่ Login
- ปุ่ม Action ทุกปุ่มต้องกำหนดมุมโค้ง `LaooRadius.xs` (`4px`) อย่างชัดเจน ห้ามใช้มุมทรงแคปซูลหรือค่าเริ่มต้นของ Widget ที่ต่างจากมาตรฐาน
- TextBox และ ComboBox ทุกช่องต้องมี `OutlineInputBorder` ครบรอบช่อง เส้นสีเทาจางจาก `LaooColors.border`/Neutral Border Token และมุมโค้ง `LaooRadius.xs` (`4px`) เสมอ ห้ามใช้ Underline, Borderless หรือกรอบสี Primary ในสถานะปกติ
- เมื่อ Focus ให้กรอบ, Floating Label, Cursor และ Selection ใช้ Primary จาก User Profile Theme; เมื่อ Disabled ใช้ Disabled/Neutral Token และเมื่อ Validation Error ใช้ Error Token โดยทุกสถานะต้องคงกรอบรอบช่องและมุมโค้ง `4px`
- Icon, Switch, Checkbox, Radio, Selected Item และปุ่ม Action ที่เป็นสีเอกลักษณ์ต้องอ่าน Semantic Color จาก User Profile Theme ห้ามกำหนดสี Primary แบบ hardcode ภายในหน้าจอ
- หน้า View ใช้รูปแบบเดียวกัน โดยแสดงข้อมูลแบบอ่านอย่างเดียวและแสดง Action ตาม Permission
- การสร้างหรือแก้หน้า Action ต้องตรวจข้อกำหนดชุดนี้ทุกครั้ง; ข้อยกเว้นเฉพาะหน้าต้องมีคำสั่งจากพ่อระบุชัดเจน

## Flow

- Action Screen ต้องสืบทอด `MenuCode`, `ScreenType` และ Permission Context จากหน้าจอแม่
- งาน Form หลาย Field ของ `ScreenType = 1` อยู่ใน Popup เดียว ไม่สร้าง Shell หรือ Route ใหม่; Popup ต้องแบ่งเป็น Header, Scrollable Content และ Footer โดยเลื่อนเฉพาะ Content เมื่อพื้นที่ไม่พอ ห้ามให้ Footer บัง Field หรือ ComboBox ด้านล่าง
- ตรวจ ActionCode, Flow และปลายทางหลัง Save/Cancel จาก Feature Specification ก่อนแก้ไข
- ปุ่มและความสามารถต้องแสดงตาม ScreenType และ Permission

## Header Card

- Header เป็น Card สีขาวเต็มความกว้าง ไม่มีเส้นกรอบ และมุมโค้ง `4px`
- Caption อยู่ด้านซ้าย และปุ่ม Icon ดาวอยู่ถัดจาก Caption ใช้สี Primary ของ User Style โดยต้องกดเพิ่ม/นำออกจากเมนูลัดของผู้ Login ได้
- Caption ใช้รูปแบบ `{MenuName} > {Action}` และใช้มาตรฐานกลาง `fontSize: 18`, `fontWeight: FontWeight.w700`, `color: Colors.black` ตาม `TYPOGRAPHY_STANDARD.md`
- ปุ่ม `ยกเลิก` และ `บันทึก` อยู่ด้านล่างขวาของ Popup หลังเส้นคั่น
- ปุ่มยกเลิกเป็น Outlined Primary; ปุ่มบันทึกเป็น Filled Primary; มุมโค้ง `4px`
- แสดงชุดปุ่ม Action เพียงชุดเดียวด้านล่างของ Popup ห้ามซ้ำที่ Caption
- มีเส้น `LaooColors.border` ยาวใต้ Header ภายใน Card พอดี

## Form Card

- Form อยู่บนพื้นสีขาวภายใน Popup มุมโค้ง `LaooRadius.xs` (`4px`) เต็มความกว้างและใช้เส้น `LaooColors.border` สีเทาจางคั่น Header/Content/Footer; Popup ทั่วไปไม่มีเส้นกรอบรอบนอก
- Padding ใช้ `LaooLayout.cardPadding`; ระยะห่างระหว่างแถว Field ใช้ `LaooLayout.popupFieldSpacing` (`16px`)
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
ปรับหน้า Action ของ ScreenType = 1 เป็น Popup สีขาว แบ่ง Panel เมื่อมีหลาย Field ตาม ACTION_UI_STANDARD.md และ POPUP_UI_STANDARD.md Caption เป็น {MenuName} > {Action} สีดำ 18px Icon ตาม User Style ปุ่มยกเลิก/บันทึกอยู่ด้านล่างขวาชุดเดียว Font ปุ่ม 13px สูง 48px ช่องกรอก 14px TextBox/ComboBox ต้องมีกรอบเทาจางแบบ Outline และมุมโค้ง 4px ทุกสถานะ สี Focus/Icon/Selection/Action อ่านจาก User Profile Theme ปุ่มมุมโค้ง 4px ระยะระหว่างแถว 16px ตรวจ Responsive, Overflow, dart format และ dart analyze ไม่เปลี่ยน Business Logic เว้นแต่ได้รับคำสั่ง
```
