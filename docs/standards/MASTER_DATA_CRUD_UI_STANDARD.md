# LAOO Master Data CRUD Reference Standard

เอกสารนี้กำหนดหน้าจอ `รหัสพื้นฐาน` (`MenuCode 05002`, `ScreenType 1`) เป็นหน้าต้นแบบสำหรับหน้าจอ CRUD แบบ List/Table, Card Mode และ Popup Action Form โดยต้องอ่านร่วมกับ `UX_UI_STANDARD.md`, `LIST_CARD_UI_STANDARD.md`, `PAGINATION_UI_STANDARD.md`, `ACTION_UI_STANDARD.md`, `POPUP_UI_STANDARD.md` และ `TYPOGRAPHY_STANDARD.md`

## 1. Screen Contract

- Caption อ่าน `MenuName` จาก Navigation API/`TDADMainMenu`; ตัวอย่างข้อมูลปัจจุบันคือ `รหัสพื้นฐาน`
- `ScreenType = 1` ต้องรองรับ `VIEW`, `CREATE`, `EDIT`, `DELETE` และตรวจ Permission ก่อนแสดงแต่ละ Action
- Layout หลักเรียงจากบนลงล่างเป็น Caption Card, Filter Card, Table/Card Result และ Pagination Card
- Card เชิงโครงสร้างทุกใบต้อง Stretch เต็ม Content Area และมีขอบซ้าย/ขวาตรงกัน
- Workspace ใช้ Margin รอบ Content `10px`; Card แต่ละ Section ห่างกัน `6px`

## 2. Color and Theme Contract

- สี Primary, Surface, Text และ Border ต้องอ่านจาก `workspaceThemeController.value` หรือ `Theme.of(context)` ของ User ที่ Login
- Primary Action, Icon ดาว, Icon แก้ไข, Focus Border, หัวตาราง และหน้าปัจจุบันของ Pagination ใช้ Primary ของ User Style
- พื้น Workspace ใช้ `Theme.of(context).scaffoldBackgroundColor`; พื้น Card/Popup ใช้ Surface ของ User Style
- ข้อความใช้ `textPrimary`/`onSurface`; ข้อความรองใช้ `textSecondary`/`onSurfaceVariant`; เส้นใช้ Border ของ User Style
- Delete และ Error ใช้ `Theme.of(context).colorScheme.error`; ห้ามนำ Primary มาแทน Semantic Error
- ห้ามกำหนด `Colors.green`, `Colors.blue`, Primary Hex, Surface Hex, Text Hex หรือ Border Hex ภายใน Feature Page

## 3. Typography

| ส่วน | ขนาด | น้ำหนัก/หมายเหตุ |
|---|---:|---|
| Caption หน้า/Popup | `18px` | `w700`, line height `1.3` |
| หัวข้อย่อย | `16px` | `w600-w700` |
| Floating Label ที่เห็นจริง | `14px` | ใช้ `LaooTypography.materialFloatingLabelSource` เพื่อชดเชย Material scale |
| TextBox/ComboBox/Table | `14px` | line height `1.45-1.5` |
| ปุ่ม | `13px` | `w600-w700` |
| Validation/หมายเหตุ | `12px` | Semantic Error เมื่อผิดพลาด |

ทุกข้อความใช้ `NotoSansThai` และ Token จาก `LaooTypography`; ห้ามกำหนด Font Family หรือ Font Size ซ้ำใน Feature เมื่อมี Token กลางแล้ว

## 4. Caption Card

- กว้างเต็ม Content Area, Surface ตาม User Style, ไม่มีกรอบและเงา, มุม `4px`
- Padding ซ้าย/ขวา `16px`, บน/ล่าง `14px`; ความสูงภายในไม่น้อยกว่าปุ่ม Action `48px`
- ซ้ายเป็น Caption `18px/w700` และปุ่ม Icon ดาว Primary ที่กดเพิ่ม/นำออกจากเมนูลัดได้อยู่ถัดจาก Caption; ขวาเป็นปุ่มสลับ List/Card และปุ่ม `เพิ่ม`
- ปุ่มสลับ View เป็น Icon Button ขนาด Target อย่างน้อย `48px`, พื้น Primary โปร่ง `10%`, มุม `4px`
- ปุ่ม `เพิ่ม` สูง `48px`, ความกว้างขั้นต่ำ `100px`, Filled Primary, Icon `+`, Font `13px`, มุม `4px`
- ปุ่ม `เพิ่ม` แสดงเมื่อมี `CREATE`; ปุ่มสลับ View ซ่อนเมื่อหน้าจอถูกบังคับเป็น Card Mode
- Caption Card ไม่มีเส้น Divider ด้านล่าง

