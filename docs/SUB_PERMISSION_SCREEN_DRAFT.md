# Draft: หน้าจอสิทธิระดับย่อย

## แนวคิดหน้าจอ

หน้าจอนี้ใช้จัดการ Master ของชื่อสิทธิ์ระดับคำสั่งย่อยภายในแต่ละหน้าจอหลัก เช่น ปุ่มนามบัตร และปุ่มเอกสารลูกค้า

ข้อมูลหน้าจอหลักอ่านจาก `TDADMainMenu` และชื่อสิทธิ์ย่อยอ่านจาก `TDADUserPermissionPointName`
ส่วน `TDADUserPermissionPoint` จะนำไปใช้ภายหลัง สำหรับกำหนดว่าพนักงานคนใดได้รับสิทธิ์

## การจัดกลุ่มข้อมูล

```text
MenuCode
  -> TDADMainMenu.MenuName                 หัวข้อกลุ่ม
  -> TDADUserPermissionPointName           รายการ Master ชื่อสิทธิ์ย่อย
  -> TDADUserPermissionPoint               ตารางกำหนดสิทธิ์ของ EmployeeID (ใช้ภายหลัง)
```

## UX Layout

```text
สิทธิระดับย่อย       ★                         [เพิ่ม]

[เลือกเมนูหลัก                         ▼]   [ค้นหา................]

┌─────────────────────────────────────────────────────────────┐
│ ข้อมูลลูกค้า                                                │  <- MenuName
├─────────────────────────────────────────────────────────────┤
│ ปุ่มนามบัตร                         [เปิด/ปิด]  [แก้ไข]     │
│ ปุ่มเอกสารลูกค้า                    [เปิด/ปิด]  [แก้ไข]     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ ข้อมูลสินค้า                                                │  <- MenuName
├─────────────────────────────────────────────────────────────┤
│ ปุ่มกำหนดราคา                       [เปิด/ปิด]  [แก้ไข]     │
└─────────────────────────────────────────────────────────────┘

                         [<] [1] [>]
```

## Query หลักสำหรับแสดงรายการ

```sql
SELECT
    M.MenuCode,
    M.MenuName,
    N.PermissionPointNameID,
    N.PermissionPointCode,
    N.PermissionPointName,
    N.PermissionPointDescription,
    N.SortOrder,
    N.IsActive
FROM dbo.TDADMainMenu AS M
INNER JOIN dbo.TDADUserPermissionPointName AS N
    ON N.MenuCode = CONVERT(NVARCHAR(20), M.MenuCode)
   AND N.IsActive = 1
WHERE M.IsActive = 1
ORDER BY M.MenuCode, N.SortOrder, N.PermissionPointName;
```

## การสร้างรหัสอัตโนมัติ

`PermissionPointNameID` เป็น `BIGINT IDENTITY(1,1)` ดังนั้นตอนเพิ่มข้อมูลให้ไม่ส่งค่า ID เข้าไป

```sql
INSERT dbo.TDADUserPermissionPointName
    (MenuCode, PermissionPointCode, PermissionPointName,
     PermissionPointDescription, SortOrder, IsActive)
VALUES
    (N'09001', N'001', N'จัดการนามบัตร', N'จัดการนามบัตรของลูกค้า', 1, 1),
    (N'09001', N'002', N'จัดการเอกสารลูกค้า', NULL, 2, 1);
```

## เงื่อนไขการแสดงผล

## รูปแบบรายการที่แก้ไข

หน้าจอหลักให้แสดงรายการจาก `TDADUserPermissionPointName` โดยมี 3 ส่วน:

| คอลัมน์ | แหล่งข้อมูล | การแสดงผล |
|---|---|---|
| MenuName | `TDADMainMenu.MenuName` | Join ด้วย `MenuCode` แล้วแสดงชื่อเมนูหลัก |
| PointName | `TDADUserPermissionPointName.PermissionPointName` | ชื่อสิทธิ์ย่อย |
| Action | - | ปุ่ม `กำหนดพนักงาน` |

เมื่อกด `กำหนดพนักงาน` ให้เปิด Popup สำหรับจัดการ `TDADUserPermissionPoint`
โดยส่ง `MenuCode` และ `PermissionPointCode` ของรายการนั้นไปด้วย

- แสดง `MenuName` เป็นหัวข้อของแต่ละกลุ่ม
- แสดง `PermissionPointName` เป็นชื่อสิทธิ์ย่อย
- หน้าจอนี้แสดงข้อมูลจาก `TDADUserPermissionPointName` เป็นหลัก
- การตรวจสิทธิ์จริงตาม `EmployeeID` จะทำในหน้าจอกำหนดสิทธิ์พนักงานภายหลัง
- สีหัวข้อและปุ่มต้องใช้ User Style ของผู้ใช้งาน
- รองรับ List และ Card ตาม `DefaultViewMode` ของผู้ใช้
