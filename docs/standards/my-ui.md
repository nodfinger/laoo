# my-ui — มาตรฐานหน้าจอ LAOO

ไฟล์นี้เป็นแหล่งข้อกำหนด UI และ Interface เดียวของโครงการ `laoo` เมื่อผู้ใช้กล่าวถึงข้อกำหนดหรือมาตรฐานให้อ่าน `AGENTS.md` ก่อน แล้วอ่านไฟล์นี้ทั้งฉบับเมื่อคำสั่งเกี่ยวกับ UI เช่น `my-ui`, `myui`, `จัดหน้าจอ`, `ตามข้อกำหนด`, `จัดอักษร`, `ตาม user` หรือ `ตาม login` โดย `myui` หมายถึง `my-ui`. เมื่อมีการเปลี่ยนข้อกำหนด UI/Interface ให้ปรับไฟล์นี้ก่อนแก้หน้าจอ ห้ามเก็บข้อกำหนด UI อีกชุดนอกไฟล์นี้. ใช้กับ List, Table, Card, Action, Popup, Lookup, Alert และทุก Project ค่าตัวเลขเป็น Flutter logical pixels. `AGENTS.md` ยังคงเป็นแหล่งกติกา MenuCode, ScreenType, Permission, API และวิธีทำงาน; ไฟล์นี้กำหนดหน้าตาและปฏิสัมพันธ์ ไม่ใช้แทนสิทธิ์หรือ Business Logic.

## 1. เลือกโครงหน้าจอ

| งาน | โครงที่ต้องใช้ |
|---|---|
| หน้ารายการ | Caption Card → Filter Card → Result แบบ Table หรือ Card → Pagination Card แม้ไม่มีข้อมูล |
| เพิ่ม/แก้ไข/ดู ของ `ScreenType = 1` | Action Popup เหนือหน้ารายการเมื่อฟอร์มมีไม่เกิน 10 ช่อง; นับทุกแท็บและทุกส่วนที่บันทึกร่วมกัน ไม่นับปุ่มและช่องค้นหาของหน้า List |
| Action ที่มีเกิน 10 ช่อง | ถามผู้ใช้ให้เลือกระหว่าง Popup กับหน้าเต็ม เว้นแต่ระบุไว้แล้ว; หน้าเต็มใช้ Header Card และ Form Card |
| `ScreenType = 4` เอกสาร Header–Detail | List ตามมาตรฐานนี้; หน้า Action แยก Header กับ Detail และใช้ Flow/สิทธิ์ใน `AGENTS.md` |
| Lookup/เลือกข้อมูล | Popup ค้นหาที่เลือกแถวหรือ Card แล้วคืนค่าให้ช่องต้นทาง |
| ยืนยันลบ | Popup ลบตามหัวข้อ 8 ทุกหน้าจอ รวม Popup ซ้อน |

ก่อนทำ UI ให้ตรวจ `MenuCode`, `MenuName`, `ScreenType`, Action และ Permission ตาม `AGENTS.md`. Caption ใช้ชื่อจาก Navigation Resolver/`TDADMainMenu.MenuName` ไม่ hardcode. หน้าจอที่มี List/Card ต้องตกลงว่าผู้ใช้เลือกแสดงและเรียงคอลัมน์ได้หรือไม่ และตั้ง `TDADMainMenu.AllowListDisplaySettings` พร้อมเชื่อมค่ารายผู้ใช้ทั้ง List/Card และ API. เมื่อเพิ่มหรือลดคอลัมน์ ต้องปรับทะเบียนคอลัมน์และ API โดยรักษาค่าของคอลัมน์เดิมที่ยังอยู่.

## 2. สี พื้นผิว ระยะ และตัวอักษร

- พื้น Workspace ใช้ `LaooColors.background` (`#F8F9FB`); Card ทั่วไปพื้นขาว ไม่มีกรอบสีหรือเงา และมุม `LaooRadius.xs` (`4px`). Popup พื้นขาวเสมอ; Popup ลบมีกรอบ Error/Delete เป็นข้อยกเว้น. ไม่ hardcode `Colors.green`, `Colors.blue` หรือ Primary/Surface/Text/Border Hex ใน Feature Page.
- Primary, Icon, Focus, Selection, Cursor, Switch, Checkbox, Radio และปุ่ม Action อ่านจาก `workspaceThemeController.value`/User Profile Theme ผ่าน Semantic Token กลาง; เปลี่ยน Style แล้วต้องอัปเดตทันทีเฉพาะ User นั้น. Error/Delete/Warning/Disabled ใช้ Semantic Status Token ไม่ใช้ Primary แทน. ข้อความข้อมูลใช้ Semantic Text Color; เส้นคั่นทั่วไปใช้ `LaooColors.border` หรือ Semantic Border ตามชนิดหน้าจอ.
- Content ทั่วไปเว้นขอบบน/ซ้าย/ขวา `LaooLayout.cardMargin` (`10px`); **หน้ารายการ** เว้น `24px` รอบ Content และลดบนจอเล็กเพื่อไม่ให้ Overflow. ห้ามซ้อน Padding ของ Shell กับหน้าจอจนระยะจริงเกินค่า. Card/Section ทั่วไปและ Card รายการห่างกัน `8px` โดยกำหนด margin ของ `Card` เป็นศูนย์เมื่อจำเป็น ไม่พึ่ง default margin. Padding ภายใน Card ทั่วไปใช้ `LaooLayout.cardPadding` (`10px`); ค่าเฉพาะ Caption, Filter, Result และ Pagination อยู่ในหัวข้อถัดไป.
- Font หลัก `NotoSansThai` ที่ Bundle มากับแอป; fallback `Noto Sans Thai`, `Tahoma`, `Arial`. ใช้ `LaooTypography` และ Theme กลาง ไม่กระจาย `fontFamily`/`fontSize` ใน Feature. Caption หลักทุกขนาดจอ `18px`, `w700`, line height ประมาณ `1.3`, สี `LaooColors.pageCaption` (ดำ); ไอคอน Caption ใช้ Primary. หัวข้อย่อย `16px/w600–w700`; Label ทั่วไป `16px`; ข้อความทั่วไปใน Popup/Table/ComboBox `14px`; Hint/Validation/หมายเหตุ `12px`.
- Floating Label ของ TextBox/ComboBox ต้องเห็นจริง `14px` โดยใช้ `LaooTypography.materialFloatingLabelSource` เมื่อ Flutter ย่อ Label. ข้อความ TextBox `LaooTypography.inputText` (`16px`, line height `1.5`); ComboBox/Table `14px`. ตรวจสถานะว่าง มีข้อมูล Focus Disabled และ Error ทั้งช่อง Filter, Action และ Popup. Floating Label เมื่อมีข้อมูลหรือ Focus ใช้ Primary; Disabled ใช้ Disabled Token.
- Button ใช้ `13px/w600–w700`, สูง `LaooTypography.buttonHeight` (`48px`), มุม `4px` และจัดไอคอน/ข้อความกึ่งกลางแนวตั้ง. ข้อยกเว้นคือ Search/ล้าง Filter ซึ่งสูงเท่าช่องค้นหาที่แสดงจริง. ห้าม Letter Spacing ติดลบกับภาษาไทยและห้ามตัดข้อความเมื่อขยาย Text Scale.
- วันที่ที่ผู้ใช้เห็นทุกหน้าเป็น `dd/MM/yyyy` (วันและเดือนสองหลัก), เวลาอยู่ต่อท้ายวันที่. ใช้ `CompanyDateFormatter` และ `yearFormat` จาก `CompanySetupController` (`BE` เป็น พ.ศ., ค่าอื่นเป็น ค.ศ.); Date Picker ใช้ Locale สอดคล้อง. ค่า API/Database คงชนิดและรูปแบบที่ Contract กำหนด ไม่ส่งข้อความแสดงผลแทนวันที่จริง.

