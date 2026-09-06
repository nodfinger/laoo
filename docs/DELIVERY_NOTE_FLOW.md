# ใบส่งของ (MenuCode 09006)

## เอกสารอ้างอิง

ใบส่งของเลือกอ้างอิงได้ 1 ประเภท หรือไม่อ้างอิงเอกสารก็ได้

- `QUOTATION` ใบเสนอราคา
- `PREORDER` ใบจองสินค้า
- `TEMP_RECEIPT` ใบเสร็จรับเงินชั่วคราว โดยระบบติดตามกลับไปยังใบจองหรือใบเสนอราคาต้นทาง
- `DELIVERY_NOTE` ใบส่งของเดิม สำหรับการส่งต่อ/ส่งซ้ำตามจำนวนคงเหลือ
- `NONE` ไม่อ้างอิงเอกสาร และเพิ่มสินค้าเอง

ความสัมพันธ์ระหว่างเอกสารบันทึกใน `TDARDocumentLink`

## สถานะและสต๊อก

- `DRAFT`: แก้ไขและลบได้ ยังไม่ตัดสต๊อก
- `CONFIRMED`: ยืนยันส่งของ ตัด `TDIVItem.StockBalance` และบันทึก `TDIVStockMovement` ภายใน Transaction เดียว
- `VOID`: ยกเลิกเอกสารที่ยืนยันแล้ว คืนสต๊อกและบันทึกรายการ `REVERSAL`

ระบบใช้ Unique Constraint ในสมุดสต๊อก ป้องกันการตัดหรือคืนสต๊อกซ้ำ และตรวจสต๊อกด้วย `UPDLOCK,HOLDLOCK`

ถ้าอ้างใบจอง ระบบเพิ่ม/ลด `TDARPreOrderDetail.DeliveredQty` พร้อมตรวจไม่ให้เกิน `AllocatedQty`

## ตาราง

- `TDARDeliveryNote`: หัวเอกสารและ Snapshot ลูกค้า/ที่อยู่จัดส่ง
- `TDARDeliveryNoteDetail`: รายการสินค้า จำนวนอ้างอิง จำนวนส่งสะสม และจำนวนส่งครั้งนี้
- `TDIVStockMovement`: สมุดรายการตัดและคืนสต๊อก

## API

- `GET /api/company/delivery-notes`
- `GET /api/company/delivery-notes/actions`
- `GET /api/company/delivery-notes/lookup`
- `GET /api/company/delivery-notes/source/{type}/{id}`
- `GET /api/company/delivery-notes/{id}`
- `POST /api/company/delivery-notes`
- `PUT /api/company/delivery-notes/{id}`
- `DELETE /api/company/delivery-notes/{id}` (เฉพาะ Draft)
- `POST /api/company/delivery-notes/{id}/confirm`
- `POST /api/company/delivery-notes/{id}/void`

API ทุกคำสั่งกรอง `CompanyID` จาก JWT และตรวจสิทธิ์ `VIEW/CREATE/EDIT/DELETE` ของ MenuCode `09006`; Company Admin ใช้งานได้ทุกคำสั่ง
