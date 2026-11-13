# AI ระบบแจ้งซ่อม

## ข้อกำหนดปัจจุบัน

Agent `service` รวม `repair.create_own`, `repair.track_own`, `repair.parts_cost`, `repair.pending`, `repair.serial_history` ดูสิทธิ์และ MenuCode ใน [ทะเบียน](README.md) การสร้างต้องยืนยันและป้องกันส่งซ้ำ; รายงานต้นทุนไม่รวมค่าแรงตามสเปก [ทะเบียนความสามารถ](capabilities-permissions.md)

## พฤติกรรมที่พบในโค้ด

`ServiceRequestController.cs` มี API `assistant/self`, `assistant/pending`, `assistant/parts-cost`, `assistant/serial-history` และรายงาน/อีเมล; มีการตรวจ capability และสิทธิ์ข้อมูล ตัวอย่างคำถาม: “แจ้งซ่อมใหม่”, “ติดตามงานซ่อมของฉัน”, “สรุปต้นทุนอะไหล่”

## แบบร่าง / ยังไม่ยืนยัน

[แผนงานแจ้งซ่อม](../../drafts/ai_service_capability_roadmap.md) อาจมีสถานะเก่า ต้องเทียบโค้ดและฐานข้อมูลก่อนถือว่าพร้อมใช้งานจริง