## 3. Interface พื้นฐานของหน้า List/Table/Card

ใช้หน้ากลุ่มสิทธิ์ `10003` เป็น Visual Reference และหน้า `05002 รหัสพื้นฐาน` เป็นตัวอย่าง CRUD โดย **ค่าของไฟล์นี้** เป็นมาตรฐานที่ใช้กับทุกระบบ. Caption, Filter, Result, Empty/Error และ Pagination เป็น Card แยกกัน กว้างเต็ม Content Area ขอบซ้าย/ขวาตรงกัน; เว้น `8px` ระหว่าง Section ทุกช่วง. ห้ามให้ Card โครงสร้างหดตามจำนวน Control ด้วย `Center`, `IntrinsicWidth`, `SizedBox(width: …)` หรือ `maxWidth`; กำหนดความกว้างได้เฉพาะ Control ภายใน. ให้ Result แบบ Table รวม Header, ทุกแถว และ Empty state อยู่ใน Card เดียว โดยเว้น `10px` จากขอบ Card ถึงตารางทุกด้าน.

### Caption Card

- ปุ่มคำสั่งทุกปุ่มใน Caption Card ต้องจัดชิดขอบด้านขวาของ Card ภายใน Padding ที่กำหนดเสมอ ทั้งหน้ารายการและหน้าอื่น; เมื่อพื้นที่แคบให้จัดปุ่มขึ้นบรรทัดใหม่โดยยังชิดขวาและไม่ล้น Card.
- Padding ซ้าย/ขวา `16px`, บน/ล่าง `14px`; พื้นขาวเต็มความกว้าง ไม่มีกรอบหรือเงา.
- ซ้ายเรียง `Icon เมนู (24px Primary) → Caption (18px ดำ) → ดาวเมนูลัด`; ระยะ Icon ถึง Caption `8px`. ดาวโปร่ง/ทึบแสดงสถานะจริงของ User และบันทึกผ่านระบบเมนูลัดส่วนกลาง; เมื่อสำเร็จอัปเดตแถบเมนูลัดทันที เมื่อผิดพลาดคืนสถานะเดิม.
- ขวาเรียง `สลับ List/Card → + เพิ่ม`, ห่าง `8px`, จัดกึ่งกลางแนวตั้ง. ปุ่มสลับเป็นสี่เหลี่ยม `48×48px`, Icon `24px` Primary, พื้น Primary โปร่ง `10%`, มุม `4px`; Icon ตารางสี่ช่องหมายถึงกดไป Card และ Icon รายการหมายถึงกดไป List. ซ่อนปุ่มเมื่อพื้นที่บังคับ Card Mode.
- `+ เพิ่ม` เป็น Filled Primary สูง `48px`, Padding แนวนอน `16px`, Font `13px`, Icon บวก, มุม `4px`; แสดงเมื่อ ScreenType และ Permission `CREATE` อนุญาตเท่านั้น. Caption/Action ต้องไม่ล้นบนจอแคบ.

### Filter Card

- Padding `12px`, พื้นขาวเต็มความกว้าง, มุม `4px`, ไม่มีกรอบสี. Control ใช้ `Wrap` หรือ Layout ที่ย้ายบรรทัดได้; ระยะระหว่างช่อง/ปุ่ม `8px`.
- ช่องค้นหามี Icon ค้นหาด้านซ้าย แล้วตามด้วยปุ่ม `ค้นหา` Filled Primary และ `ล้าง Filter` Outlined Primary พร้อม Icon; ปุ่มมุม `4px`, Padding แนวนอน `16px`, Font `13px`. ค้นหาเมื่อกด Enter หรือปุ่มเท่านั้น; ล้างทั้งคำค้นและตัวกรองกลับค่าเริ่มต้นแล้วแสดงข้อมูลใหม่.
- ปุ่มทั้งสองและ ComboBox ในแถวเดียวกันต้อง **สูงเท่าช่องค้นหาที่แสดงจริง** และกึ่งกลางแนวตั้ง; ห้ามสมมติว่า TextBox สูง `48px`. ตัวกรองสถานะกว้าง `170px` เมื่อพื้นที่พอและอยู่หลังชุดปุ่ม; เมื่อแคบให้ Wrap โดยคงลำดับ.
- TextBox/ComboBox ทุกช่องมี `OutlineInputBorder` ครบรอบ มุม `4px`, กรอบปกติสี Neutral/Border Token และ Focus สี Primary; ComboBox มีลูกศรขวาและตัด/Wrap ค่าที่ยาวโดยไม่ Overflow.