## 5. Filter Card

- กว้างเต็ม Content Area, Surface ตาม User Style, ไม่มีกรอบและเงา, มุม `4px`, Padding `16px`
- Caption Card กับ Filter Card ห่าง `6px`; Filter กับ Result ห่าง `6px`
- ช่องค้นหากว้าง `280px`; ComboBox กลุ่มข้อมูลกว้าง `280px`
- TextBox/ComboBox ใช้ Outline Border จาก User Style, Focus เป็น Primary, มุม `4px`, ข้อความ `14px`
- ช่องค้นหามี Icon ค้นหาด้านซ้าย ไม่มีปุ่มลูกศรหรือ Refresh ซ้ำด้านขวา; ค้นหาเมื่อกด Enter หรือปุ่ม `ค้นหา`
- ปุ่ม `ค้นหา` เป็น Filled Primary และ `ล้าง Filter` เป็น Outlined Primary; สูง `40px`, Font `13px`, มุม `4px`
- ระหว่าง Control ในกลุ่มเดียวกัน `8px`; ระหว่างกลุ่ม Search Action กับ ComboBox `14px`
- Desktop วางในแถวเดียวเมื่อพื้นที่พอ; พื้นที่แคบจัด Search, ชุดปุ่ม และ ComboBox ลงบรรทัดโดยไม่ Overflow

## 6. Table/List Mode

- ใช้ Table เมื่อ Content Area กว้างตั้งแต่ `900px` และ User ไม่ได้เลือก Card Mode
- Result Card กว้างเต็มพื้นที่, Surface ตาม User Style, ไม่มีกรอบ/เงา, มุม `4px`
- หัวตารางสูง `56px`, พื้น Primary โปร่ง `10%`, ตัวอักษร Primary `14px/w700`
- แถวข้อมูลสูง `48-56px`, ตัวอักษร `14px`; เส้นคั่นแนวนอน `1px` ใช้ Border ของ User Style
- ไม่มีเส้นแนวตั้งและไม่มีกรอบรอบนอก Table
- คอลัมน์แรก `ID`; คอลัมน์ที่สอง `Action` กว้าง `100px` และจัด Icon กึ่งกลาง
- Edit ใช้ Primary; Delete ใช้ Semantic Error; แสดงตาม `EDIT`/`DELETE`
- รองรับ Horizontal Scroll เมื่อคอลัมน์เกินพื้นที่ และตรึงหัวตารางตาม Shared Table Component

## 7. Card Mode

- ใช้อัตโนมัติเมื่อ Content Area แคบกว่า `900px` หรือเมื่อ User เลือก Card Mode
- Card รายการกว้างเต็มพื้นที่, Surface ตาม User Style, ไม่มีกรอบ/เงา, มุม `4px`
- Card แต่ละรายการห่างกัน `6px` พอดี; ใบสุดท้ายไม่มี Bottom Margin
- Padding ภายในซ้าย `16px`, บน `14px`, ขวา `10px`, ล่าง `14px`
- บรรทัดแรกแสดงลำดับ/ID/รหัสด้วย Primary `14px/w700`; ชื่อ `14px/w600`; รหัสย่อ `14px`
- Action อยู่ขวา Edit Primary/Delete Error และต้องไม่บีบข้อความจน Overflow
- Empty Result ใช้ Card รูปแบบเดียวกัน ไม่มีเงา แสดง `ไม่พบข้อมูล` กึ่งกลาง พร้อมคง Pagination Card ด้านล่าง

## 8. Pagination Card

- Result กับ Pagination ห่าง `6px`; Card สูง `56px` พอดี กว้างเต็มพื้นที่ ไม่มีกรอบ/เงา/Divider ภายใน และมุม `4px`
- Padding แนวนอน `12px`; เนื้อหาจัดกึ่งกลางแนวตั้งและชิดซ้าย
- ปุ่ม `<`, เลขหน้า และ `>` ขนาด `34x34px`, มุม `4px`; ระหว่างปุ่ม `6px`
- หน้าปัจจุบัน Filled Primary พร้อมข้อความ `onPrimary`; หน้าอื่น Outlined Primary
- ปุ่มก่อนหน้า/ถัดไปที่ Disabled ใช้ Text และ Border สีรองของ User Style โดยพื้นยังเป็น Surface
- ข้อความ `รายการเริ่มต้น-รายการสุดท้าย จาก จำนวนทั้งหมด` อยู่ห่างจากชุดปุ่ม `12px`, ขนาด `14px`
- ไม่มีข้อมูลแสดง `0-0 จาก 0`; Pagination ยังคงแสดงและไม่ Overflow

