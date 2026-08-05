# LAOO STARTER UPDATE GUIDE

ให้นำไฟล์ไปวางตาม Path ดังนี้

```text
C:\laoo\laoo\PROJECT.md
C:\laoo\laoo\lib\main.dart
C:\laoo\laoo\lib\app.dart
C:\laoo\laoo\lib\features\landing\presentation\pages\landing_page.dart
```

สร้างโฟลเดอร์ที่ยังไม่มีด้วย PowerShell

```powershell
New-Item -ItemType Directory -Force -Path "C:\laoo\laoo\lib\features\landing\presentation\pages"
```

จากนั้นรัน

```powershell
cd C:\laoo\laoo
flutter pub get
flutter analyze
flutter run -d windows
```

Version นี้ยังไม่ต้องแก้ `pubspec.yaml` เพราะใช้เฉพาะ Flutter SDK