### Table/List Result

- เมื่อความกว้างหน้าจอ **ไม่เกิน `600px` ให้แสดง Card เสมอ**; เมื่อกว้างกว่า `600px` ให้ผู้ใช้เลือก List หรือ Card ได้ โดยตารางต้องแสดงข้อมูลครบและรองรับการเลื่อนแนวนอนเมื่อพื้นที่ไม่พอ.
- Header สูง `56px`, พื้น Primary โปร่ง `12%`, ข้อความ Primary `14px/w700`; แถวสูง `48–56px`, ข้อมูล `14px`. มีเส้นแนวนอนใต้ Header และทุกแถวรวมแถวสุดท้าย `0.6px` สี Semantic Border ตาม User Style; ไม่มีเส้นตั้งหรือกรอบนอก. ระยะขอบเซลล์แนวนอน `8px`, ระหว่างคอลัมน์ `20px`; หากตรึงหัวและเลื่อนเนื้อหา เส้นยังต้องเหมือนกัน.
- คอลัมน์แรก `ID` หมายถึงเลขลำดับแถว ไม่ใช่ Primary Key; คอลัมน์ที่สอง `Action`. Caption และ Icon ของ Action ชิดซ้ายและแนวตรงกัน; Edit ใช้ Primary, Delete ใช้ Error/Delete และตรวจ Permission. คอลัมน์ที่มี Icon เช่น `รูป` ให้หัวกับ Icon ในแต่ละแถวชิดซ้ายแนวเดียวกัน.
- ซ่อนรหัสที่ระบบสร้างอัตโนมัติจาก Table และ Card แต่เก็บค่าไว้สำหรับ API, Edit/Delete และ Permission; รหัสที่ผู้ใช้กำหนดเองแสดงได้. Sort เฉพาะคอลัมน์ที่ระบบรองรับ. ข้อมูลยาวใช้ ellipsis/Wrap ตามพื้นที่และยังเข้าถึงรายละเอียดได้.
- สถานะเป็นป้ายมุม `999px`, Padding แนวนอน `10px` แนวตั้ง `4px`; สถานะปกติใช้ Primary กับพื้นโปร่ง `12%`, สถานะไม่ปกติ/ยกเลิกใช้ Semantic Error/Delete กับพื้นโปร่ง `12%`.

### Card Result

- Card รายการพื้นขาว กว้างเต็มพื้นที่ ไม่มีกรอบหรือเงา มุม `4px`, ห่างกัน `8px` พอดี; Padding ซ้าย `14px`, บน `10px`, ขวา `8px`, ล่าง `10px`. ใช้ `ListView.separated`/`GridView` หรือ Layout ที่ได้ช่องว่างจริงเท่ากัน.
- ชื่อหลักอยู่ซ้าย สี Primary น้ำหนัก `w700`; ด้านขวาเรียงสถานะ, Edit, Delete ตาม Permission. เมื่อพื้นที่แคบให้ Wrap/หลายแถวโดยไม่ Overflow. ภาพจริงกดเปิด Popup ดูเต็มและซูมได้ตามสิทธิ์; ภาพแทนเมื่อไม่มีรูปไม่ต้องเปิด Popup.
- เมื่อบังคับ Card ชั่วคราวจากพื้นที่ ไม่บันทึกทับรูปแบบ List/Card ที่ผู้ใช้เลือกไว้; เมื่อกว้างพอให้กลับมุมมองเดิมและแสดงปุ่มสลับอีกครั้ง.

## 4. Pagination

- Pagination Card แยกใต้ Result ห่าง `8px`, กว้างเต็ม Content Area, พื้นขาว ไม่มีกรอบ/Divider, มุม `4px`, **สูงรวมพอดี `LaooLayout.paginationCardHeight` (`56px`)**. Padding แนวนอน `10px` โดยไม่เพิ่มความสูงรวม.
- ชุดปุ่มชิดซ้ายและกึ่งกลางแนวตั้ง: `<`, เลขหน้าปัจจุบัน, `>` ขนาด `LaooLayout.paginationButtonSize` (`36×36px`), มุม `4px`, ห่างกัน `6px`; Chevron `22px`. ข้อความ `รายการเริ่มต้น-รายการสุดท้าย จาก จำนวนทั้งหมด` อยู่ถัดไป `12px`, ห้ามใช้ Spacer ดันไปขวา.
- หน้าปัจจุบันพื้น/กรอบ Primary และข้อความอ่านชัด; เลขหน้าอื่นกรอบ Primary `1px`; ลูกศรที่ใช้งานได้พื้น Primary/Icon ขาว; ปุ่มที่ใช้งานไม่ได้พื้นเทา/Icon เทาเข้ม. ไม่มีข้อมูลแสดง `0-0 จาก 0` และปิดลูกศร แต่ **ยังแสดง Pagination Card**. จอแคบ Wrap ได้โดยคงลำดับและไม่ Overflow; ไม่เปลี่ยน Page Size, Current Page หรือ API.

## 5. Action เพิ่ม/แก้ไข/ดู

