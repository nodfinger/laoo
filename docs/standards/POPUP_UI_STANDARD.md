# LAOO Popup, Dialog and Alert Standard

มาตรฐานนี้ใช้กับ Popup, Dialog, Lookup, Confirm และ Notification ทุกหน้าจอ

## Scope

- ใช้ Popup สำหรับ Confirm Delete, Confirm Action, Lookup, จัดการ Master และ Action Form ของ CRUD (`ScreenType = 1`)
- Action Form ของ `ScreenType = 1` ใช้ Popup เป็นมาตรฐาน แม้มีหลาย Field; ScreenType อื่นใช้ Popup ได้เมื่อ Feature Specification หรือพ่อกำหนด
- ข้อยกเว้นเฉพาะหน้า Action เพิ่ม/แก้ไข Partner: ให้ใช้หน้า Action แบบเต็มตามที่พ่อกำหนด ไม่ใช้ Popup; Popup ประเภทอื่นของหน้า Partner ยังใช้มาตรฐานตามประเภทนั้น
- ข้อยกเว้นเฉพาะหน้า Action เพิ่ม/แก้ไขลูกค้าของผู้ใช้ประเภท P: ใช้หน้า Action แบบเต็มตามที่พ่อกำหนด ไม่ใช้ Popup และยังใช้สี การ์ด ระยะ และตัวอักษรตามมาตรฐาน Action
- การจัดการข้อมูลจาก `TDSTMaster` ต้องใช้หน้าจอจัดการรหัสพื้นฐานร่วมเดียวกัน โดยส่ง `MasterGroupCode` จากตัวแปรกลางเพื่อเลือกและจำกัดกลุ่มข้อมูล ใช้รูปแบบ List/Card และสีตามหน้ากลุ่มสิทธิ์ ไม่สร้างหน้าจอซ้ำรายกลุ่ม; กรณีค้นหาอย่างเดียวให้ใช้ Popup ค้นหาแบบง่ายตามข้อกำหนดด้านล่าง สิทธิ์และ API ยังคงตรวจตามข้อมูลรหัสพื้นฐานและขอบเขตผู้ Login
- Popup ค้นหาที่เปิดจาก ComboBox ต้องเลือกข้อมูลได้โดยกดแถวใน List หรือกด Card แล้วปิด Popup พร้อมนำค่าที่เลือกกลับไปแสดงใน ComboBox; ปุ่ม Action ภายในรายการยังทำงานแยกตามสิทธิ์ และการปิดโดยไม่เลือกต้องคงค่าเดิม
- ComboBox ที่รองรับการจัดการข้อมูลและผู้ Login ไม่มีสิทธิ์เพิ่ม แก้ไข หรือลบ แต่มีสิทธิ์อ่านเพื่อค้นหาและเลือก ให้แสดง Icon ค้นหา (`Icons.search`) ภายในช่องแทน Icon จัดการ กดเปิด Popup ค้นหาแบบง่ายได้ โดย Icon ใช้สีตาม User Style และมี Tooltip อธิบายการค้นหา
- ตรวจสิทธิ์เพิ่ม แก้ไข และลบของข้อมูลปลายทางจริงก่อนเลือก Icon; ถ้ามีอย่างน้อยหนึ่งสิทธิ์และมีสิทธิ์ดู ให้ใช้ Icon จัดการและจำกัด Action ตามสิทธิ์ หากตรวจสิทธิ์ไม่ได้ให้ใช้โหมดค้นหาอย่างเดียวโดยไม่อนุมานสิทธิ์แก้ไข
- Popup ค้นหาแบบง่ายใช้หน้าค้นหาแผนกเป็นต้นแบบ มี Caption สีดำและ Icon ค้นหาตาม User Style ช่องค้นหากรองรายการทันทีขณะพิมพ์ แสดงชื่อโดยไม่แสดงรหัส และรองรับ Scroll แนวตั้ง มีปุ่มยกเลิก; ไม่แสดงปุ่มเพิ่ม แก้ไข หรือลบ และไม่ให้การค้นหาข้ามขอบเขตข้อมูลหรือสิทธิ์ของผู้ Login
- ช่อง TextBox ค้นหาใน Popup ทุกประเภท รวม Popup กำหนดสิทธิ์และ Popup เลือกข้อมูล ต้องใช้ Typography และสีตาม `TYPOGRAPHY_STANDARD.md` เช่นเดียวกับช่องข้อมูลทั่วไป: ข้อความที่พิมพ์ `LaooTypography.inputText` (`16px`) และ Floating Label/Caption บนช่องที่เห็นจริง `14px` โดยใช้ `LaooTypography.materialFloatingLabelSource` รองรับการขยายข้อความของระบบ ห้ามกำหนดขนาดแยกราย Popup
- เมื่อช่องค้นหามีข้อมูลหรือ Focus ให้ Floating Label และเส้น Focus ใช้สี Primary ตาม User Style ของผู้ Login; สถานะปกติใช้สีข้อความและเส้นกรอบกลาง ส่วน Disabled และ Error ใช้สีสถานะจาก Theme พร้อมกรอบ Outline มุม `4px` ทุกสถานะ ต้องตรวจช่องว่าง มีข้อมูล Focus และ Disabled
- เมื่อ ComboBox อ่านรหัสพื้นฐานและผู้ Login ไม่มีสิทธิ์ Action เพิ่ม แก้ไข หรือลบ ให้ใช้ Popup ค้นหาแบบง่ายซึ่งมีช่องค้นหาแบบ TextChange และรายการที่เลือกได้เท่านั้น พร้อมส่วน Caption/ปิดตามมาตรฐาน ไม่แสดงปุ่มจัดการ ทั้งนี้ต้องมีสิทธิ์อ่านข้อมูลประกอบที่จำเป็นตามหน้าต้นทางและไม่ข้ามขอบเขต Company หรือ Permission
- Popup แสดงรูปภาพหรือรูปภาพแนบ ต้องมี Icon สื่อถึงรูปภาพอยู่ด้านซ้ายก่อน Caption โดยใช้สี Primary ตาม User Style ของผู้ Login ส่วน Caption ใช้สีดำตามมาตรฐาน Popup มีเส้นแบ่งใต้ Caption และก่อนแถวปุ่มปิด โดยใช้สีเส้นกลางและระยะห่างตามมาตรฐาน Header และ Footer ด้านล่าง เนื้อหารูปเลื่อนได้เมื่อพื้นที่ไม่พอ

