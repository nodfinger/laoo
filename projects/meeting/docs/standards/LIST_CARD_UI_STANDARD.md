# LAOO List and Card Screen Standard

มาตรฐานนี้ใช้กับหน้า List/Table และ Card Mode ทุกหน้าจอ โดยต้องอ่าน `UX_UI_STANDARD.md` และ `PAGINATION_UI_STANDARD.md` ร่วมด้วย

## Layout

- ใช้พื้นหลังและ Design Token จากส่วนกลางเท่านั้น
- ส่วน Caption, Filter, Table/List และ Pagination เป็น Card สีขาวเต็มความกว้างของ Content Area
- Card ของแต่ละ Section จัดให้ติดกันและใช้เส้น `LaooColors.border` คั่น ห้ามใช้ช่องว่างหรือกรอบสีสร้างขอบซ้ำ
- Margin ซ้าย บน ขวาของ Content ใช้ `LaooLayout.cardMargin`
- Card ทุกตัวไม่มีเส้นกรอบสีและใช้มุมโค้ง `LaooRadius.xs`

## Caption Card

- Caption อ่าน `MenuName` จาก Navigation API/`TDADMainMenu` ห้าม hardcode
- Caption ใช้ค่ากลาง ขนาด `18px`, `FontWeight.w700`, สีดำ `LaooColors.pageCaption` ทั้ง List Mode และ Card Mode ห้ามกำหนด Style แยกรายหน้า
- Icon ดาวอยู่ซ้ายสุด ชิดกับ Caption และใช้สี Primary ของ User Style
- ปุ่ม `+ เพิ่ม` อยู่ขวา ใช้สี Primary มุมโค้ง `4px` และแสดงตาม Permission
- มีเส้นสีเทาอ่อนยาวใต้ Caption โดยต้องอยู่ภายใน Card พอดี

## Filter Card

- Filter Card เต็มความกว้างและ Responsive โดยใช้ `Wrap` หรือ Layout ที่ไม่ Overflow
- ช่องค้นหากว้างประมาณ `260px`, มีกรอบมุมโค้ง `4px`, Icon ค้นหาซ้าย และลูกศรขวา
- ไม่ Auto Search; ค้นหาเมื่อกด Enter, ลูกศร หรือปุ่ม `ค้นหา`
- ปุ่ม `ค้นหา` เป็น Filled สี Primary และปุ่ม `ล้าง Filter` เป็น Outlined สี Primary
- ComboBox กว้างประมาณ `280px`, มีกรอบมุมโค้ง `4px` และแสดงข้อความขนาดตาม Typography กลาง
- ปุ่มทุกปุ่มใช้ Font `14px` และมุมโค้ง `4px`

## Table Mode

- ตารางเต็มความกว้างและ Scroll แนวนอนได้เมื่อจำเป็น
- ไม่มีกรอบสีรอบนอก
- หัวตารางใช้พื้น Primary ความทึบประมาณ `10%`; ข้อความหัวตารางใช้ Primary ขนาด `14px` น้ำหนัก `700`
- ข้อความข้อมูลใช้ `14px`; เส้นคั่นแต่ละแถวใช้ `LaooColors.border` แบบบางและอ่อน
- คอลัมน์แรกเป็น `ID` เรียงตามลำดับรายการ และคอลัมน์ที่สองเป็น `Action`
- Action และ Icon จัดกึ่งกลาง; Edit ใช้ Primary, Delete ใช้สีแดง และแสดงตาม Permission
- รองรับ Sort เฉพาะคอลัมน์ที่ระบบกำหนดไว้เดิม

## Card Mode

- เมื่อ Content Area กว้างน้อยกว่า `900px` ให้เปลี่ยนเป็น Card Mode อัตโนมัติ
- Card Mode ใช้ Card สีขาว ไม่มีเส้นกรอบสี และข้อมูล/Action ต้องไม่ Overflow
- ข้อความข้อมูลใน Card ใช้ `14px` จาก `LaooTypography.body`
- ระยะห่างระหว่าง Card แต่ละรายการต้องเท่ากับ `6px` พอดี
- ให้ใช้ `ListView.separated`, `GridView` หรือ Layout ที่ได้ระยะเท่ากัน และตั้ง `Card.margin` เป็นศูนย์เมื่อจำเป็น
- ห้ามพึ่ง `Card` default margin เพราะจะทำให้ระยะจริงคลาดเคลื่อน
- ถ้าหน้าจอแคบจนบังคับ Card Mode ต้องซ่อนปุ่มสลับ List/Card; ปุ่มสลับแสดงเฉพาะหน้าจอกว้างปกติ

## Prompt สำหรับส่งให้ AI

```text
ปรับหน้า List/Card นี้ตาม docs/standards/UX_UI_STANDARD.md, LIST_CARD_UI_STANDARD.md, PAGINATION_UI_STANDARD.md และ TYPOGRAPHY_STANDARD.md ใช้ Caption จาก MenuName ขนาด 18px สีดำ FontWeight.w700 ผ่านค่ากลาง, Card สีขาวไม่มีกรอบสี, Filter/Table/Pagination เต็มความกว้าง, Action ตาม Permission และ User Style เมื่อหน้าจอแคบกว่า 900px ให้เป็น Card Mode อัตโนมัติ โดย Card รายการแต่ละใบห่างกัน 6px พอดี ห้ามพึ่ง Card default margin ห้ามแก้ API, SQL, Repository หรือ Business Logic และต้องตรวจ Responsive, Overflow, dart format และ dart analyze
```
