# LAOO_SCHOOL_FOOD — รายงานพัฒนา 2026-10-04

สถานะ: **อยู่ระหว่างพัฒนา — ยังไม่ครบระบบ** ข้อขัดแย้ง UX และ Core PR ได้รับอนุมัติและดำเนินการแล้ว

## สิ่งที่ทำแล้ว

- Bootstrap PR #99 merged: main commit 7f9d6ac (แยกงาน Visitor ออกทั้งหมด)
- Migration ทั้งสองไฟล์ใช้ runner กลางสำเร็จ: 20 ตาราง TDSF และ MenuCode 53001–53012
- ไม่เปลี่ยน schema ของ School, Company หรือ Inventory เดิม
- เพิ่ม API หลักและ Lifecycle: ร้านค้า สินค้า บัตร ตั้งค่า ค่าหัก Wallet ขาย คืนบางส่วน Transfer Report และ CSV
- เพิ่ม Flutter package และ route ครบ 12 เมนู; ตัวหน้าจอยังมี Action ที่ขาด ห้ามตีความว่า route ครบเท่ากับระบบครบ
- POS ใช้ API จริง ยอดชำระเด่น Product Grid และ Mobile cart; ปิดการชำระเมื่อยืนยันการเชื่อมต่อไม่ได้
- ตัวเลือกนักเรียน/สินค้าในฟอร์มค้นหาและแบ่งหน้าจาก API
- เพิ่ม Student token claim แบบ optional แยกประเภท พร้อมการตรวจไม่ให้ปน Company/Guardian/Support/Partner; Core PR #100 merge ที่ main f9d3cb0 แล้ว
- บันทึกการอนุมัติ Filter Card Padding 10px ใน docs/standards/SCHOOL_FOOD_UI_DECISIONS.md
- เพิ่ม Guardian Food API สำหรับรายชื่อลูกและประวัติ/สถิติ/Wallet พร้อมตรวจ active guardian, linked child, company และ subscription ซ้ำ
- เพิ่ม Portal นักเรียน /school/student/food และผู้ปกครอง /school/guardian/food ใช้ Token แยกในหน่วยความจำ ไม่แทน Session บริษัท; หน้าผู้ปกครองเดิมมีปุ่มเปิดประวัติอาหาร
- เพิ่มหน้าใบโอน Header–Detail ภายใน Shell เดิม: ดู/แก้/บันทึก/ส่ง/รับ ตาม Permission และสถานะ พร้อมกันส่งก่อนบันทึกการแก้ไข
- เพิ่ม UI กำหนดบัญชีนักเรียนและรหัสผ่านเริ่มต้นแบบซ่อนข้อความ, UI ปรับยอด Wallet พร้อมเหตุผลบังคับ
- เพิ่มตัวกรองช่วงวันที่ มิติห้องเรียน และทุกร้านค้าในรายงานฝั่งโรงเรียน
- พ่อสั่งเลื่อน Fingerprint ออกไปก่อนในรอบนี้ ไม่ถือเป็นเงื่อนไขส่งมอบรอบบัตร/QR และไม่อ้าง Hardware Acceptance

## Metadata และผลต่อเมนู

ชื่อและ ScreenType ตรวจจาก dbo.TDADMainMenu ใน DBTDLaooService หลัง Migration

