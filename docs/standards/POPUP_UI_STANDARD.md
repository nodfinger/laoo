# LAOO Popup, Dialog and Alert Standard

มาตรฐานนี้ใช้กับ Popup, Dialog, Lookup, Confirm และ Notification ทุกหน้าจอ

## Scope

- ใช้ Popup สำหรับ Confirm Delete, Confirm Action, Lookup, จัดการ Master และ Action Form ของ CRUD (`ScreenType = 1`)
- Action Form ของ `ScreenType = 1` ใช้ Popup เป็นมาตรฐาน แม้มีหลาย Field; ScreenType อื่นใช้ Popup ได้เมื่อ Feature Specification หรือพ่อกำหนด

## Form Popup Layout

### 1. Popup Container

- Popup ทุกชนิดใช้พื้นหลังสีขาว (`Colors.white`) และห้ามเปลี่ยนสีพื้นหลังตาม User Style
- Popup ทั่วไปไม่มี `BorderSide` หรือเส้นกรอบรอบนอก ยกเว้น Popup ยืนยันลบที่ต้องมีเส้นกรอบสี Error/Delete ตาม `alertdelete.md`
- กรอบ Popup ใช้มุมโค้ง `LaooRadius.xs` (`4px`) ทุกมุม
- Desktop ใช้ความกว้างสูงสุด `480px`; Mobile ใช้ความกว้างเท่าพื้นที่จอหลังเว้นซ้ายและขวาด้านละ `LaooLayout.dialogInsetPadding` (`24px`)
- ความกว้างและความสูงต้องไม่เกินพื้นที่หน้าจอหลังหัก Inset Padding และ Safe Area
- โครงสร้างภายในต้องแบ่งเป็น `Header / Scrollable Content / Footer`; เมื่อเนื้อหายาวให้เลื่อนเฉพาะ Content โดย Header และ Footer ต้องคงอยู่ มองเห็น และไม่ทับหรือบัง Field
- ข้อยกเว้นที่อนุมัติ: Popup ข้อมูลสินค้าใช้ความกว้างสูงสุด `1100px` ไม่เกินพื้นที่จอหลังหัก Inset แบ่งข้อมูลเป็น Panel และยังต้องใช้โครงสร้าง Header/Scrollable Content/Footer เดียวกัน

### 2. Caption and Header

- Header สูงขั้นต่ำ `LaooLayout.popupHeaderMinHeight` (`48px`) และใช้ Padding ภายใน `LaooLayout.cardPadding` (`10px`)
- ต้องมี Icon ขนาดประมาณ `24px` อยู่ด้านหน้า Caption และใช้สี Primary จาก User Profile Theme
- Caption ใช้รูปแบบ `{MenuName} > {Action}` โดย `MenuName` อ่านจาก Navigation Resolver/`TDADMainMenu`
- Caption ใช้ `fontSize: 18`, `fontWeight: FontWeight.w700`, `color: Colors.black` และ Font จาก Theme กลาง
- ใต้ Header ต้องมี Divider ยาวเต็มพื้นที่ หนา `1px` สี `LaooColors.border`
- Popup ลบเป็นข้อยกเว้น: Icon และ Caption ใช้สี Error/Delete ตาม `alertdelete.md`

### 3. Scrollable Form Content

- Content ใช้ Padding `LaooLayout.cardPadding` (`10px`) และต้องอยู่ใน `Flexible`/`Expanded` ร่วมกับ Scroll View เพื่อไม่ให้ Footer บัง Field หรือ ComboBox ด้านล่าง
- ระยะห่างแนวตั้งระหว่าง Field ใช้ `LaooLayout.popupFieldSpacing` (`16px`)
- Section Title เช่น `คำถาม` ใช้ `16px`, น้ำหนัก `FontWeight.w600` ถึง `FontWeight.w700`; ข้อความทั่วไปใช้ `14px`
- Floating Label ใช้ `14px`; Hint, Validation และ Counter ใช้ `12px`; Font ทั้งหมดใช้ `NotoSansThai` จาก Theme กลาง
- Field บังคับต้องแสดง `*` และ Validation ต้องแสดงสี Error ใต้ Field ที่ผิด
- Context Bar ที่แสดงรายการแม่/ห้อง/อาคารที่เลือก ใช้พื้น Primary แบบโปร่งแสงและข้อความขนาด `16px`
- เมื่อ Popup แคบต้องจัด Field ลงบรรทัดใหม่โดยไม่ Overflow และต้องตรวจทั้งข้อความไทยยาว, Text Scale และ Keyboard/Viewport ที่ลดความสูง

### 4. TextBox and ComboBox

