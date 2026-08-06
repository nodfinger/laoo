# Laoo Login — Unified Block Update

นำไฟล์นี้ไปวางทับ:

`C:\laoo\laoo\lib\features\authentication\presentation\pages\login_page.dart`

จากนั้นรัน:

```powershell
cd C:\laoo\laoo
flutter clean
flutter pub get
flutter run -d chrome
```

การเปลี่ยนแปลง:
- Logo และ Login อยู่ในกรอบเดียวกัน
- มี Border รอบกรอบหลัก
- มีเงาและมุมโค้ง
- Desktop/Web แบ่งซ้าย-ขวา
- Mobile เรียงบน-ล่าง
- มี Fade + Slide animation เบา ๆ
- คง Username, Password, ลืมรหัสผ่าน และปุ่มเข้าสู่ระบบ