| MenuCode | MenuName | ScreenType | UI | API | Permission | Integration | Status |
|---|---|---:|---|---|---|---|---|
|53001|ตั้งค่าระบบขายอาหารในโรงเรียน|2|เขียน inline form; ยังไม่ทดสอบภาพ|settings ผ่าน controller|ตรวจสิทธิ์จริง|ยังไม่ Browser|PARTIAL|
|53002|ข้อมูลร้านค้าในโรงเรียน|1|List/Card/Add/Edit/Delete/ผูกผู้ใช้ร้านแล้ว|create/edit/delete/list users ผ่านฐานจริง|Company และ Shop scope ผ่านบางเคส|Popup 360/1440px ผ่าน; ยังไม่ Browser|PARTIAL|
|53003|สินค้าที่ขายแยกตามร้านค้า|2|แก้ราคา/เปิดขายในหน้า|assign/products ผ่าน|ตรวจ menu/shop|ยังไม่ Browser|PARTIAL|
|53004|กำหนดเปอร์เซ็นต์หักยอดขาย|2|แก้รายสินค้าและประเภท; อัตราร้านอยู่ในฟอร์มร้านค้า|precedence, snapshot และ category lookup ผ่าน|ตรวจ EDIT|ยังไม่ Browser|PARTIAL|
|53005|บัตรและลายนิ้วมือนักเรียน|1|CARD/QR ระงับและกำหนดบัญชีนักเรียนแล้ว|เลขบัตรตัวอย่างถูก/ผิด/ระงับผ่านฐานจริง|ตรวจสิทธิ์ราย action|คืนสถานะบัตรตัวอย่างแล้ว; Fingerprint เลื่อนตามคำสั่งพ่อ|PARTIAL|
|53006|โอนและรับสต๊อกร้านค้า|4|Header–Detail ดู/แก้/บันทึก/ส่ง/รับ/ยกเลิกแล้ว|create/send/receive/edit/cancel ผ่าน|ตรวจ scope|Widget flow ผ่าน 2 viewport; concurrency ยังไม่ครบ|PARTIAL|
|53007|Wallet และการเติมเงิน|4|รายการ/เติมเงิน/ปรับยอด/ประวัติ Ledger แบบแบ่งหน้าแล้ว|topup/sale/refund และ rollback ผ่าน|Company/Partner ผิดถูกปฏิเสธ|Popup 360/1440px ผ่าน; ยังไม่ Browser|PARTIAL|
|53008|ขายหน้าร้าน|4|POS กรอกเลขบัตรจำลอง กด Enter ตรวจนักเรียนก่อนเลือกสินค้า/ชำระ; เปลี่ยนบัตรแล้วล้างตัวตนและตะกร้า|ค้นบัตรและขายเก็บ/ไม่เก็บสต๊อกผ่าน|ค้นบัตรต้องมี SALE และ Shop scope|Widget 360/1440px, HTTP/JWT และฐานจริงผ่าน; ยังไม่ลองเครื่องอ่านบัตรจริง|PARTIAL|
|53009|ประวัติขายและคืนสินค้า|4|ดูรายละเอียด/คืนบางส่วนเขียนแล้ว|คืนบางส่วน/เกิน/ซ้ำผ่าน|ตรวจ REFUND|ยังไม่ Browser|PARTIAL|
|53010|ประวัติการซื้อของนักเรียน|3|Portal นักเรียน/ผู้ปกครองและช่วงวันแล้ว|รายงาน/บัญชีนักเรียนผ่าน Controller|Student/Guardian scope ผ่าน|Portal widget ผ่าน 12 เคส; HTTP ยังไม่ครบ|PARTIAL|
|53011|กระทบยอดร้านค้า|3|ช่วงวันและทุกร้านแล้ว|ลงเงินคืนตามวันคืนจริงแล้ว|ตรวจ scope|ยังไม่รับรองบัญชีข้ามวัน|PARTIAL|
|53012|Dashboard และรายงาน|3|มิติ/ช่วงวัน/ทุกร้านและปุ่ม Export CSV แล้ว|มิติและ CSV ผ่าน|ตรวจ VIEW/EXPORT|Widget callback และ HTTP ผ่าน; ยังไม่ Browser|PARTIAL|

## ข้อมูลทดสอบจริง

Run ID: SF_20261004_DEMO; Company ของ c111 (CompanyID 1)

- นักเรียนใหม่ SFDEMO001 / SFDEMO002 ไม่แก้รายชื่อนักเรียนเดิม
- ระดับ/ห้องเรียนทดสอบ SFDEMO-M3 / SFDEMO-3/2
- ร้าน SFDEMO-FOOD เก็บสต๊อก และ SFDEMO-DRINK ไม่เก็บสต๊อก
- คลัง SFDEMO-CENTRAL / SFDEMO-SHOP และสินค้า SFDEMO-RICE / SFDEMO-WATER
- บัตรทดสอบ SFDEMO-CARD001 / SFDEMO-CARD002
- เติมเงินจำลอง 500 ขาย 80 คืน 35 ขายร้านไม่เก็บสต๊อก 10: Wallet SFDEMO001 คงเหลือ 445 บาท
- โอนสินค้า 20 ต่อชนิดเข้าร้าน หลังขาย/คืนเหลือข้าว 19 น้ำ 19 หน่วย
- เปิด School Food Trial 30 วันเฉพาะ Company ทดสอบและสิทธิ์ c111; Subscription/CompanyProject/CompanyFeature บันทึกใน Transaction เดียวพร้อม Audit
- เพิ่มผู้ปกครองตัวอย่าง SFDEMO-G ผูกเฉพาะ SFDEMO001; ไม่ใส่รหัสผ่านใหม่ ไม่เปลี่ยนรหัสผ่านผู้ใช้เดิม ไม่มีเงินจริงหรือ Payment Gateway
- SQL Seed ทำซ้ำได้; ชุด retire ปิดใช้เฉพาะนักเรียน/สินค้า/ร้านตาม Run ID โดยไม่ลบ Wallet Ledger หรือประวัติ ยังไม่ได้รัน retire

## หลักฐานทดสอบ

