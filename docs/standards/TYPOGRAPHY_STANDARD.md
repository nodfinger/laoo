# LAOO Typography Standard

- Font หลักใช้ `NotoSansThai` ที่ Bundle มากับ Application
- Fallback ใช้ `Noto Sans Thai`, `Tahoma`, `Arial` ตามลำดับ
- ทุกหน้าจอต้องอ่านค่าจาก `LaooTypography` และ Theme กลาง ห้ามกระจาย `fontFamily` หรือ `fontSize` แบบ hardcode
- Caption หลักของทุกหน้าจอทุกประเภท (`List`, `Card`, `Action` และ `Popup/Dialog` รวม Popup ยืนยันลบ): `fontSize: 18`, `fontWeight: FontWeight.w700`, `color: LaooColors.pageCaption` (สีดำ), line height ประมาณ `1.3`
- คำว่า Caption หลัก หมายถึงชื่อหน้าจอหรือชื่อ Popup ที่อยู่บนสุดของพื้นที่นั้น ไม่รวม Section Title, Label/Floating Label, Table Header, ข้อมูลในรายการ และข้อความช่วยเหลือ
- ข้อกำหนด Caption นี้ต้องใช้เหมือนกันทุกขนาดหน้าจอและทุก Responsive Breakpoint โดยต้องไม่ปิดกั้นการปรับขนาดข้อความจาก Accessibility ของระบบ
- Section/หัวข้อย่อย: `16px`, น้ำหนัก `600-700`, line height ประมาณ `1.3`
- Label ทั่วไป: `16px`, line height ประมาณ `1.4`; Floating Label ของ TextBox/ComboBox ที่เห็นจริงใช้ `14px` และอ้าง `LaooTypography.materialFloatingLabelSource` เมื่อ Flutter มีการ Scale ตอนวาด
- **ข้อบังคับสำหรับหน้าจอใหม่ทุกหน้า:** ตรวจ Caption/Label บน TextBox และ ComboBox ทุกช่อง รวมถึง Filter และ Popup ให้ Floating Label มีขนาดที่แสดงจริง `14px` โดยใช้ `LaooTypography.materialFloatingLabelSource` เมื่อ Flutter ย่อขนาด Label; เมื่อมีข้อมูลหรือ Focus ใช้สี Primary จาก User Style และสถานะ Disabled ใช้สี Disabled ของ Theme ห้ามกำหนดสีหรือขนาดตายตัวรายหน้าจอ ตรวจทั้งตอนช่องว่าง มีข้อมูล Focus และ Disabled
- ข้อความที่กรอกใน TextBox: `16px` ใช้ `LaooTypography.inputText`, line height `1.5` และสีข้อความจาก Theme ผู้ Login; ComboBox และ Table: `14px` ใช้ Token กลางตามประเภท; Floating Label เมื่อมีข้อมูลหรือ Focus ใช้ Primary ของ User Style
- Button: `13px`, น้ำหนัก `600-700`; ความสูงมาตรฐานอ่านจาก `LaooTypography.buttonHeight` (`48px`) ยกเว้นปุ่มค้นหาและล้าง Filter ในหน้า List/Card ซึ่งต้องสูงเท่าช่องค้นหาที่แสดงจริงตาม `LIST_CARD_UI_STANDARD.md`
- Hint/Validation/หมายเหตุ: `12px`
- ห้ามใช้ Letter Spacing ติดลบกับข้อความภาษาไทย
- ข้อความต้องไม่ถูกตัดหรือ Overflow เมื่อปรับขนาดหน้าจอ

## Prompt สำหรับส่งให้ AI

```text
ตรวจ Typography ตามมาตรฐานกลาง ใช้ NotoSansThai และ LaooTypography: Caption ทุก Popup 18px น้ำหนัก w700 สีดำ; Section/Label 16px; Floating Label ที่เห็นจริง 14px; TextBox 16px; ComboBox/Table 14px; Button 13px สูง 48px ยกเว้นปุ่ม Filter ที่สูงเท่าช่องค้นหาตามมาตรฐาน List/Card; Hint/Validation 12px ห้ามกระจายค่าฟอนต์แบบ hardcode และต้องตรวจข้อความไทยกับ Overflow
```
