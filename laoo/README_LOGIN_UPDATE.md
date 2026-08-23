# Laoo Solutions — Login UI Update

ไฟล์ชุดนี้จัดทำสำหรับโปรเจกต์:

`C:\laooplatformplatform\laoo`

## ไฟล์ที่ต้องวาง

- `C:\laooplatformplatform\laoo\assets\images\laoo_login_logo.png`
- `C:\laooplatformplatform\laoo\lib\main.dart`
- `C:\laooplatformplatform\laoo\lib\core\theme\app_theme.dart`
- `C:\laooplatformplatform\laoo\lib\features\authentication\presentation\pages\login_page.dart`
- `C:\laooplatformplatform\laoo\lib\features\authentication\presentation\widgets\login_form.dart`

## pubspec.yaml

ตรวจสอบว่า `C:\laooplatformplatform\laoo\pubspec.yaml` มีส่วนนี้:

```yaml
flutter:
  uses-material-design: true

  assets:
    - assets/images/laoo_login_logo.png
```

จากนั้นรัน:

```powershell
cd C:\laooplatformplatform\laoo
flutter pub get
flutter run -d windows
```

## หมายเหตุ

ขณะนี้ปุ่มเข้าสู่ระบบจำลองการรอ API เท่านั้น ยังไม่ได้ตรวจสอบ Username/Password กับ SQL Server