|ชุดตรวจ|ผล|
|---|---|
|Center gate -Module service ก่อน Bootstrap merge|ผ่าน; analyzer เดิมมี warnings/info ที่ไม่ใช่ School Food|
|School Food rules|21 ข้อผ่าน|
|ฐานจริง/Controller integration รอบล่าสุด|120 ข้อผ่าน รวมค้นบัตรถูก/ผิด/ระงับ/ข้าม Company, ยิงขายซ้ำพร้อมกันด้วย key เดียว, Wallet Ledger และยอดกระทบยอดร้านค้า|
|Student token contract (isolated)|17 ข้อผ่าน|
|Flutter responsive และ flow widget tests (mock API)|83 ข้อผ่าน รวม 60 เมนู/viewport, 12 Portal, 2 Transfer, 4 Popup, Export, Commission และ Enter ค้นบัตรที่ 360/1440px; ยังไม่ใช่ Browser end-to-end|
|Rendered Portal fixtures|ตรวจภาพ 360px และ 1440px หลังโหลด NotoSansThai/MaterialIcons; รูปอยู่ artifacts/school-food ไม่ commit|
|Flutter web debug build หลังเชื่อม Portal/Transfer/CSV/POS card Enter|ผ่าน build/web ล่าสุด; ยังไม่ได้ deploy/restart 8080|
|Route security regression|14 เคสผ่าน รวม Portal public แบบ exact path และหลังบ้านยังต้อง Login|
|Flutter analyze projects/school_food/lib และ lib/main.dart|No issues found|
|School Food module Release build|ผ่าน|
|HTTP/JWT end-to-end|26 ข้อผ่าน Center API 5081 กับฐานจริง รวมเลขบัตรถูก/ผิด/ชนิดผิด, anonymous/guardian ถูกปฏิเสธ, Guardian/Student, Ledger, Shop Users และ CSV; ล้าง Credential ชั่วคราวแล้ว|
|Browser screenshots, Android, device hardware|Chrome widget runner เปิด Chrome และ frontend compiler แต่ไม่เริ่มเคสหลังรอเกิน 3 นาที จึงหยุดและไม่อ้างว่าผ่าน; Android SDK ขาด cmdline-tools ตาม flutter doctor; Fingerprint เลื่อนตามคำสั่งพ่อ|
|Shop user negative cases, concurrent requests|ยิงขายซ้ำพร้อมกันด้วย key เดียวผ่านและไม่หัก Wallet ซ้ำ; ยังไม่ได้ทดสอบหลาย key พร้อมกันและสิทธิ์ผู้ใช้ร้านค้าทุกแบบ|

Integration tests เรียก Controller โดยใช้ Test principal กับฐานจริง จึงยืนยัน SQL/Transaction/Guard ได้ แต่ไม่ใช่หลักฐานว่า HTTP authentication middleware ผ่าน
รัน integration regression รอบล่าสุดผ่าน 120 เคส และ HTTP/JWT ผ่าน 26 เคส; ทดสอบ credential ชั่วคราวเฉพาะ SFDEMO002 และล้าง credential ทดสอบแล้ว บัตร SFDEMO-CARD001 กลับมา Active; ไม่ลบ Ledger หรือประวัติการเงิน

## งานค้างและจุดตัดสินใจ

1. ข้อยุติ UX: พ่ออนุมัติใช้ 10px แล้ว ไม่มีจุดรออนุมัตินี้
2. Core token contract merge แล้ว ไม่มีจุดรออนุมัตินี้
3. Student Login/credentials/change-password, API และหน้าจอ Student/Guardian Portal เชื่อมแล้ว; HTTP authentication middleware ผ่าน 21 เคส แต่ยังต้องทดสอบ Browser กับฐานจริง; Fingerprint เลื่อนตามคำสั่งพ่อ ไม่ต้องดำเนินการในรอบนี้
4. ตรวจ validation/ScreenType ทุก action, error/retry/key lifecycle และสิทธิ์ผู้ใช้ร้านค้าแบบ negative เพิ่ม
5. Date filters, มิติห้องเรียนและ Export UI ทำแล้ว; ยังต้องแสดงชื่อระดับชั้นแทน ID; API 53011 แยกยอดคืนตามวันคืนจริงแล้ว (REFUND_EVENT_DATE) ทดสอบยอดขาย 80 คืน 35 ค่าหักสุทธิ 4.30 จ่ายร้าน 40.70 ผ่าน แต่ยังต้องทดสอบคืนข้ามวันจริง
6. ทดสอบทุก role, การขายพร้อมกันด้วยหลาย request key, expiry/suspend, Browser จริงที่ 1440/1024/768/430/360 และ Android; same-key parallel retry, rollback และ stock ผ่านแล้ว
7. ตรวจภาพจริงตาม flutter-ui-design ก่อนสรุปความสมบูรณ์ UX

ยังไม่ได้ Restart API 5080 หรือ Flutter 8080 ในรอบนี้ จึงไม่อ้างว่า Browser กำลังแสดงโค้ดล่าสุด; API ทดสอบชั่วคราว 5081 หยุดแล้ว
เส้นทางใหม่หลังเปิด runtime ล่าสุด: /#/school/student/food และ /#/school/guardian/food; หน้าผู้ปกครองเดิมมีปุ่มส่งต่อ Token ใน memory ไปประวัติอาหารโดยไม่ต้อง Login ซ้ำ
Working tree ไม่สะอาดเพราะเก็บงาน Visitor เดิมและงาน business School Food ที่ยังไม่ commit ไว้ทั้งหมด