## ต้นแบบ Popup Action ส่วนกลาง

- ใช้ Popup `รหัสพื้นฐาน > จังหวัด > เพิ่ม` จาก `_MasterDataForm` ใน `lib/features/support/master_data/pages/master_data_page.dart` เป็นภาพอ้างอิงสำหรับ Popup Action เพิ่ม/แก้ไข/ดู ทุกระบบ โดยปรับ Caption, Field และ Action ตามงานจริง ไม่คัดลอกข้อมูลจังหวัดไปใช้ทุกหน้า
- ตัวอย่างอ้างอิงจากโค้ดใช้ Dialog กว้างไม่เกิน `480px`, inset รอบจอ `24px`, มุม `4px`, พื้นขาว และ Padding ภายใน `10px` ค่าเป็น Flutter logical pixels; ขนาดในภาพหน้าจออาจต่างตามการ Scale
- Header สูงขั้นต่ำ `48px` มี Icon ประมาณ `24px` ห่าง Caption `10px`; Caption ขนาด `18px` น้ำหนัก `w700`; ระยะจาก Header ถึง Divider `10px` และจาก Divider ถึง Field แรก `12px`
- ช่องข้อมูลเรียงแนวตั้ง ห่างกัน `14px`; ใช้กรอบ Outline มุม `4px`, ข้อความ TextBox `16px` และ ComboBox `14px`, content padding แนวนอน `14px` และแนวตั้ง `12px`; Floating Label ที่มองเห็น `14px`
- ก่อน Footer เว้นระยะ `12px`, มี Divider หนา `1px`, แล้วเว้นอีก `12px`; ปุ่มเรียงชิดขวา ห่างกัน `8px` สูง `48px` มุม `4px` โดยปุ่มยกเลิกเป็น Outline และปุ่มบันทึกเป็น Filled พร้อม Icon
- ต้นแบบนี้ใช้อ้างอิงหน้าตาและระยะ ไม่เปลี่ยน ScreenType, Permission, Field, Validation, วิธีสร้างรหัส หรือพฤติกรรมบันทึกของแต่ละหน้าจอ; ข้อกำหนดสีและขนาดในเอกสารนี้และ `TYPOGRAPHY_STANDARD.md` ยังคงใช้เป็นมาตรฐาน
- ต้นแบบปัจจุบันเลื่อนทั้งฟอร์มเมื่อพื้นที่ไม่พอ แต่ Popup Action ที่สร้างหรือปรับใหม่ต้องตรึง Header และ Footer และให้เลื่อนเฉพาะ Content ตามข้อกำหนดด้านล่าง เพื่อให้ปุ่มไม่ถูกบังบนหน้าจอเล็ก