- รับ MenuCode, ScreenType, Permission และ Flow จากหน้าแม่. `ScreenType = 1` ใช้ Popup Action ตามเกณฑ์หัวข้อ 1; หากผู้ใช้กำหนดหน้าเต็ม ให้ใช้ Header Card กับ Form Card สีขาวเต็มความกว้าง มุม `4px` และระยะ Card ตามหัวข้อ 2. หน้า View ใช้รูปแบบเดียวกันแต่ข้อมูลอ่านอย่างเดียว.
- Caption รูป `{MenuName} > {Action}`, Icon Primary, ดาวเมนูลัดถัดจาก Caption เมื่อเป็นหน้าเต็ม; ไม่สร้าง Shell หรือ Route ซ้อนเมื่อเป็น Popup. ตรวจ ActionCode, ปลายทางหลัง Save/Cancel และ Permission ก่อนแสดงปุ่ม; Backend ตรวจ Permission ซ้ำ.
- ใน Form ให้ `สถานะ` อยู่ก่อน Field อื่นโดยข้อความกับ Switch อยู่ติดกัน. Field แต่ละแถวห่าง `LaooLayout.popupFieldSpacing` (`14px`); เมื่อพื้นที่แคบย้ายลงบรรทัด ไม่ให้ Overflow. Field บังคับแสดง `*`, Validation สี Error ใต้ช่องนั้น.
- TextBox/ComboBox ทุกสถานะเป็น Outline มุม `4px` กรอบปกติสีเทาจาง; Focus Border/Label/Cursor/Selection สี Primary, Error สี Error, Disabled สี Disabled. ช่องที่เลือกจาก Lookup และอนุญาตค่าว่างมีปุ่มล้างเมื่อมีค่า; ช่องบังคับหรือไม่มีสิทธิ์แก้ไม่แสดงปุ่มล้าง.
- ปุ่ม `ยกเลิก` Outlined Primary และ `บันทึก` Filled Primary พร้อม Icon อยู่ด้านล่างขวาเพียงชุดเดียว; สูง `48px`, Font `13px`, มุม `4px`. ปิดการกดซ้ำระหว่างบันทึกและแสดงกำลังบันทึก. หลังสำเร็จแสดง Notification ตามหัวข้อ 7 และรักษา Flow ของ Feature.

## 6. Popup Action และ Lookup

- Popup ทั่วไปพื้นขาว ไม่มีกรอบนอกหรือ Surface Tint มุม `4px`; Delete Confirm ใช้กรอบ Error/Delete. Desktop กว้างไม่เกิน `480px`; Mobile เว้นซ้าย/ขวาด้านละ `24px`; ขนาดไม่เกินพื้นที่หลังหัก Safe Area/Keyboard. Popup Action อยู่กึ่งกลาง มี scrim `54%`; กดพื้นนอกไม่ปิดฟอร์ม. ใช้ Popup `รหัสพื้นฐาน > จังหวัด > เพิ่ม` ของ `_MasterDataForm` เป็นภาพอ้างอิงด้านระยะ โดยไม่คัดลอก Field หรือ Business Logic.
- โครง `Header / Scrollable Content / Footer`: Header และ Footer ตรึงไว้ เลื่อนเฉพาะ Content. Header สูงอย่างน้อย `48px`, Padding `10px`; Icon `24px` Primary ห่าง Caption `10px`; Caption ดำ `18px/w700`; เว้น `10px` ถึง Divider และ `12px` จาก Divider ถึง Field แรก. Content Padding `10px`, Field ห่าง `14px`.
- TextBox/ComboBox มีกรอบ Outline เทาจาง มุม `4px` ทุกสถานะ, Padding ภายในแนวนอน `14px` แนวตั้ง `12px`, TextBox `16px`, ComboBox `14px`, Floating Label `14px`. ซ่อนตัวนับ `20/200` ใต้ TextBox Popup แต่คงข้อจำกัดและ Validation. ComboBox ต้องมีค่าไม่ว่าง/ไม่ซ้ำและไม่ Overflow.
- Footer มี Divider สี Border; เว้น `12px` ก่อนและหลังเส้น. ปุ่มชิดขวาห่าง `8px`, สูง `48px`, มุม `4px`; ยกเลิก Outlined กว้างขั้นต่ำ `84px`, บันทึก Filled พร้อม Icon กว้างขั้นต่ำ `100px`. Action เพิ่มสำเร็จให้ล้างฟอร์มกลับค่าเริ่มต้นและคง Popup เปิดไว้; แก้ไขสำเร็จให้ปิด Popup และโหลดรายการใหม่.
- Lookup ที่เปิดจาก ComboBox ให้ค้นหาชื่อ/รหัสตามสิทธิ์และขอบเขต Company, กรองรายการทันทีขณะพิมพ์, เลือกด้วยการกดแถวหรือ Card แล้วปิดพร้อมคืนค่า; ปิดโดยไม่เลือกคงค่าเดิม. ถ้ามีสิทธิ์อ่านแต่ไม่มีสิทธิ์เพิ่ม/แก้/ลบ ให้แสดง Icon ค้นหาในช่องและ Popup ค้นหาแบบง่าย โดยไม่แสดงปุ่มจัดการ; หากมีสิทธิ์ Action ให้แสดงเฉพาะ Action ที่ได้รับ. ช่องค้นหา Lookup ใช้ Typography/Label เดียวกับ Field ทั่วไป.
- Popup รูปภาพมี Icon รูป Primary ก่อน Caption ดำ, Divider ใต้ Header และก่อน Footer, เนื้อหาเลื่อนได้เมื่อจำเป็น และจำกัดขนาด Popup ตามจอ. Date Picker พื้นขาวทั้ง Header/Calendar ไม่มี Surface Tint ใช้ Theme กลาง, มุม `4px`, สีข้อความ/วัน/ปุ่มตาม Semantic Text และ Primary ของ User.

## 7. สถานะข้อความและการแจ้งผล

