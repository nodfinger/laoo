# LAOO Build Tools

โฟลเดอร์นี้เก็บคำสั่ง Build ที่ใช้ร่วมกันใน Workspace `C:\laoo`

## โครงสร้างปัจจุบัน

```text
C:\laoo\laoo          Flutter app หลัก
C:\laoo\laoo_api      ASP.NET Core API หลัก
C:\laoo\scripts       SQL scripts
C:\laoo\docs          มาตรฐานและเอกสารส่วนกลาง
C:\laoo\publish       ผล Build ชั่วคราว (ไม่เก็บใน Git)
```

Project ใหม่ให้วางเป็นโฟลเดอร์ระดับเดียวกันภายใต้ `C:\laoo` และเปิดด้วย `.code-workspace` ของ Project นั้น ห้ามใช้โฟลเดอร์ `projects` ซ้อนอีกชั้น

## Build API สำหรับ Cloud

```powershell
& C:\laoo\tools\build-api-cloud.ps1
```

ผลลัพธ์อยู่ที่ `C:\laoo\publish\laoo_api_cloud.zip` และ Script จะหยุดทันทีหากพบ `local.json` หรือ `appsettings.Local.json` ในชุด Publish

## Build APK สำหรับทดสอบมือถือจริง

```powershell
& C:\laoo\tools\build-apk-test.ps1 `
  -ApiUrl https://api.example.com `
  -ProjectCode LAOO
```

ผลลัพธ์อยู่ที่ `C:\laoo\publish\laoo-LAOO-test.apk` ปัจจุบันเป็น Test APK ที่ใช้ Debug Signing Key ต้องตั้ง Release Keystore ก่อนนำขึ้น Store
