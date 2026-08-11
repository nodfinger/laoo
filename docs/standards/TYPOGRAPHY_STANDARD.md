# TYPOGRAPHY_STANDARD

**Document Type:** Central Standard  
**Scope:** All Laoo Solutions projects  
**Status:** Approved Baseline  
**Standard Path:** `C:\laoo\docs\standards\TYPOGRAPHY_STANDARD.md`

---

## 1. Purpose

เอกสารนี้เป็นมาตรฐานกลางเพียงไฟล์เดียวสำหรับเรื่อง Font, Font Size และ Typography ของ Laoo Solutions

เป้าหมายคือไม่กำหนด `fontSize` กระจายตามแต่ละ Form และให้ Pattern เดียวกันเปลี่ยนจากส่วนกลางได้

---

## 2. Central Source

Typography Runtime:

`C:\laoo\laoo\lib\app\theme\laoo_typography.dart`

Theme Integration:

`C:\laoo\laoo\lib\app\theme\workspace_theme_presets.dart`

Feature ใหม่ต้องอ้าง `LaooTypography` แทน hard-code `fontSize`

---

## 3. Current Approved Runtime Values — V2.2

- Page Title = 28
- Section Title = 16
- Subsection Title = 14
- Body = 12
- Body Small = 11
- Caption = 10
- **Input Text = 13**
- **Input Label = 16**
- Input Hint = 11
- Validation / Error = 11
- Table Header = 12
- Table Body = 12
- Button = 12
- Menu Group = 14
- Menu Item = 12
- Popup Menu = 12
- User Name = 13
- User Context = 10
- System Title = 13.5
- System Version = 8.5

---

## 4. TextBox Standard — V2.2

ค่ากลาง TextBox ปัจจุบัน:

- ข้อความที่พิมพ์ใน TextBox = 13px
- Label เหนือ/ลอยบน TextBox = 13px
- Hint Text = 11px
- Vertical Content Padding = 12px
- Horizontal Content Padding = 14px

ดังนั้น TextBox จะสูงขึ้นจากเดิมหนึ่งระดับโดยไม่ต้องแก้ทีละ Form

---

## 5. Font Family Standard

Font Family ต้องควบคุมจาก Theme กลาง ห้ามแต่ละ Form เลือกเอง เว้นแต่ได้รับอนุมัติเป็นกรณีพิเศษ

มาตรฐานที่อนุมัติปัจจุบัน:

- Font หลัก = `Noto Sans Thai`
- Flutter family key = `NotoSansThai`
- Font asset = `C:\laoo\laoo\assets\fonts\NotoSansThai-Variable.ttf`
- Font license = `C:\laoo\laoo\assets\fonts\OFL.txt`
- Font fallback = `Noto Sans Thai`, `Tahoma`, `Arial`, `sans-serif`
- ทุกหน้าจอต้องรับ Font จาก `LaooTypography`, `LaooTheme` หรือ `WorkspaceThemePreset` ห้ามระบุชื่อ Font ตายตัวใน Feature
- Font ถูก bundle ไปกับ Application เพื่อรองรับ Windows, Mobile และ Web โดยเครื่องปลายทางไม่ต้องติดตั้ง Font เพิ่ม

---

## 6. ThemeData Integration

`workspace_theme_presets.dart` ควบคุมกลางแล้วสำหรับ:

- Body Text
- Input Label
- Floating Label
- Hint Text
- Helper Text
- Error Text
- Button Text
- Input Border
- Focused Input Border
- TextBox Content Padding

Widget ที่กำหนด `TextStyle` เองจะ override Theme กลางและต้องทยอย migrate เมื่อเข้าไปแก้ Feature นั้น

---

## 7. Change Management

เมื่อต้องปรับ Font ของ Pattern เดียวกัน ให้แก้ที่ `laoo_typography.dart` หรือ Theme กลางก่อน ห้ามไล่แก้ทีละ Form

---

## 8. Source-First Rule

**Source First — No Guessing**

ก่อนแก้ Typography ต้องอ่าน Source ล่าสุด ถ้าไม่แน่ใจให้ขอไฟล์จริงก่อน

---

## 9. Single Documentation Rule

เรื่อง Font/Typography ใช้เอกสารนี้เพียงไฟล์เดียว:

`C:\laoo\docs\standards\TYPOGRAPHY_STANDARD.md`

ไม่สร้าง MD แยกสำหรับ Input Font, Hint Font, Menu Font, Popup Font, Table Font หรือ Button Font

---

**Laoo Solutions**  
*Simple Today. Ready Tomorrow.*