- Loading คง Layout ไม่กระโดด; Empty/Filtered Empty แสดงเหตุผลที่เข้าใจได้พร้อม Pagination `0-0 จาก 0`; Error มี Action ลองใหม่เมื่อเหมาะสม. ตรวจข้อมูลสั้น ยาว และ Text Scale, Hover, Focus, Keyboard, Wide/Compact/Mobile โดยไม่ Overflow.
- Alert ทุกชนิด (Success, Error, Warning, Info) แสดงเป็น overlay มุมขวาบน Content Area ไม่ดัน Layout และไม่ใช้ SnackBar ติดขอบล่างเป็นค่าเริ่มต้น; อ่าน `TDSTCompanySetUp.TimeAlert` จาก `CompanySetupController` ผ่าน `AutoDismissMessage`/`showTimedSnackBar` เพื่อปิดอัตโนมัติตามค่าที่กำหนด และผู้ใช้กดปิดได้. Success ใช้พื้น Primary โปร่ง `50%`; Error ใช้ Semantic Error และข้อความอ่านชัด.
- Error แสดง `message` และ `รายละเอียดเพิ่มเติม` ที่บอกว่ารายการใดผิด สาเหตุโดยย่อ และสิ่งที่ควรทำต่อ; แยกข้อความซ้ำจาก `ApiException`, ใช้ `description`/`detail`/Validation `errors` จาก API เมื่อมี. หาก API ไม่มี Description ให้เติมข้อความสำรองตาม HTTP Status เช่น ตรวจข้อมูลแล้วลองใหม่, Session หมดอายุ, ไม่มีสิทธิ์ หรือ Server ขัดข้อง. ไม่แสดงเพียงชื่อ Exception/HTTP/SQL/Secret/Stack Trace. Log เทคนิคแยกสำหรับผู้พัฒนา.

## 8. Popup ยืนยันลบ — ข้อยกเว้นสี Caption

- พื้นขาว กรอบนอกและมุม `4px` สี Semantic Error/Delete, กว้างตาม Popup มาตรฐาน. Header แถวเดียวมี Icon ถังขยะในกล่องแดงอ่อนและ Caption `ยืนยันการลบข้อมูล` **สีแดง Error/Delete** `18px/w700`; เป็นข้อยกเว้นจาก Caption ดำของ Popup อื่น.
- แสดง Key/ชื่อรายการในแถบพื้นแดงอ่อน และข้อความว่าเมื่อลบแล้วเรียกคืนไม่ได้; มี Divider ก่อน Footer. `ยกเลิก` เป็น TextButton สี Primary, `ลบ` เป็น Filled Error พร้อม Icon ถังขยะ. ถามยืนยันก่อนลบ; ตรวจ Permission ฝั่ง UI และ Backend และแสดงคำอธิบายเมื่อผิดพลาด.

## 9. Workspace และข้อมูลเฉพาะที่แสดงใน UI

- Shared Header Desktop สูง `52px`, Mobile `56px`. Desktop วางหน้าแรก/เมนูลัดสูงสุด 5/เมนูผู้ใช้แถวเดียว ที่เหลือใน `เพิ่มเติม`; Mobile ใช้ Popup ดาวและ User Menu แบบ Compact. คำสั่งออกจากระบบอยู่ใน User Menu แห่งเดียว. เมนูและ Caption มาจาก Navigation API/Resolver ตาม Permission.
- `MenuStyleCode` ของ User: `SLIDE` ใช้ Sidebar/Drawer (Mobile เปิดด้วย Hamburger); `BUTTON` ใช้ Home Card เมนูลัด/กลุ่มเมนู โดย Mobile ยังมี Hamburger และเมื่อเปิดปลายทางให้ใช้ Content เต็ม. เมื่อเข้า Home ให้แสดงกลุ่มเมนูแรกที่ผู้ใช้มีสิทธิ์. Menu Card เป็นข้อยกเว้นที่มีเงา/ขอบมน สีตาม Theme และ Card ที่ Active ใช้ Primary โปร่ง; โหมดรายการโปรด `LIST` แสดงชื่อคั่น `|` โดยไม่มีกรอบ/ActionChip. Logo กลับ Home ตาม User Scope โดยไม่สร้าง Shell ใหม่; ไม่แสดงเมนู stale หรือเมนู hardcode.
- ชื่อพนักงานอ่านรูปแบบที่บริษัทกำหนด (ชื่อจริง/ชื่อเล่น/ทั้งสอง). ค่าว่างหนึ่งด้านใช้ด้านที่มี; ว่างทั้งคู่แสดง `-`. ไม่เปลี่ยนข้อมูลต้นทาง, สิทธิ์ หรือประวัติ และไม่ใช้กติกานี้กับชื่อบุคคลชนิดอื่นหรือ snapshot.
- หน้ากำหนดอนุมัติแบบระดับตำแหน่งให้แสดงวิธีเรียงตามชื่อ/รหัสย่อ/ลำดับ และตัวเลือกหน่วยงาน `เจาะจงตำแหน่ง`, `แผนกเดียวกัน`, `ฝ่ายเดียวกัน` พร้อมคำอธิบาย. Backend ใช้ค่าบริษัทหรือค่ารูปแบบเฉพาะ, เรียงน้อยไปมาก, ไม่ส่งเมื่อข้อมูลว่าง/ซ้ำ; ตรวจลำดับเฉพาะพนักงานก่อนรูปแบบปกติและห้าม fallback เงียบเมื่อค่าพิเศษไม่ครบ. ตรวจ Company, Permission และหน่วยงานทุกครั้ง.

## 10. ตรวจรับก่อนส่งงาน UI

ตรวจ Caption/Label ทุกสถานะและสีทุกจุด, ระยะ Content/Card ที่แสดงจริงรวม Padding ชั้นนอก, Table/Card/Empty/Error/Pagination, Responsive และ Text Scale, Permission ทุก Action, วันที่และปีบริษัท, Lookup, Popup Action และ Popup ลบ. เมื่อแก้ UX ให้ทำตามวิธี Format/Run/Test ที่ `AGENTS.md` กำหนด; งาน UI อย่างเดียวไม่เปลี่ยน API, SQL, Repository หรือ Business Logic โดยไม่มีคำสั่ง.

**ประวัติการรวม:** มาตรฐาน UI เดิมถูกแทนด้วยไฟล์นี้. ข้อยกเว้น Filter Padding `10px` ของ School Food และค่าต่าง ๆ ในต้นแบบ Master Data ถูกแทนด้วยค่ากลางในหัวข้อ 2–4; เอกสารประวัติเดิมไม่ได้กำหนดค่า UI ปัจจุบัน.

## 11. ค่าที่อ่านได้จากหน้าจอตัวอย่างสิทธิ์เมนู