## 9. Add/Edit Popup

- Popup กว้างสูงสุด `480px`, Inset รอบจอ `24px`, พื้นสีขาวเสมอ, ไม่มีกรอบ/เงาใน Popup ทั่วไป, มุม `4px`; Popup ยืนยันลบเป็นข้อยกเว้นที่มีกรอบสี Error/Delete
- Padding ภายใน `10px`; เมื่อความสูงไม่พอให้ Scroll ภายใน Popup โดยไม่ Overflow
- Header สูงขั้นต่ำ `48px`; Icon Primary กับ Caption ห่าง `10px`; Caption รูปแบบ `{MenuName} > {กลุ่มข้อมูล} > {Action}` ขนาด `18px/w700`
- มี Divider สี Border ใต้ Header; ระยะจาก Divider ถึง Field แรก `12px`
- TextBox กว้างเต็ม Popup, Outline Border, มุม `4px`, Padding ภายในแนวนอน `14px` แนวตั้ง `12px`
- Floating Label ที่เห็นจริง `14px`; ข้อความกรอก `14px`; Field แต่ละแถวห่างกัน `16px`
- Field Read-only ต้องแยกสถานะด้วยพฤติกรรม ไม่เปลี่ยนเป็นสี Primary จนดูเหมือนแก้ไขได้
- ก่อน Footer มีระยะ `12px`, Divider Border และระยะถึงปุ่ม `12px`
- ปุ่ม Footer ชิดขวาและห่างกัน `8px`; `ยกเลิก` Outlined Primary, `บันทึก` Filled Primary; สูง `48px`, Font `13px`, มุม `4px`
- ระหว่างบันทึกปิดการกดซ้ำและแสดง `กำลังบันทึก...`; Validation อยู่ใต้ Field ที่เกี่ยวข้อง

## 10. Delete Confirmation

- Popup พื้นสีขาว มีกรอบนอกสี Semantic Error/Delete มุม `4px`
- Icon ถังขยะ, Caption `18px/w700` และปุ่มยืนยันใช้ Semantic Error/Delete
- กล่องรายการที่จะลบใช้ Error โปร่ง `10%`; ต้องแสดง Key/ชื่อและข้อความว่าเรียกคืนไม่ได้
- `ยกเลิก` เป็น Text Primary; `ลบ` เป็น Filled Error พร้อม Icon ถังขยะ

## 11. State and Responsive Checklist

- Loading: คง Workspace และแสดง Progress ที่ไม่ทำให้ Layout กระโดด
- Loaded: ตรวจข้อมูลสั้น, ปกติ และข้อความยาว
- Empty/Filtered Empty: แสดงสาเหตุที่เข้าใจได้และ Pagination `0-0 จาก 0`
- Error: แสดงข้อความหลักและรายละเอียดเพิ่มเติม พร้อม Action `ลองใหม่` เมื่อเหมาะสม
- Disabled/Permission: ซ่อน Action ที่ไม่มีสิทธิ์; ปุ่มบันทึก Disabled ระหว่างส่งข้อมูล
- ตรวจ Wide `>=900px`, Compact `<900px`, Mobile, Text Scale ปกติ/ขยาย, Hover, Focus และ Keyboard Navigation

## 12. Implementation Checklist

- [ ] Metadata ยืนยัน `MenuCode`, `MenuName`, `ScreenType`
- [ ] Caption มาจาก Resolver กลาง
- [ ] Permission ครบทุก Action และ Backend ตรวจซ้ำ
- [ ] สี Primary/Surface/Text/Border มาจาก User Style/Theme
- [ ] Caption, Filter, Result, Pagination กว้างเท่ากันและห่าง `6px`
- [ ] Table และ Card Mode มีข้อมูล/Empty state ครบ
- [ ] Pagination สูง `56px` และปุ่ม `34px`
- [ ] Popup Header `48px`, Field gap `16px`, Action `48px`
- [ ] ไม่มี Overflow ที่ Breakpoint `900px`
- [ ] Format Source และตรวจภาพจริงก่อนนำไปใช้กับหน้าจออื่น