- TextBox/ComboBox ทุกช่องต้องใช้ `OutlineInputBorder` ครบรอบช่องในสถานะ Normal, Focus, Error และ Disabled พร้อมมุม `LaooRadius.xs` (`4px`) เสมอ; ห้ามใช้ Underline, Borderless หรือปล่อยรูปทรงตามค่าเริ่มต้นของ Widget
- สถานะ Normal ใช้เส้นกรอบสีเทาจางจาก `LaooColors.border`/Neutral Border Token ห้ามใช้สี Primary
- สถานะ Focus ใช้กรอบ, Floating Label, Cursor และ Selection สี Primary จาก User Profile Theme; Error ใช้ Error Token; Disabled ใช้ Disabled/Neutral Token โดยยังคงกรอบเทาจางและมุม `4px`
- ข้อความที่กรอกและข้อความที่เลือกใช้ `LaooTypography.inputText` / `LaooTypography.comboBox` ขนาด `14px`; Floating Label ที่เห็นจริงใช้ `14px` ผ่าน `materialFloatingLabelSource`
- ComboBox ต้องมีลูกศรด้านขวา รายการต้องมี Value ไม่ว่างและไม่ซ้ำ และข้อความต้อง Ellipsis/Wrap ตามพื้นที่โดยไม่ Overflow
- ช่องหลายบรรทัดต้องกำหนด `maxLines` และแสดง Counter เมื่อ Feature ต้องจำกัดจำนวนอักษร
- Combo Popup, Dropdown Menu, Selected Item, Icon และ Action Button ต้องใช้ Semantic Color จาก User Profile Theme ห้าม hardcode สี Primary รายหน้าจอ

### 5. Detail Rows

- รายการ Detail เช่นคำถามใช้ชื่อ `ข้อ 1` ขนาด `16px`, น้ำหนัก `FontWeight.w600`
- ปุ่มลบอยู่ด้านขวาและใช้ Error/Delete Token; แต่ละ Detail Row ห่างกัน `16px`
- ปุ่ม `เพิ่มคำถาม` เป็น Outlined Button ใช้ Primary จาก User Profile Theme และมุม `4px`
- บนหน้าจอแคบ Action ของ Detail ต้องย้ายบรรทัดหรือย่อพื้นที่อย่างเหมาะสม ห้ามซ้อนกับข้อความหรือเกิด Overflow

### 6. Footer and Action Area

- Footer ต้องอยู่นอก Scrollable Content และคงมองเห็นที่ด้านล่างของ Popup
- ก่อน Footer ต้องมี Divider ยาวเต็มพื้นที่ หนา `1px` สี `LaooColors.border`
- Footer ใช้ Padding `LaooLayout.cardPadding` (`10px`); ปุ่มชิดขวาและห่างกัน `8px`
- ปุ่มใช้ Font `13px`, น้ำหนัก `FontWeight.w600` ถึง `FontWeight.w700`, สูง `LaooTypography.buttonHeight` (`48px`) และมุม `LaooRadius.xs` (`4px`)
- ปุ่ม `ยกเลิก` กว้างขั้นต่ำ `84px` ใช้ Outlined Primary; ปุ่ม `บันทึก` กว้างขั้นต่ำ `100px` ใช้ Filled Primary พร้อม Icon
- ต้องกำหนด `RoundedRectangleBorder(borderRadius: BorderRadius.circular(LaooRadius.xs))` ใน Style ของปุ่มโดยตรง ห้ามปล่อยให้รับรูปทรง Pill จาก Theme
- ขณะบันทึกต้อง Disable Action ที่ทำให้ส่งซ้ำ แสดงสถานะกำลังบันทึก และยังต้องเปิดให้ผู้ใช้เห็นผล Validation ที่เกิดขึ้น
- สีปุ่ม, Icon และ Focus อ่านจาก User Profile Theme; สีสถานะ Error/Delete/Warning ใช้ Semantic Status Token

### 7. Save Flow and Permission

- ก่อนแสดงหรือเรียก Action ต้องตรวจทั้ง `ScreenType` และ Permission; Backend ต้องตรวจ Permission ซ้ำ
- หลังบันทึกสำเร็จให้แสดง Overlay Notification มุมขวาบนและหายอัตโนมัติตาม `TDSTCompanySetUp.TimeAlert`
- Action `เพิ่ม`: ล้างค่ากรอกทั้งหมด กลับสู่ค่าเริ่มต้นของ Form และคง Popup เปิดไว้เพื่อเพิ่มรายการถัดไป
- Action `แก้ไข`: ปิด Popup หลังบันทึกสำเร็จแล้วโหลดข้อมูลรายการใหม่อัตโนมัติ
- Action อื่นให้ใช้ Flow ที่ Feature Specification กำหนด ห้ามเปลี่ยน Form เพิ่มเป็นโหมดแก้ไขเอง

### Date Picker