ส่วนนี้เป็นค่ามาตรฐานอ้างอิงจากหน้าจอจริงตัวอย่าง `สิทธิ์เมนู` ที่ส่งให้ตรวจ ไม่ใช่การผูกกับค่าของบริษัทใดบริษัทหนึ่ง. หากขัดกับ Token กลาง ให้ใช้ Token กลางและใช้ค่าด้านล่างเป็นสัดส่วน/แนวทางจัดวาง.

- โครง Desktop แบ่งเป็น Sidebar ทางซ้าย, App Header ด้านบน และ Content Area ทางขวา; Sidebar กว้างประมาณ `310px`, App Header สูงประมาณ `52px` และ Content เริ่มหลัง Sidebar โดยไม่ซ้อนทับกัน.
- Content ใช้พื้นหลัง `LaooColors.background`; Card ทุกส่วนกว้างเต็ม Content Area และขอบซ้าย/ขวาตรงกัน. ระยะระหว่าง Caption Card, Filter Card และ Result Card เป็น `8px`; ไม่ใช้ Card แบบหดตามข้อความ.
- Caption Card ของหน้าตัวอย่างมีแถวหัวเรื่องด้านซ้าย (Icon `24px`, Caption `18px/w700`, ดาวเมนูลัด) และชุดปุ่มด้านขวา. ปุ่มทั้งหมดต้องอยู่ชิดขวา เรียงตามลำดับที่ได้รับอนุญาต และมีช่องว่างระหว่างปุ่ม `8px`.
- ปุ่มใน Caption Card ใช้ความสูง `48px`; ปุ่มไอคอนสลับ List/Card เป็น `48×48px`; ปุ่ม Filled/Outlined ใช้ Padding แนวนอน `16px`, มุม `4px`, ข้อความ `13px/w600–w700`. ปุ่มลบใช้ Error/Delete และปุ่มบันทึก/ให้สิทธิ์ใช้ Primary ตาม User Theme.
- Filter Card ของหน้าตัวอย่างมี Padding `12px`; TextBox และ ComboBox อยู่ในแนวเดียวกัน สูงเท่ากันเมื่ออยู่แถวเดียวกัน; ระยะระหว่าง Control `8px`. ช่องค้นหาใช้ Icon ด้านซ้าย, ComboBox มี Floating Label และลูกศรขวา.
- Filter ของสิทธิ์เมนูประกอบด้วยช่องค้นหากลุ่มสิทธิ์/ชื่อ, ComboBox ระดับระบบ และ ComboBox กลุ่มเมนู. เมื่อพื้นที่ไม่พอให้ Wrap ตามลำดับเดิมโดยไม่ย่อ TextBox จนอ่านไม่ออก.
- Result Table ใช้ Header พื้น Primary โปร่งประมาณ `12%`, Header Text Primary `14px/w700`; แถวข้อมูล `14px`, แถวสูงประมาณ `56px`; เส้นคั่นแนวนอน `0.6px` สี Semantic Border และไม่มีเส้นตั้ง/กรอบนอก.
- คอลัมน์สิทธิ์ในภาพเรียง `เมนู`, `แสดง`, `เพิ่ม`, `แก้ไข`, `ลบ`, `พิมพ์`, `ส่งออก`; คอลัมน์เมนูและ Action อยู่ซ้าย ส่วน Checkbox จัดกึ่งกลางในคอลัมน์ของตนเอง. Icon เมนู/โฟลเดอร์และข้อความอยู่แนวเดียวกัน.
- Checkbox ที่เลือกใช้ Primary ของ User Theme พร้อมเครื่องหมายสีอ่านชัด; Checkbox ที่ไม่ได้เลือกใช้กรอบ Neutral/Border. การแสดง Checkbox ต้องเคารพ Permission และไม่แสดง Action ที่ผู้ใช้ไม่มีสิทธิ์.
- แถวเมนูหลักใช้ข้อความ/ไอคอน Primary น้ำหนัก `w700`; แถวลูกใช้ข้อความปกติและเยื้องตามระดับต้นไม้. ปุ่มสามจุดของ Action อยู่ในคอลัมน์ Action เดียวกันและต้องไม่ทำให้ข้อความเมนูเลื่อนแนว.
- ตารางที่มีคอลัมน์มากต้องเลื่อนแนวนอนได้เมื่อจำเป็น; ที่ความกว้างหน้าจอ `<=600px` ให้เปลี่ยนเป็น Card เสมอและซ่อนปุ่มสลับ List/Card. ห้ามลดขนาดตัวอักษรต่ำกว่ามาตรฐานเพื่อฝืนให้ตารางพอดี.
- ทุกค่าที่เป็นสีในภาพ (ม่วง/เขียว/แดง/เทา) ให้แมปผ่าน Semantic Token ของ User Theme; ห้ามคัดลอก Hex จากภาพลง Feature Page. สีม่วงของภาพเป็น Primary ของ User ตัวอย่าง ไม่ใช่สีบังคับทั้งระบบ.

## 12. ค่าที่พ่อยืนยันล่าสุดสำหรับหน้ารายการและ Popup Action

ค่าชุดนี้เป็นข้อกำหนดล่าสุดของ `my-ui` สำหรับหน้ารายการที่มี Table/Pagination และ Popup Action. หากข้อความก่อนหน้ากำหนดค่าทั่วไปต่างกัน ให้ใช้ค่าชุดนี้กับหน้าประเภทดังกล่าว โดยยังคงใช้ Semantic Token ของ User Theme แทนการกำหนดสีแบบตายตัว.

### รายการ, ตาราง และ Pagination

1. Header ตารางใช้พื้น Primary แบบโปร่ง ข้อความ Primary ขนาด `18px` น้ำหนัก `w700`.
2. แถวข้อมูลสูงประมาณ `58–60px` และข้อมูลในแถวใช้ขนาด `16px`.
3. ใช้เส้นคั่นแนวนอนบาง สีอ่อน ไม่มีเส้นตั้ง.
4. ตารางเว้น Padding ซ้าย/ขวาประมาณ `12px`.
5. Icon ในคอลัมน์ Action เริ่มชิดซ้ายของคอลัมน์.
6. Edit ใช้สี Primary; Delete ใช้สี Semantic Error/Delete.
7. Pagination Card อยู่ใต้ Result Card และห่างประมาณ `8px`.
8. ปุ่มเลื่อนหน้าเป็นสี่เหลี่ยม มุมประมาณ `4px` และไม่มีเส้นขอบสี.
9. ปุ่มก่อนหน้า/ถัดไปใช้พื้นเทาอ่อน; ปุ่มหน้าปัจจุบันใช้พื้น Primary และข้อความสีขาว.

