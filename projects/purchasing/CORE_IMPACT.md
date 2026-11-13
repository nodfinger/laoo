# Purchasing Core Impact (69002)

โมดูลจัดซื้อถูกเตรียมแยกไว้ใน `projects/purchasing/**` แล้ว แต่ยังไม่เปิดใช้งานผ่านระบบกลางจนกว่า Core จะลงทะเบียนรายการต่อไปนี้เป็นชุดเดียว:

- MenuCode `69002` ชื่อเมนูคำขอจัดซื้อ และ `ScreenType = 4`
- Route name/path ตาม Core Registry (ค่าในโมดูลปัจจุบันเป็นสัญญาชั่วคราว: `purchasingRequests`, `/company/purchasing-requests`)
- Permission actions `VIEW`, `CREATE`, `EDIT`, `DELETE`, `UPLOAD`
- Project registration และ Company menu activation
- Root Flutter package/route/feature-host wiring
- Root API project reference และ MVC ApplicationPart ของ `Laoo.Purchasing.Module`

ห้ามแก้ `AGENTS.md`, Root Router, Shared UI, Permission กลาง หรือ Core Database จากฝั่งโมดูลนี้โดยอัตโนมัติ
