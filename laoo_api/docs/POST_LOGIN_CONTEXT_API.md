# POST_LOGIN_CONTEXT_API

Status: Implementation package v1

## Goal

หลังจาก Login สำเร็จและได้รับ JWT แล้ว Flutter เรียก:

```http
GET /api/auth/post-login-context
Authorization: Bearer <access-token>
```

API จะอ่าน Username จาก JWT แล้ว resolve ตัวตนจาก Authentication Database

## Resolution order

```text
JWT
 |
Username
 |
 +--> TDADLaooUser
 |      |
 |      +--> TDADLaooUserProject
 |      +--> TDADProject
 |
 +--> TDADUser
        |
        +--> TDADUserCompany
        +--> TDADCompany
        +--> TDADUserBranch
        +--> TDADBranch
        +--> TDADUserProject
        +--> TDADProject
```

## Important decision

ฐานข้อมูลปัจจุบันไม่มี Column `IsSuperUser` ใน `TDADLaooUser`.

ดังนั้น v1 นี้จะ **ไม่เดา** ว่า `CanLoginAsUser` หรือ `IsSupportUser`
เท่ากับ Super User

Response จะคืน:

```text
UserType
IsSupportUser
CanLoginAsUser
```

เมื่อ Product Owner กำหนด Super User Policy/Field อย่างเป็นทางการ
จึงค่อยเพิ่ม `IsSuperUser` ในขั้นต่อไป

## Security

- Endpoint ต้องมี JWT (`[Authorize]`)
- Client ไม่ส่ง UserID / CompanyID เพื่อให้ API เชื่อ
- API resolve User จาก JWT และฐานข้อมูลเอง
- Company / Branch / Project ที่ส่งกลับต้องเป็นข้อมูลที่ User มีสิทธิ์จริง
