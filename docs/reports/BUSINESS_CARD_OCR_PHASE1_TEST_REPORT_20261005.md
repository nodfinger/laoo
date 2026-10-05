# รายงานทดสอบ OCR นามบัตร Phase 1

วันที่ทดสอบ: 5 ตุลาคม 2026
ฐานทดสอบ: DBTDLaooService / Company 1
ผู้ใช้ทดสอบ: Company Admin `c`

## ขอบเขตที่ส่งมอบ

- เมนู `55001` ตั้งค่า OCR นามบัตร — ScreenType 2
- เมนู `55002` ทะเบียนผู้ติดต่อ — ScreenType 1
- OCR ภายใน Center API ด้วย Tesseract 5.5.2 และโมเดล `tha+eng`
- นำเข้าไปยังข้อมูลลูกค้า ทะเบียนผู้ติดต่อ และแบบฟอร์ม Visitor
- ตรวจข้อมูลซ้ำภายใน Company และจำกัด Visitor ตามสิทธิ์สาขา
- เก็บภาพนามบัตรเป็นไฟล์ส่วนตัวของ API และเก็บเฉพาะ metadata ในฐานข้อมูล

## ผลทดสอบ

| ชุดทดสอบ | ผล |
|---|---|
| Center API Release Build | ผ่าน — 0 Error, 0 Warning |
| Flutter Analyze หน้า OCR/Contact/Route | ผ่าน — ไม่พบปัญหา |
| Flutter Analyze Visitor OCR | ผ่าน — ไม่พบปัญหา |
| Shared OCR Widget Test | ผ่าน 10/10 |
| Parser/Image/EXIF/Engine Test | ผ่าน 40/40 |
| OCR ภาพสร้างจริงภาษาอังกฤษ | ผ่านชื่อ บริษัท โทรศัพท์ และอีเมล |
| OCR ภาพสร้างจริงภาษาไทย | ผ่านชื่อ บริษัท โทรศัพท์ และอีเมล หลัง Normalize ช่องไฟอักษรไทย |
| API + ฐานจริง | ผ่าน Setting, Analyze, Create, Update, Delete, Duplicate, Upload และ Download |
| Security Negative | ไม่มี Token = 401, Target ไม่ถูกต้อง = 403 |
| Browser 8080 | ผ่าน Contact 1440/430px, Setting 430px และ Popup 1440/430px |
| Responsive Widget | ผ่าน 1440, 1024, 768, 430 และ 360px |

ข้อมูลตัวอย่างที่คงไว้:

- `OCR-DEMO-20261005 สมชาย ใจดี`
- บริษัท LAOO OCR Demo จำกัด
- มีภาพนามบัตรตัวอย่าง 1 รูป

## หมายเหตุ

- หน้า Customer เดิมมี Analyzer Warning เรื่อง dead code 16 จุดซึ่งมีอยู่ก่อนงาน OCR; การเชื่อม OCR ไม่มี Error ใหม่
- Machine Boundary ของ Service และ Visitor ผ่าน; `verify-center` ชุดรวมเดินถึง Test ลำดับ 26 แล้วค้างโดยไม่มี output จึงหยุดหลังรอเกิน 5 นาที ส่วน Test เป้าหมาย OCR/Service/Visitor ที่ระบุด้านบนผ่านครบ
- ยังไม่ได้วัดความแม่นยำจากนามบัตรกระดาษจริงหลายรูปหรือกล้องมือถือจริง ผล 40 เคสใช้ภาพสังเคราะห์ที่เรนเดอร์ด้วย Font จริง
- กล้อง Web จากเครื่องอื่นต้องใช้ HTTPS ตามข้อกำหนด Browser
- ไม่ได้เพิ่มสิทธิ์ตรงให้ `c111`; การทดสอบใช้ Company Admin `c` และ Backend ยังคงตรวจ Menu/Action Permission
