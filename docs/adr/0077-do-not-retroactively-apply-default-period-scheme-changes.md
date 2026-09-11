# ไม่ย้ายพนักงานเดิมเมื่อเปลี่ยน Default Scheme

การเปลี่ยน Default Attendance Period Scheme มีผลเฉพาะการสร้าง Employee Attendance Period Assignment ใหม่หลังวันที่เปลี่ยน และไม่ย้าย Employee ที่มี Assignment เดิม หากต้องการย้ายพนักงานหลายคนต้องใช้ Bulk Period Scheme Reassignment ระบุวันที่มีผล ตรวจช่วง Assignment ซ้อน และแสดง Attendance Period กับ Attendance Result ที่ได้รับผลกระทบก่อนยืนยัน เหตุผลคือ Default เป็นค่าช่วยตั้งต้น ไม่ใช่คำสั่งเปลี่ยนขอบเขตงวดของพนักงานทั้งหมดโดยอัตโนมัติ
