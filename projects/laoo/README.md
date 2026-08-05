# Laoo Product

Laoo เป็น Product แรกและเป็นระบบหลักของ Laoo Solutions

## Entry Point

- หน้าเริ่มต้นเป็น Landing Page
- ไม่มีหน้าสมัครสมาชิกในขอบเขตปัจจุบัน
- หลัง Login ต้องระบุ Context ได้ตามลำดับ `Laoo → Partner → Customer → Employee`

## Structure

```text
laoo/
├── app/        Flutter application
├── api/        ASP.NET Core Web API
├── database/   SQL Server scripts and migrations
├── docs/       Product-specific documentation
└── laoo.code-workspace
```

มาตรฐานกลางอยู่ที่ `C:\laoo\docs`

## Open in VS Code

ให้เปิด Product นี้ผ่านไฟล์

```text
C:\laoo\projects\laoo\laoo.code-workspace
```

เพื่อให้เห็นทั้ง `Laoo Product` และ `Laoo Shared Standards` ห้ามเปิด `app/` เป็น Workspace หลักของทีม

## Security

- Flutter ห้ามเชื่อมต่อ SQL Server โดยตรง
- ห้ามเก็บ Password, Connection String จริง, API Key หรือ Private Key ใน Git
