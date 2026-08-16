# Authorization and Data Access Rules

เอกสารนี้สรุปเงื่อนไขการ Login, Permission และการเข้าถึงข้อมูลตาม User ที่ระบบใช้อยู่ในปัจจุบัน รวมถึงประเด็นที่ต้องยกระดับก่อนรองรับหลาย Project อย่างเต็มรูปแบบ

## 1. หลักการบังคับใช้

- Client ใช้ซ่อนเมนูหรือปุ่มได้เพื่อประสบการณ์ใช้งานเท่านั้น
- Backend ต้องตรวจสอบ Authentication, Project Access, Permission และ Data Scope ซ้ำทุก Request
- การมี JWT ไม่ได้หมายความว่า User มีสิทธิ์อ่านหรือแก้ไขข้อมูลทุกประเภท
- การตรวจสิทธิ์ต้องยึดข้อมูลจาก JWT ที่ออกโดยระบบและข้อมูลสิทธิ์ใน Database ห้ามเชื่อค่า `UserID`, `CompanyID` หรือ `PartnerID` จาก Client โดยตรง

## 2. ข้อมูลหลักใน JWT

หลัง Login สำเร็จ ระบบออก JWT ซึ่งมีข้อมูลหลักดังนี้:

| Claim | ความหมาย |
|---|---|
| `user_type` | ประเภทผู้ใช้ เช่น `LAOO_SUPPORT`, `PARTNER_USER`, `COMPANY_USER` |
| `project_id` | Project ที่ Login อยู่ |
| `project_code` | รหัส Project |
| `laoo_user_id` | ID ผู้ใช้ฝั่ง Support |
| `partner_id` | ID Partner |
| `user_id` | ID ผู้ใช้ฝั่ง Company |
| `company_id` | ID Company |
| `branch_id` | ID Branch |

Claim ที่ไม่มีค่าจะไม่ถูกใส่ลงใน Token

## 3. เงื่อนไขตอน Login

Login จะสำเร็จเมื่อครบเงื่อนไขต่อไปนี้:

1. Username และ Password ถูกต้อง
2. User มีสถานะ Active
3. Project มีอยู่จริงและเปิดใช้งาน
4. User มีสิทธิ์เข้า Project ที่ร้องขอ
5. ประเภท User สอดคล้องกับข้อมูล User ใน Database
6. ระบบสามารถสร้าง JWT ได้

การผูก Project ปัจจุบันใช้ตารางตามประเภท User เช่น:

- `TDADLaooUserProject`
- `TDADUserProject`
- สิทธิ์/ความสัมพันธ์ของ Partner User ตามข้อมูล Partner และ Project

## 4. เงื่อนไข Authentication ของ API

Controller ที่มี `[Authorize]` ต้องได้รับ JWT ที่:

- Signature ถูกต้อง
- Issuer ถูกต้อง
- Audience ถูกต้อง
- ยังไม่หมดอายุ

ถ้าไม่ผ่าน ให้ถือว่าไม่มีสิทธิ์เข้า API และไม่ควรดำเนินการ Query ข้อมูลธุรกิจ

## 5. เงื่อนไข Permission

Action ที่ระบบรองรับ:

```text
VIEW
CREATE
EDIT
DELETE
```

Permission ต้องตรวจตาม:

- User หรือ Role Group
- `ProjectID`
- `IsAllowed = 1`
- `IsActive = 1`
- Permission ต้อง Active
- Role Group ต้องอยู่ในช่วง `EffectiveFrom` และ `EffectiveTo`

Permission อาจมาจาก:

1. Permission ตรงของ User
2. Permission ผ่าน Role Group ที่ผูกกับ User/Employee
3. สิทธิ์ Admin ตามประเภท User ที่ระบบกำหนด

การแสดงปุ่มใน Client ไม่ถือเป็นการป้องกัน ต้องตรวจ Permission ซ้ำที่ Backend ทุก Action

## 6. Data Scope ปัจจุบัน

ระบบปัจจุบันกำหนดขอบเขตข้อมูลจากประเภท User ดังนี้:

| User Type | `OwnerType` | ขอบเขตข้อมูล |
|---|---:|---|
| `LAOO_SUPPORT` | `L` | ข้อมูลส่วนกลางของระบบ |
| `PARTNER_USER` | `P` | ข้อมูลของ Partner ที่ Login อยู่ |
| `COMPANY_USER` | `C` | ข้อมูลของ Company ที่ Login อยู่ |

ขอบเขตปัจจุบันเป็นระดับ:

```text
Project -> Partner -> Company
```

ยังไม่ใช่ขอบเขตระดับ User หรือ Branch ในทุกตาราง

## 7. เงื่อนไขการอ่าน TDSTMaster ปัจจุบัน

Endpoint:

```text
GET /api/support/master-data/groups
GET /api/support/master-data/actions
GET /api/support/master-data?groupCode={MasterGroupCode}&search={Search}
```

เงื่อนไขหลัก:

1. ต้อง Login และมี JWT ที่ถูกต้อง
2. ต้องมี Permission `VIEW`
3. ต้องระบุ `groupCode`
4. ระบบสร้าง Scope จาก Claims ใน JWT
5. Query ต้องตรงกับ `OwnerType`, `OwnerPartnerID` และ `OwnerCompanyID`