## Form Popup Layout

### 1. Popup Container

- Popup ทุกชนิดใช้พื้นหลังสีขาว (`Colors.white`) และห้ามเปลี่ยนสีพื้นหลังตาม User Style
- Popup ทั่วไปไม่มี `BorderSide` หรือเส้นกรอบรอบนอก ยกเว้น Popup ยืนยันลบที่ต้องมีเส้นกรอบสี Error/Delete ตาม `alertdelete.md`
- กรอบ Popup ใช้มุมโค้ง `LaooRadius.xs` (`4px`) ทุกมุม
- Popup Action อยู่กึ่งกลางพื้นที่ที่เปิดและมี Modal Barrier สี `ColorScheme.scrim` ความทึบ `54%`; การกดพื้นที่นอก Popup ไม่ปิดฟอร์ม ให้ผู้ใช้กด `ยกเลิก` โดยตรง
- Desktop ใช้ความกว้างสูงสุด `480px`; Mobile ใช้ความกว้างเท่าพื้นที่จอหลังเว้นซ้ายและขวาด้านละ `LaooLayout.dialogInsetPadding` (`24px`)
- ความกว้างและความสูงต้องไม่เกินพื้นที่หน้าจอหลังหัก Inset Padding และ Safe Area
- โครงสร้างภายในต้องแบ่งเป็น `Header / Scrollable Content / Footer`; เมื่อเนื้อหายาวให้เลื่อนเฉพาะ Content โดย Header และ Footer ต้องคงอยู่ มองเห็น และไม่ทับหรือบัง Field
- ข้อยกเว้นที่อนุมัติ: Popup ข้อมูลสินค้าใช้ความกว้างสูงสุด `1100px` ไม่เกินพื้นที่จอหลังหัก Inset แบ่งข้อมูลเป็น Panel และยังต้องใช้โครงสร้าง Header/Scrollable Content/Footer เดียวกัน

### 2. Caption and Header