### TextBox

- Caption/Floating Label ใช้ขนาดประมาณ `16px` และใช้สี Primary เมื่อช่องมี Focus หรือมีข้อมูล.

### Popup Action

- Popup กว้างตามความเหมาะสมของข้อมูลและพื้นที่หน้าจอ ไม่ล็อกความกว้างตายตัว.
- พื้น Popup สีขาว อยู่กึ่งกลางหน้าจอ และมี Scrim สีเทาดำแบบโปร่งรอบ Popup.
- Header เว้น Padding ซ้ายประมาณ `14px`; Icon Header ประมาณ `24px`; Caption Popup ประมาณ `24px/w700`.
- มี Divider ใต้ Header และก่อน Footer.
- ระยะจาก Header ถึง Field แรกประมาณ `14px`.
- TextBox สูงประมาณ `50px`; ระหว่าง TextBox ประมาณ `16px`.
- Caption/Floating Label และข้อความใน TextBox ใช้ขนาดประมาณ `16px`.
- กรอบ TextBox ใช้สี Primary เมื่อ Focus และสีอ่อนตาม Semantic Border ในสถานะปกติ.
- Footer จัดปุ่มชิดขวา; ปุ่มยกเลิกและบันทึกสูงประมาณ `60px`; ระยะห่างระหว่างปุ่มประมาณ `10px`.
- ปุ่มยกเลิกเป็น Outlined Primary ไม่มีพื้นสี; ปุ่มบันทึกเป็น Filled Primary พร้อม Icon; ปุ่มทั้งสองมุมประมาณ `4px`.

## 13. มาตรฐาน ScreenType = 2 แบบ Card

ใช้กับหน้ากำหนดค่า/หน้าฟอร์มที่แบ่งข้อมูลเป็นหัวข้อย่อ–ขยายได้ โดยใช้ Semantic Token ของ User Theme และค่าต่อไปนี้เป็นค่ากลางล่าสุด.

### โครง Card และระยะ

- พื้นหน้าจอใช้ `LaooColors.background`; Card พื้นขาว ไม่มีเส้นขอบและไม่มีเงา มุมประมาณ `4px`.
- Card กว้างเต็มพื้นที่ Content โดยเว้นขอบซ้าย/ขวาประมาณ `12px`; ระยะห่างระหว่าง Card ประมาณ `10–12px`.
- Header Card สูงประมาณ `98px`; Padding ซ้าย/ขวาประมาณ `24px`.

### Header Card และปุ่มคำสั่ง

- Header ใช้ Icon ประมาณ `24px` สี Primary, Caption ประมาณ `24px/w700` และดาวเมนูลัดห่างจาก Caption ประมาณ `14px`.
- ปุ่มคำสั่งทั้งหมดจัดชิดขวาของ Header Card.
- ปุ่มยกเลิกกว้างประมาณ `120px`, สูงประมาณ `60px`, เป็น Outlined Primary และไม่มีพื้นสี.
- ปุ่มบันทึกกว้างประมาณ `115px`, สูงประมาณ `60px`, เป็น Filled Primary และมี Icon.
- ระยะห่างระหว่างปุ่มประมาณ `10px`; ปุ่มทุกปุ่มมุมประมาณ `4px`.

### หัวข้อ Card ย่อ/ขยาย

- Card หัวข้อสูงประมาณ `68–70px`; ใช้ Icon ประมาณ `24px`, Caption ประมาณ `22px/w700` และ Chevron ชิดขวา.
- Header หัวข้อเว้น Padding ซ้าย/ขวาประมาณ `24px`.
- เมื่อเปิดหัวข้อ ให้ใช้แถบหัวข้อพื้น Neutral/Surface อ่อน; เมื่อปิดให้แสดงเฉพาะหัวข้อและ Chevron.

### Card เนื้อหาและ Grid

- Card เนื้อหาใช้ Padding ภายในประมาณ `24px`.
- เมื่อพื้นที่เพียงพอ ให้จัดข้อมูลเป็น Grid `3 คอลัมน์`; ช่องว่างระหว่างคอลัมน์ประมาณ `16–18px`.
- ช่องข้อมูลสูงประมาณ `50px`; ระยะห่างระหว่างแถวประมาณ `14–16px`.
- Floating Label ใช้ขนาดประมาณ `14–16px` สี Primary; ข้อความใน TextBox/ComboBox ใช้ขนาดประมาณ `16px`.
- TextBox/ComboBox ใช้กรอบ Outline สี Primary อ่อน มุมประมาณ `4px`; ComboBox มีลูกศรชิดขวา.
- เมื่อมีข้อมูลหรือ Focus ให้ Floating Label อยู่ด้านบนและใช้สี Primary.
- Grid ให้ลดจาก `3` เป็น `2` และ `1` คอลัมน์ตามพื้นที่ โดยไม่ให้เกิด Horizontal Overflow.

## 14. มาตรฐาน ScreenType = 3 แบบอ่านอย่างเดียว

