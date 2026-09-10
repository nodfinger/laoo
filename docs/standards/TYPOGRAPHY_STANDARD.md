# LAOO Typography Standard

- Font หลักใช้ `NotoSansThai` ที่ Bundle มากับ Application
- Fallback ใช้ `Noto Sans Thai`, `Tahoma`, `Arial` ตามลำดับ
- ทุกหน้าจอต้องอ่านค่าจาก `LaooTypography` และ Theme กลาง ห้ามกระจาย `fontFamily` หรือ `fontSize` แบบ hardcode
- Caption หลักของทุกหน้าจอทุกประเภท (`List`, `Card`, `Action` และ `Popup/Dialog`): `fontSize: 18`, `fontWeight: FontWeight.w700`, `color: Colors.black`, line height ประมาณ `1.3`
- คำว่า Caption หลัก หมายถึงชื่อหน้าจอหรือชื่อ Popup ที่อยู่บนสุดของพื้นที่นั้น ไม่รวม Section Title, Label/Floating Label, Table Header, ข้อมูลในรายการ และข้อความช่วยเหลือ
- ข้อกำหนด Caption นี้ต้องใช้เหมือนกันทุกขนาดหน้าจอและทุก Responsive Breakpoint โดยต้องไม่ปิดกั้นการปรับขนาดข้อความจาก Accessibility ของระบบ
- Section/หัวข้อย่อย: `16px`, น้ำหนัก `600-700`, line height ประมาณ `1.3`
- Label/Floating Label: `16px`, line height ประมาณ `1.4`
- TextBox, ComboBox และ Table: `14px`, line height ประมาณ `1.45-1.5` โดยใช้ `LaooTypography.inputText` และ `LaooTypography.comboBox`
- Button: `13px`, น้ำหนัก `600-700`; ความสูงมาตรฐานอ่านจาก `LaooTypography.buttonHeight` (`48px`)
- Hint/Validation/หมายเหตุ: `12px`
- ห้ามใช้ Letter Spacing ติดลบกับข้อความภาษาไทย
- ข้อความต้องไม่ถูกตัดหรือ Overflow เมื่อปรับขนาดหน้าจอ

## Prompt สำหรับส่งให้ AI

```text
ตรวจ Typography ตามมาตรฐานกลาง ใช้ NotoSansThai และ LaooTypography: Caption 18px น้ำหนัก w700 สีดำ; Section/Label 16px; TextBox/ComboBox/Table 14px; Button 13px สูง 48px; Hint/Validation 12px ห้ามกระจายค่าฟอนต์แบบ hardcode และต้องตรวจข้อความไทยกับ Overflow
```