- Header สูงขั้นต่ำ `LaooLayout.popupHeaderMinHeight` (`48px`) และใช้ Padding ภายใน `LaooLayout.cardPadding` (`10px`)
- ต้องมี Icon ขนาดประมาณ `24px` อยู่ด้านหน้า Caption และใช้สี Primary จาก User Profile Theme
- Icon อยู่ห่าง Caption `10px`; หลัง Header เว้น `10px` ก่อน Divider และหลัง Divider เว้น `12px` ก่อน Field แรก
- Caption ใช้รูปแบบ `{MenuName} > {Action}` โดย `MenuName` อ่านจาก Navigation Resolver/`TDADMainMenu`
- Caption ของ Popup ทุกประเภท รวม Popup กำหนดสิทธิ์และ Popup ยืนยันลบ ใช้ `fontSize: 18`, `fontWeight: FontWeight.w700`, `color: LaooColors.pageCaption` (สีดำ) และ Font จาก Theme กลาง โดยไม่เปลี่ยนตามสี Primary ของผู้ใช้
- ใต้ Header ต้องมี Divider ยาวเต็มพื้นที่ หนา `1px` สี `LaooColors.border`
- Popup ลบใช้ Icon สี Error/Delete ส่วน Caption ยังคงเป็นสีดำ

### 3. Scrollable Form Content

- Content ใช้ Padding `LaooLayout.cardPadding` (`10px`) และต้องอยู่ใน `Flexible`/`Expanded` ร่วมกับ Scroll View เพื่อไม่ให้ Footer บัง Field หรือ ComboBox ด้านล่าง
- ระยะห่างแนวตั้งระหว่างแถว Field ใช้ `LaooLayout.popupFieldSpacing` (`14px`) วัดระหว่างกรอบ โดยต้องเผื่อพื้นที่ข้อความ Validation ไม่ให้ทับช่องถัดไป
- Section Title เช่น `คำถาม` ใช้ `16px`, น้ำหนัก `FontWeight.w600` ถึง `FontWeight.w700`; ข้อความทั่วไปใช้ `14px`
- Floating Label ใช้ `14px`; Hint และ Validation ใช้ `12px`; Font ทั้งหมดใช้ `NotoSansThai` จาก Theme กลาง
- สีตัวอักษรและองค์ประกอบของ Popup ต้องอ่าน Semantic Color จาก Theme กลางของ User ที่ Login ตามบทบาทและสถานะของแต่ละองค์ประกอบ ห้ามกำหนดสีประจำ User แบบ hardcode ในหน้าจอ และต้องเปลี่ยนตาม Style ของ User เมื่อมีการเปลี่ยนค่า
- Switch/Slider สถานะขณะเปิดใช้ Primary ของ User ที่ Login; เมื่อช่องมีข้อมูลให้ Floating Label ใช้ Primary ของ User ที่ Login แม้ช่องไม่ได้ Focus; ช่องที่ Focus ใช้ Primary เช่นเดียวกัน โดยห้ามกำหนดสีตายตัว; Error และ Disabled ใช้ Semantic Token ของสถานะนั้น
- ข้อความ Label ปกติใช้ `LaooTypography.inputLabel` (`16px`); Floating Label ใช้ `LaooTypography.materialFloatingLabelSource` เพื่อให้ขนาดที่วาดจริงเป็น `14px`; ข้อความใน TextBox ใช้ `LaooTypography.inputText` (`16px`)
- Field บังคับต้องแสดง `*` และ Validation ต้องแสดงสี Error ใต้ Field ที่ผิด
- Context Bar ที่แสดงรายการแม่/ห้อง/อาคารที่เลือก ใช้พื้น Primary แบบโปร่งแสงและข้อความขนาด `16px`
- เมื่อ Popup แคบต้องจัด Field ลงบรรทัดใหม่โดยไม่ Overflow และต้องตรวจทั้งข้อความไทยยาว, Text Scale และ Keyboard/Viewport ที่ลดความสูง

### 4. TextBox and ComboBox

- ซ่อนตัวนับจำนวนอักขระใต้ TextBox ใน Popup ทุกช่อง เช่น `20/200`; กรณี Flutter ใช้ `maxLength` ให้ซ่อน Counter ที่แสดง โดยยังคงข้อจำกัดความยาว การตรวจสอบข้อมูล และข้อความ Validation ตามที่ระบบกำหนด

