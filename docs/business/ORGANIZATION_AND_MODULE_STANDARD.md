# Organization and Module Standard

Version: 1.0  
Updated: 2026-08-09

## Hierarchy

`Laoo → Partner → Customer/Company → Branch → User`

Version 1 ไม่ใช้ TenantCode คำว่า Data Isolation ให้ยึด Company/Branch ownership และ Login Context

## Customer Creation

- Laoo Support Login ด้วยบัญชีตนเอง ไม่ Login เป็น Partner
- ทางเข้าหลัก: Partner detail → Customers → Add Customer; Partner ถูกกำหนดและแก้ไม่ได้
- ทางเข้ารอง: All Customers → Add Customer; Laoo Support ต้องเลือก Partner
- Partner User ใช้ Partner จาก Login Context และเปลี่ยนไม่ได้
- Laoo ขายตรงให้ใช้ Partner record ของ Laoo
- API ตรวจ Partner active และ Scope ก่อนบันทึก

## Company Module

| Actor | View | Activate/Deactivate | Laoo Lock |
|---|---:|---:|---:|
| Laoo Support | ตาม Permission | ตาม Permission ทุก Scope ที่อนุญาต | ตาม Permission |
| Partner User | ตาม Permission | ตาม Permission เฉพาะ Customer ของ Partner | ไม่ได้ |
| Company User | ตาม Permission | ไม่ได้ | ไม่ได้ |

Permission แนะนำ: `CM_MODULE.VIEW`, `CM_MODULE.ACTIVATE`, `CM_MODULE.DEACTIVATE`, `CM_MODULE.LOCK`

LaOO Lock มีอำนาจเหนือ Active state เมื่อถูก Lock Partner ห้ามแก้สถานะหรือเปิดกลับ การปลด Lock ทำได้เฉพาะ Laoo Support ที่มี Permission

การปิด Module ไม่ลบ Role/Permission เดิม เมื่อเปิดกลับสามารถใช้สิทธิ์เดิมต่อได้หลังตรวจ Runtime ครบ

