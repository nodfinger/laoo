# รายงานตรวจข้อกำหนด Function รายระบบ — 13 พฤศจิกายน 2569

## ขอบเขตที่ตรวจ

- `lib/app/router/app_menu_route_registry.dart`, Route/Feature contracts ของ 29 โมดูล, migration ที่เกี่ยวกับทะเบียนเมนู, สเปก Function ปัจจุบัน 5 ไฟล์
- สร้างดัชนี `docs/system/README.md` และไฟล์ระบบธุรกิจ; ทุก MenuCode ที่พบในแหล่งดังกล่าวมีไฟล์ปลายทาง
- ADR, drafts, reports และเอกสารสถาปัตยกรรมคงอยู่เพื่อเก็บที่มาและข้อเสนอที่ยังไม่ใช่ข้อกำหนดปัจจุบัน

## ช่องว่างที่ต้องตรวจต่อ

1. Route ไม่ได้ยืนยันว่าเมนูเปิดใช้จริงใน DB; ต้องเทียบ `TDADMainMenu`, `TDADProjectMenu`, permission และสถานะ migration ในฐานข้อมูลเป้าหมาย
2. หลายโมดูลมี Route แบบสร้างจาก slug; ดัชนีแสดง MenuCode/Route ตามโค้ด แต่ยังไม่ยืนยัน ScreenType และ ProjectCode เมื่อไม่มีหลักฐานตรง
3. เมนูจำนวนมากมีเพียง Route ไม่พบสเปก Input, Validation, Flow, State, ActionCode หรือ API ที่ยืนยัน; ไฟล์ระบบแต่ละไฟล์ระบุช่องว่างไว้ ไม่เติมกติกาจากการคาดเดา
4. `STOCK_RECEIPT.md`, `VENDOR.md`, `ITEM_PROJECT_DEFAULTS.md` เคยเรียกเมนูสต๊อกว่า Core `LAOO`; migration `20261107120000_LAOO_stock_project.sql` ย้าย 08001–08011 ไป `LAOO_STOCK` จึงเก็บข้อความเดิมไว้เป็นหลักฐานประวัติใน `stock.md` พร้อมข้อแก้ไขที่หัวไฟล์
5. `docs/architecture/MEETING_EXTRACTION_PLAN.md` มีแผนและ Placeholder; ใช้ `meeting.md` สำหรับ Function ที่ยืนยันจากสเปกจองห้อง ไม่ถือแผนเป็นสิ่งที่ implement แล้ว
6. ระบบจัดซื้อ/กฎหมายยังมีทะเบียนเมนูเบื้องต้น; Flow และตารางของระบบเต็มยังต้องตกลงก่อนพัฒนา

## ไฟล์สเปกที่ย้ายครบและลบต้นฉบับ

- `docs/STOCK_RECEIPT.md` → `docs/system/stock.md`
- `docs/VENDOR.md` → `docs/system/stock.md`
- `docs/ITEM_PROJECT_DEFAULTS.md` → `docs/system/stock.md`
- `docs/DELIVERY_NOTE_FLOW.md` → `docs/system/sales.md`
- `projects/meeting/docs/MEETING_ROOM_BOOKING_FUNCTIONS.md` → `docs/system/meeting.md`

เอกสาร AI, รายงาน inventory และแผนอื่นยังไม่ได้ย้ายครบ จึงไม่ลบต้นฉบับ