- TextBox/ComboBox ทุกช่องต้องใช้ `OutlineInputBorder` ครบรอบช่องในสถานะ Normal, Focus, Error และ Disabled พร้อมมุม `LaooRadius.xs` (`4px`) เสมอ; ห้ามใช้ Underline, Borderless หรือปล่อยรูปทรงตามค่าเริ่มต้นของ Widget
- สถานะ Normal ใช้เส้นกรอบสีเทาจางจาก `LaooColors.border`/Neutral Border Token ห้ามใช้สี Primary
- สถานะ Focus ใช้กรอบ, Floating Label, Cursor และ Selection สี Primary จาก User Profile Theme; Error ใช้ Error Token; Disabled ใช้ Disabled/Neutral Token โดยยังคงกรอบเทาจางและมุม `4px`
- ข้อความที่กรอกใช้ `LaooTypography.inputText` ขนาด `16px`; ข้อความที่เลือกใน ComboBox ใช้ `LaooTypography.comboBox` ขนาด `14px`; Floating Label ที่เห็นจริงใช้ `14px` ผ่าน `materialFloatingLabelSource`
- ข้อความข้อมูลใน TextBox ใช้ Semantic Text Color ของ Theme ผู้ Login; line height มาตรฐาน `1.5` ของขนาดตัวอักษร (ประมาณ `24px` สำหรับข้อความ `16px`); Padding ภายในแนวนอน `14px` และแนวตั้ง `12px` ต่อด้าน โดยไม่บังคับความสูงรวมตายตัว และช่องหลายบรรทัดขยายตามจำนวนบรรทัด
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
- เว้น `12px` ระหว่าง Field สุดท้ายกับ Divider และระหว่าง Divider กับแถวปุ่ม; ปุ่มมี Padding แนวนอน `16px` และจัด Icon กับข้อความกึ่งกลางแนวตั้ง
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
- สีข้อความ Header, ชื่อเดือน/ปี, วันในสัปดาห์ และวันที่ปกติอ่าน Semantic Text Color จาก Theme ของ User ที่ Login; วันที่เลือกใช้ข้อความสีที่อ่านชัดบนพื้น Primary ส่วนวันที่เลือก, วันนี้, ไอคอนเปลี่ยนเดือน และปุ่มยกเลิก/ตกลงอ้าง Primary ของ User Style ห้ามกำหนดสีประจำ User ตายตัวหรือใช้พื้น Header สีจาก Material Theme เดิม
- กำหนด Date Picker ผ่าน Theme กลาง เพื่อให้ทุกหน้าที่ใช้ Date Picker รับพื้นขาวและสี User Style เดียวกัน ทั้งโหมดปฏิทินและกรอกวันที่; สถานะ Disabled ใช้สี Disabled จาก Theme
- Typography ของ Header, วันในปฏิทิน และปุ่มต้องอ้าง TextTheme/LaooTypography กลาง ห้ามกำหนดขนาด Font เฉพาะ Date Picker

## Validation and Notification