- Date Picker ถือเป็น Popup และต้องใช้พื้นขาวทั้ง Header และ Calendar, ไม่มี Surface Tint หรือกรอบนอก, มุม `LaooRadius.xs` (`4px`)
- สีวันที่เลือก, วันนี้, ไอคอนเปลี่ยนเดือน และปุ่มยกเลิก/ตกลง ต้องอ้าง Primary ของ User Style; ข้อความใช้สีมาตรฐานของระบบ ห้ามคงพื้น Header สีเทาหรือสีจาก Material Theme เดิม
- Typography ของ Header, วันในปฏิทิน และปุ่มต้องอ้าง TextTheme/LaooTypography กลาง ห้ามกำหนดขนาด Font เฉพาะ Date Picker

## Validation and Notification

- Validation ค่าว่างหรือข้อมูลไม่ถูกต้องต้องแสดงข้อความสีแดงใต้ Field ที่เกี่ยวข้อง
- Success/Error Notification ต้องลอยมุมขวาบนของ Content Area ไม่ดัน Layout และไม่บังพื้นที่ข้อมูลหลัก
- Notification ต้องหายอัตโนมัติตาม `TDSTCompanySetUp.TimeAlert` ผ่าน `CompanySetupController` และกดปิดเองได้
- พื้นหลัง Notification ใช้ Primary ของ User Style ความทึบ `50%`; Error ใช้สีแดงได้
- Error Notification ทุกจุดต้องแสดงอย่างน้อย 2 ส่วน: ข้อความหลัก (`message`) และ `รายละเอียดเพิ่มเติม` ที่อธิบายสาเหตุหรือสิ่งที่ผู้ใช้ควรทำต่อ
- หน้าจอที่รับ `ApiException` ต้องแยกข้อความหลักออกจากรายละเอียดที่ฝังอยู่ใน `message` ก่อนแสดงผล เพื่อให้มีบรรทัด `รายละเอียดเพิ่มเติม` เสมอและไม่แสดงข้อความซ้ำ
- ห้ามแสดงเพียง `เกิดข้อผิดพลาดในการเรียก API`, ชื่อ Exception, Stack Trace หรือรหัส HTTP โดยไม่มีคำอธิบาย
- ถ้า API ส่ง `description`, `detail` หรือ Validation `errors` ให้แสดงข้อมูลนั้นใต้ข้อความหลักโดยไม่แสดงซ้ำ
- ถ้า API ไม่ส่งคำอธิบาย ให้ HTTP Client เติมข้อความสำรองตามสถานะ เช่น Session หมดอายุ, ไม่มีสิทธิ์, ไม่พบข้อมูล, ข้อมูลขัดแย้ง, Timeout หรือ Server ขัดข้อง
- ข้อความสำหรับผู้ใช้ต้องไม่เปิดเผย SQL, Connection String, Secret, Stack Trace หรือรายละเอียดภายในระบบ

## Delete Confirmation

- ใช้ Pattern เดียวกันทั้งระบบ: Icon ถังขยะและ Caption สี Error/Delete (`18px`/`FontWeight.w700`), กล่องข้อความพื้นแดงอ่อนที่แสดง Key/ชื่อรายการ และข้อความว่าเรียกคืนไม่ได้
- ปุ่ม `ยกเลิก` เป็น TextButton สี Primary ของ User Style
- ปุ่ม `ลบ` เป็น Filled สีแดงพร้อม Icon ถังขยะ
- Popup ยืนยันลบต้องมีเส้นกรอบรอบนอกสี Error/Delete ตาม `alertdelete.md` โดยพื้นหลังยังเป็นสีขาว

## Prompt สำหรับส่งให้ AI

```text
ปรับ Popup/Dialog/Alert นี้ตาม docs/standards/UX_UI_STANDARD.md, POPUP_UI_STANDARD.md และ TYPOGRAPHY_STANDARD.md ใช้พื้นขาว มุม 4px และไม่มีกรอบรอบนอก ยกเว้น Delete Confirm ที่มีกรอบ Error/Delete; Desktop กว้างไม่เกิน 480px และ Mobile เว้นขอบข้าง 24px แบ่งโครงสร้างเป็น Header / Scrollable Content / Footer โดยตรึง Header และ Footer ไม่ให้เลื่อนหรือบัง Field Caption สีดำ 18px w700 พร้อม Icon 24px สี Primary และ Divider สี LaooColors.border ใต้ Header/ก่อน Footer TextBox/ComboBox ใช้ Outline สีเทาจาง มุม 4px ข้อความ 14px Label 14px Hint/Validation 12px และ Value ต้องไม่ว่างหรือซ้ำ ปุ่มสูง 48px Font 13px มุม 4px ยกเลิกขั้นต่ำ 84px บันทึกขั้นต่ำ 100px สีทั้งหมดอ่านจาก User Profile Theme ขณะบันทึกต้องป้องกันการกดซ้ำ Action เพิ่มให้ล้าง Form และคง Popup ไว้ Action แก้ไขให้ปิด Popup Notification ลอยมุมขวาบนและหายตาม TimeAlert ตรวจ ScreenType, Permission, Responsive และ Overflow ห้ามแก้ API, SQL, Repository หรือ Business Logic โดยไม่มีคำสั่ง
```
