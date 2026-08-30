# Laoo Login — Remove Footer Full File

Copy และ Replace ไฟล์นี้:

`C:\laooplatformplatform\laoo\lib\features\authentication\presentation\pages\login_page.dart`

การเปลี่ยนแปลง:

- ลบข้อความ `ละออ โซลูชั่น`
- ลบ Divider ใต้ปุ่มเข้าสู่ระบบ
- แก้ Bottom Overflow 1 pixel
- ไม่แก้ `login_form.dart`

จากนั้นรัน:

```powershell
cd C:\laooplatformplatform\laoo
flutter clean
flutter pub get
flutter run -d chrome
```