- Validation ค่าว่างหรือข้อมูลไม่ถูกต้องต้องแสดงข้อความสีแดงใต้ Field ที่เกี่ยวข้อง
- Success/Error Notification ต้องลอยมุมขวาบนของ Content Area ไม่ดัน Layout และไม่บังพื้นที่ข้อมูลหลัก
- Notification ต้องหายอัตโนมัติตาม `TDSTCompanySetUp.TimeAlert` ผ่าน `CompanySetupController` และกดปิดเองได้
- พื้นหลัง Notification หลังทำรายการสำเร็จใช้สี Primary ของ User Style ที่ความทึบ `50%` (`alpha: 0.5`); ให้ใช้ `AutoDismissMessage`/`showTimedSnackBar` ส่วนกลางเพื่อรับทั้งสีและระยะเวลาแสดง ห้ามกำหนดความทึบรายหน้าจอ; Error ใช้สี Error จาก Theme และตัวอักษรต้องอ่านได้ชัดเจน
- Error Notification ทุกจุดต้องแสดงอย่างน้อย 2 ส่วน: ข้อความหลัก (`message`) และ `รายละเอียดเพิ่มเติม` ที่อธิบายสาเหตุหรือสิ่งที่ผู้ใช้ควรทำต่อ
- หน้าจอที่รับ `ApiException` ต้องแยกข้อความหลักออกจากรายละเอียดที่ฝังอยู่ใน `message` ก่อนแสดงผล เพื่อให้มีบรรทัด `รายละเอียดเพิ่มเติม` เสมอและไม่แสดงข้อความซ้ำ
- ห้ามแสดงเพียง `เกิดข้อผิดพลาดในการเรียก API`, ชื่อ Exception, Stack Trace หรือรหัส HTTP โดยไม่มีคำอธิบาย
- ถ้า API ส่ง `description`, `detail` หรือ Validation `errors` ให้แสดงข้อมูลนั้นใต้ข้อความหลักโดยไม่แสดงซ้ำ
- ถ้า API ไม่ส่งคำอธิบาย ให้ HTTP Client เติมข้อความสำรองตามสถานะ เช่น Session หมดอายุ, ไม่มีสิทธิ์, ไม่พบข้อมูล, ข้อมูลขัดแย้ง, Timeout หรือ Server ขัดข้อง
- ข้อความสำหรับผู้ใช้ต้องไม่เปิดเผย SQL, Connection String, Secret, Stack Trace หรือรายละเอียดภายในระบบ

## Delete Confirmation

- ใช้ Pattern เดียวกันทั้งระบบ: Icon ถังขยะสี Error/Delete และ Caption สีดำ (`18px`/`FontWeight.w700`), กล่องข้อความพื้นแดงอ่อนที่แสดง Key/ชื่อรายการ และข้อความว่าเรียกคืนไม่ได้
- ปุ่ม `ยกเลิก` เป็น TextButton สี Primary ของ User Style
- ปุ่ม `ลบ` เป็น Filled สีแดงพร้อม Icon ถังขยะ
- Popup ยืนยันลบต้องมีเส้นกรอบรอบนอกสี Error/Delete ตาม `alertdelete.md` โดยพื้นหลังยังเป็นสีขาว

## Prompt สำหรับส่งให้ AI

```text
ปรับ Popup/Dialog/Alert นี้ตาม docs/standards/UX_UI_STANDARD.md, POPUP_UI_STANDARD.md และ TYPOGRAPHY_STANDARD.md ใช้พื้นขาว มุม 4px และไม่มีกรอบรอบนอก ยกเว้น Delete Confirm ที่มีกรอบ Error/Delete; Desktop กว้างไม่เกิน 480px และ Mobile เว้นขอบข้าง 24px แบ่งโครงสร้างเป็น Header / Scrollable Content / Footer โดยตรึง Header และ Footer ไม่ให้เลื่อนหรือบัง Field Caption สีดำ 18px w700 พร้อม Icon 24px สี Primary และ Divider สี LaooColors.border ใต้ Header/ก่อน Footer TextBox/ComboBox ใช้ Outline สีเทาจาง มุม 4px ข้อความ TextBox 16px และ ComboBox 14px Label 14px Hint/Validation 12px และ Value ต้องไม่ว่างหรือซ้ำ ปุ่มสูง 48px Font 13px มุม 4px ยกเลิกขั้นต่ำ 84px บันทึกขั้นต่ำ 100px สีทั้งหมดอ่านจาก User Profile Theme ขณะบันทึกต้องป้องกันการกดซ้ำ Action เพิ่มให้ล้าง Form และคง Popup ไว้ Action แก้ไขให้ปิด Popup Notification ลอยมุมขวาบนและหายตาม TimeAlert ตรวจ ScreenType, Permission, Responsive และ Overflow ห้ามแก้ API, SQL, Repository หรือ Business Logic โดยไม่มีคำสั่ง
```
