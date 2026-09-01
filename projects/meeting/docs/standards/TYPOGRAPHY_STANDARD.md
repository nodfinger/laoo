# LAOO Typography Standard

- Font หลักใช้ `NotoSansThai` ที่ Bundle มากับ Application
- Fallback ใช้ `Noto Sans Thai`, `Tahoma`, `Arial` ตามลำดับ
- ทุกหน้าจอต้องอ่านค่าจาก `LaooTypography` และ Theme กลาง ห้ามกระจาย `fontFamily` หรือ `fontSize` แบบ hardcode
- Caption/Page Title ด้านบนของหน้าจอทุกประเภท (`List`, `Card`, `Action`, `Popup/Dialog`): `18px`, สีดำ `LaooColors.pageCaption`, น้ำหนัก `FontWeight.w700`, line height ประมาณ `1.3`
- Caption/Page Title ต้องใช้ค่ากลาง `LaooTypography.workspaceCaption`, `LaooTypography.workspaceCaptionWeight` หรือ Style กลาง เช่น `LaooTypography.popupTitleStyle`; ห้าม hardcode แยกรายหน้า
- Section/หัวข้อย่อย: `16px`, น้ำหนัก `600-700`, line height ประมาณ `1.3`
- Label/Floating Label: `16px`, line height ประมาณ `1.4`
- TextBox, ComboBox, Table, List และข้อมูลใน Card: `14px`, line height ประมาณ `1.45-1.5`
- Button: `14px`, น้ำหนัก `600-700`; ความสูงมาตรฐานอ่านจาก `LaooTypography.buttonHeight` (`48px`)
- Hint/Validation/หมายเหตุ: `12px`
- ห้ามใช้ Letter Spacing ติดลบกับข้อความภาษาไทย
- ข้อความต้องไม่ถูกตัดหรือ Overflow เมื่อปรับขนาดหน้าจอ

## Prompt สำหรับส่งให้ AI

```text
ตรวจ Typography ของหน้าจอนี้ตาม docs/standards/TYPOGRAPHY_STANDARD.md ใช้ NotoSansThai และค่า LaooTypography จากส่วนกลางเท่านั้น: Caption ด้านบนของ List/Card/Action/Popup ใช้ 18px สีดำ FontWeight.w700, Section/Label 16px, TextBox/ComboBox/Table/List/Card/Button 14px, Hint/Validation 12px และปุ่มสูง 48px ห้าม hardcode fontFamily/fontSize กระจายในหน้าจอ และต้องตรวจข้อความไทยกับ Overflow
```