เงื่อนไขเชิง SQL ของการอ่านรายการมีลักษณะดังนี้:

```sql
WHERE MasterGroupCode = @GroupCode
  AND OwnerType = @OwnerType
  AND ISNULL(OwnerPartnerID, 0) = ISNULL(@PartnerID, 0)
  AND ISNULL(OwnerCompanyID, 0) = ISNULL(@CompanyID, 0)
```

ผลลัพธ์ตามประเภท User:

- Support เห็นเฉพาะรายการ `OwnerType = 'L'`
- Partner เห็นเฉพาะรายการของ `PartnerID` ตัวเอง
- Company เห็นเฉพาะรายการของ `CompanyID` ตัวเอง
- User ใน Company เดียวกันจะเห็น Master ชุดเดียวกัน หากมี Permission เท่ากัน

## 8. เงื่อนไข Create, Edit และ Delete TDSTMaster

### Create

- ต้องมี Permission `CREATE`
- ระบบกำหนด `OwnerType` และ Owner ID จาก JWT
- `MasterCode` ถูกสร้างภายใน Scope ของ `MasterGroupCode` และ Owner
- ห้ามสร้างข้อมูลซ้ำชื่อภายใน Group และ Scope เดียวกัน

### Edit

- ต้องมี Permission `EDIT`
- ต้องระบุ `MasterGroupCode` และ `MasterCode`
- Update ได้เฉพาะ Record ที่ตรงกับ Owner Scope ของ User

### Delete

- ต้องมี Permission `DELETE`
- ลบได้เฉพาะ Record ที่ตรงกับ Owner Scope ของ User
- ถ้าไม่พบ Record ใน Scope ให้ตอบ `NotFound`

## 9. ข้อจำกัดที่พบจาก Implementation ปัจจุบัน

### 9.1 TDSTMaster ยังไม่ได้กรองด้วย ProjectID

การ Query `TDSTMaster` ปัจจุบันกรองด้วย Group และ Owner แต่ยังไม่มี `ProjectID` ในเงื่อนไขโดยตรง

ถ้าหลาย Project ใช้ฐานข้อมูลเดียวกัน และใช้ `MasterGroupCode` ซ้ำกัน อาจเกิดข้อมูลชนกันได้

### 9.2 MasterDataController ใช้ `LaooDatabase` โดยตรง

ปัจจุบัน Controller เปิด Connection ด้วย `ConnectionStrings:LaooDatabase` โดยตรง และยังไม่ได้เรียก `DatabaseRouteResolver`

จึงต้องตรวจให้ชัดเจนว่า `TDSTMaster` อยู่ในฐานข้อมูลส่วนกลางหรือฐานข้อมูลของแต่ละ Project ก่อนรองรับหลาย Project จริง

### 9.3 ยังไม่มี User-level Record Scope สำหรับ TDSTMaster

ปัจจุบันไม่มีเงื่อนไข `OwnerUserID` และยังไม่ได้ใช้ `BranchID` ใน Query ของ `TDSTMaster`

ดังนั้น User ใน Company เดียวกันอาจเห็น Master ชุดเดียวกันทั้งหมด

## 10. มาตรฐานที่ควรใช้เมื่อรองรับหลาย Project

ทุก API ที่อ่านหรือแก้ข้อมูลธุรกิจควรผ่านลำดับนี้:

```text
Validate JWT
    -> Validate Project Access
    -> Validate Permission
    -> Resolve Database
    -> Resolve Data Scope
    -> Apply Record Filter
    -> Execute Query
```

ข้อมูลที่ต้องพิจารณาใน Record Scope ตามความจำเป็นของแต่ละตาราง:

```text
ProjectID
OwnerType
PartnerID
CompanyID
BranchID
OwnerUserID
```

ห้ามเพิ่มเงื่อนไข Scope จาก Client โดยตรง และห้ามใช้ค่าที่ส่งมากับ Query String แทนค่าจาก JWT

## 11. ข้อเสนอสำหรับ TDSTMaster

ก่อนใช้งานร่วมกันหลาย Project ให้กำหนดให้ชัดเจนว่า TDSTMaster เป็น:

1. Master ส่วนกลางของทุก Project
2. Master แยกตาม Project
3. Master ส่วนกลางที่ Override ได้ตาม Partner/Company

ถ้าเป็นแบบที่ 3 ควรมี Scope อย่างน้อย:

```text
ProjectID
OwnerType
OwnerPartnerID
OwnerCompanyID
```

และ Query ต้องเรียงลำดับการเลือกข้อมูลจาก Scope ที่เฉพาะที่สุดไปกว้างที่สุด เช่น:

```text
Company -> Partner -> Project Default -> System Default
```

## 12. สรุปสั้น

ระบบปัจจุบันป้องกันข้อมูลด้วย:

```text
JWT + Project + Permission + OwnerType + Partner/Company Scope
```

สำหรับ `TDSTMaster` ตอนนี้รองรับการแยกข้อมูลระดับ:

```text
Support / Partner / Company
```

แต่ยังต้องตัดสินใจและปรับเพิ่มเรื่อง:

- Project Scope
- Branch Scope
- User-level Scope
- การเลือก Database ผ่าน `DatabaseRouteResolver`

