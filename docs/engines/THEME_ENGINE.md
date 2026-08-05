# Laoo Theme Engine

Version: 0.1  
Status: Prototype

## Objective

ให้ผู้ใช้แต่ละคนเลือกโทนสีของตนเองจากชุด Theme ที่ Laoo เตรียมไว้

## Approved Requirements

- User ไม่เลือกสีทีละส่วน
- เลือก Theme เป็นชุด
- เริ่มต้นรองรับโทนสีเขียวและโทนสีฟ้า
- เมื่อเลือก Theme ต้องเปลี่ยนผลทันที
- เปิดระบบครั้งถัดไปต้องใช้ Theme เดิม
- Theme เป็น User Preference
- ใน Prototype เก็บค่าใน Local Storage
- ในระบบจริงเก็บใน User Profile ผ่าน API
- ถ้าไม่มีค่าที่บันทึกไว้ ใช้ Theme สีเขียวเป็น Default

## Architecture

```text
UI
→ AppThemeController
→ AppThemeStorage
→ SharedPreferencesAsync
```

ในอนาคต

```text
UI
→ AppThemeController
→ UserPreferenceRepository
→ API
→ SQL Server
```

## Extension

การเพิ่ม Theme ใหม่ต้องเพิ่ม

1. Theme Code
2. Display Name
3. Seed Color
4. Test Case

ห้ามกำหนดสี Theme กระจายอยู่ตาม Widget
