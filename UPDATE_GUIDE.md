# LAOO STARTER UPDATE GUIDE

ให้นำไฟล์ไปวางตาม Path ดังนี้

```text
C:\laooplatformplatform\laoo\PROJECT.md
C:\laooplatformplatform\laoo\lib\main.dart
C:\laooplatformplatform\laoo\lib\app.dart
C:\laooplatformplatform\laoo\lib\features\landing\presentation\pages\landing_page.dart
```

สร้างโฟลเดอร์ที่ยังไม่มีด้วย PowerShell

```powershell
New-Item -ItemType Directory -Force -Path "C:\laooplatformplatform\laoo\lib\features\landing\presentation\pages"
```

จากนั้นรัน

```powershell
cd C:\laooplatformplatform\laoo
flutter pub get
flutter analyze
flutter run -d windows
```

Version นี้ยังไม่ต้องแก้ `pubspec.yaml` เพราะใช้เฉพาะ Flutter SDK