- `ScreenType = 3` เป็นหน้าจอ `ShowOnly`; ห้ามแสดงหรือเปิด Action `CREATE`, `EDIT`, `DELETE` และห้ามแสดงปุ่มบันทึก/ยกเลิกสำหรับข้อมูลอ่านอย่างเดียว.
- ค่าเริ่มต้นของมุมมองรายการให้ อ่าน `User Style` ของผู้ใช้ก่อนเสมอ: ถ้าผู้ใช้กำหนด Card ให้เปิดเป็น Card ทันที; ถ้าผู้ใช้กำหนด List ให้เปิดเป็น List ตามมาตรฐาน `ScreenType = 1` ได้แก่ Caption Card, Filter Card เมื่อจำเป็น, Result แบบ Table และ Pagination Card.
- เมื่อผู้ใช้เลือกดูรายการ ให้เปิดรายละเอียดด้วย Card ตามมาตรฐาน `ScreenType = 2` โดยใช้ Header Card และ Card เนื้อหาแบบย่อ/ขยายได้.
- รายละเอียดของ `ScreenType = 3` ใช้ข้อมูลแบบ Read-only; TextBox/ComboBox ห้ามแก้ไขและใช้สี Disabled/Neutral ตาม Semantic Token แต่ยังคงขนาดตัวอักษร Floating Label และระยะห่างของ `ScreenType = 2`.
- ถ้าหน้ารายการมี Action ให้แสดงเฉพาะ `VIEW` หรือ Action ที่อ่านข้อมูลได้ตาม Permission; Icon Action เริ่มชิดซ้ายของคอลัมน์ Action.
- เมื่อ User Style กำหนด List แต่ความกว้างหน้าจอไม่เกิน `600px` ให้เปลี่ยน Result เป็น Card อัตโนมัติ; การเปลี่ยนนี้เป็นการแสดงผลชั่วคราวและห้ามเขียนทับค่าที่ผู้ใช้เลือกไว้.
- เมื่อ User Style กำหนด Card ให้ใช้ Card ได้ทันทีโดยไม่ต้องรอให้หน้าจอแคบ และคง Card ไว้จนกว่าผู้ใช้จะเปลี่ยน User Style.
- เมื่อเปิดรายละเอียด ให้ใช้ Card ตามมาตรฐาน `ScreenType = 2` เสมอ ไม่ว่ารายการก่อนหน้าแสดงเป็น List หรือ Card.

## 15. ลำดับการเลือกรูปแบบ List/Card จาก User Style และ Responsive

1. อ่านค่ารูปแบบเริ่มต้นจาก User Style ของผู้ใช้ก่อนสร้าง Result.
2. ถ้า User Style เป็น `CARD` ให้แสดง Card เป็นค่าเริ่มต้น.
3. ถ้า User Style เป็น `LIST` ให้แสดง List เมื่อความกว้างหน้าจอมากกว่า `600px`.
4. ถ้าความกว้างหน้าจอไม่เกิน `600px` ให้บังคับแสดง Card อัตโนมัติ แม้ User Style จะเป็น `LIST`.
5. การบังคับ Card จาก Responsive เป็นเพียง View ที่คำนวณชั่วคราว ไม่แก้ไขหรือบันทึก User Style.
6. เมื่อหน้าจอกลับมากกว่า `600px` ให้คืนมุมมองตาม User Style เดิม และแสดงปุ่มสลับ List/Card ตาม Permission/การตั้งค่าของเมนู.

## 16. รูปแบบเริ่มต้นหลังเข้าเมนู

- ทุกครั้งที่ผู้ใช้กดเข้าเมนูที่มี Result แบบ List/Card ให้คำนวณรูปแบบการแสดงผลก่อนสร้างรายการ โดยอ่าน `User Style` ของผู้ใช้ก่อนเสมอ.
- ถ้า `User Style = CARD` ให้แสดงรายการเป็น Card ทันทีตั้งแต่การเปิดเมนูครั้งแรก.
- ถ้า `User Style = LIST` และความกว้างหน้าจอมากกว่า `600px` ให้แสดงรายการเป็น List ตั้งแต่การเปิดเมนูครั้งแรก.
- ถ้า `User Style = LIST` แต่ความกว้างหน้าจอไม่เกิน `600px` ให้บังคับแสดงเป็น Card ชั่วคราวตั้งแต่เปิดเมนู เพื่อป้องกันตารางล้นจอ.
- การบังคับ Card จากความกว้างหน้าจอเป็นเพียงค่าการแสดงผลของรอบนั้น ห้ามบันทึกทับ `User Style`.
- เมื่อขนาดหน้าจอเปลี่ยนกลับมากกว่า `600px` ให้คืนรูปแบบตาม `User Style` เดิมโดยอัตโนมัติ.
- ถ้าเมนูไม่มีสิทธิ์ให้ผู้ใช้เลือก List/Card ให้ใช้ User Style เป็นค่าเริ่มต้นและซ่อนปุ่มสลับ; ถ้าหน้าจอไม่เกิน `600px` ยังคงบังคับ Card ตามกติกา Responsive.

## 17. มาตรฐาน Tab

- Tab เริ่มชิดซ้ายของ Content Card.
- ตำแหน่งเริ่มอ้างอิงประมาณ `x=55px`, `y=45px`.
- ความสูง Tab ประมาณ `60px`.
- Tab ที่เลือกกว้างประมาณ `122px`; Tab อื่นกว้างประมาณ `120px`.
- ระยะห่างระหว่าง Tab ประมาณ `24–28px`.
- Tab ที่เลือกใช้พื้น Primary โปร่งสีอ่อน และมุมบนประมาณ `4px`.
- ข้อความ Tab ใช้ขนาดประมาณ `16px`; Tab ที่เลือกใช้ `w700`; Tab ที่ไม่ได้เลือกใช้น้ำหนักปกติ.
- เส้นคั่นใต้ Tab หนาประมาณ `1px` สี Semantic Border.
- Tab เรียงแนวนอนชิดซ้าย ไม่จัดกึ่งกลางหน้าจอ.
- ถ้า Tab มีจำนวนมาก ให้เลื่อนแนวนอนได้โดยไม่บีบหรือตัดตัวอักษร.

## 18. ระยะวางเนื้อหาใต้ Tab

- ระยะจากเส้นใต้ Tab ถึงหัวข้อประมาณ `16px`.
- Icon หัวข้อประมาณ `24px`.
- ระยะ Icon ถึง Caption ประมาณ `10px`.
- Caption หัวข้อประมาณ `22px/w700`.
- ระยะจากหัวข้อถึงช่องแรกประมาณ `14–16px`.
