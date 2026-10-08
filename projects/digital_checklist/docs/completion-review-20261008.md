# LAOO_DIGITAL_CHECKLIST — completion review (2026-10-08)

สถานะ: **พร้อมทดสอบ** แต่ยังไม่อ้างว่า “พร้อมใช้งาน”: Browser ทั้ง 10 เมนู, Responsive หน้างานตรวจ, Popup ส่งผล, การกดส่งพร้อมกัน และ predicate ปฏิทินขอบเดือน/ปีผ่านแล้ว; ยังขาดการทดสอบ Login ข้าม Company/ผู้ไม่มีแผนก, การส่งอีเมลจริงแบบปลอดภัย และข้อกำหนดวันหยุด

| MenuCode | MenuName | ScreenType | UI | API | Permission | Integration | Status |
|---|---|---:|---|---|---|---|---|
| 58001 | ตั้งค่าระบบตรวจสอบดิจิทัล | 2 | route ผ่าน | GET/PUT ผ่าน | c111 ผ่าน | Setting + Audit บันทึกจริง | PARTIAL |
| 58002 | กลุ่มและประเภทการตรวจ | 1 | route ผ่าน | group CRUD/type create ผ่าน | แผนกอื่น 403 | ผูกแผนก IT จริง | PARTIAL |
| 58003 | แบบตรวจสอบ | 1 | route ผ่าน | create + items ผ่าน | c111 ผ่าน | แผนเดิมใช้ template snapshot แม้มี V2 | PARTIAL |
| 58004 | สายอนุมัติ | 1 | route ผ่าน | create/directory ผ่าน | ผู้อนุมัติต่างแผนก | สองขั้น a1 → tu1 | PARTIAL |
| 58005 | แผนตรวจและผู้รับผิดชอบ | 1 | route ผ่าน | create/options ผ่าน | c111 ผ่าน | 6 แผนตัวอย่าง, worker สร้างรอบ | PARTIAL |
| 58006 | งานตรวจของฉัน | 4 | route ผ่าน | submit/items/evidence ผ่าน | a1/tu1 เห็น 0 งานของ IT | PASS/FAIL, return/version, รูป | PARTIAL |
| 58007 | งานรออนุมัติ | 3 | route ผ่าน | approve/return ผ่าน | a1/tu1 เห็นเฉพาะงานส่งถึงตน | อนุมัติ 2 ขั้น, กันกดซ้ำ/รูปขาด | PARTIAL |
| 58008 | งานแก้ไขและส่งแจ้งซ่อม | 3 | route ผ่าน | handoff ผ่าน | a1/tu1 ถูกปฏิเสธ 403 | สร้าง TDADServiceRequest ID 21 | PARTIAL |
| 58009 | ประวัติและ Audit | 3 | route ผ่าน | GET ผ่าน | AUDIT guard ผ่าน c111 | Audit ของการส่ง/อนุมัติ/ส่งต่อ | PARTIAL |
| 58010 | Dashboard และรายงาน | 3 | route ผ่าน | GET ผ่าน | VIEW guard ผ่าน c111 | สรุปจาก TDCLInspection | PARTIAL |

## ฐานและข้อมูลตัวอย่าง

- รัน Migration ผ่าน `tools/scripts/run-migrations.ps1 -Module digital_checklist`: Bootstrap/Schema สำเร็จ; ฐานมี 10 เมนู และ 16 ตาราง TDCL
- Run ID: `DCL_20261008_DEMO`, Company DEMO (CompanyID 1), c111 ผู้ตรวจ, a1/tu1 ผู้อนุมัติต่างแผนก
- Trial, 6 แผน (รวมแผนที่สร้างผ่าน API), รอบ Daily/Weekly/Monthly/Yearly, CCTV/Backup, งาน PASS/FAIL/NEGATIVE/EVIDENCE
- Worker สร้างรอบของวันจริง 5 รายการ และสร้าง Notification; ส่งผล PASS/FAIL, ส่งกลับ PASS แล้วส่ง Version 2, อนุมัติครบ, งาน FAIL สร้าง Corrective Task
- รูป PNG ตัวอย่างแนบผ่าน API เป็น AttachmentID 1; ก่อนแนบรูป การอนุมัติ FAIL ได้ 409; หลังแนบรูป อนุมัติครบ
- รายการ NEGATIVE ทดสอบการกู้รูป: ก่อนแนบ `canUploadEvidence=true`, หลังแนบ PNG ผ่าน API เป็น `false`; UI มีปุ่มแนบรูปที่ค้างให้ผู้มีสิทธิ์
- ไฟล์ seed และ retire อยู่ใน `database/test-data`. Retire ตั้งใจปฏิเสธการลบเมื่อมีไฟล์หลักฐานหรือ Service Handoff เพื่อรักษาประวัติจริง

## หลักฐานทดสอบ

- Center API Release build: 0 warnings, 0 errors; runtime `http://localhost:5080/health` 200
- c111 Login ผ่าน Center token LAOO; Navigation API แสดงเมนู 58001–58010 ครบ; actions และ data ตอบ 200 ทั้ง 10 เมนู
- Flutter module analyze: no issues; route-contract test: 1 ผ่าน; Center verify: ผ่าน (root analyze ยังคงมี warnings/info เดิม 282 รายการนอกโมดูล)
- Flutter web-server เปิด `http://localhost:8080` และตอบ 200; Playwright/Chrome Login c111 ผ่าน แล้วเปิดหน้า 58001–58010 จริง ทุกหน้าแสดงข้อมูลหรือ Empty State ตามข้อมูลและไม่พบข้อความโหลดไม่สำเร็จ (หน้า 58004 ใช้เวลารอข้อมูลนานกว่า 2 วินาที)
- ตรวจหน้ารายการ 58006 ที่ 1440/1024/768/430/360 px หลังแก้: ไม่มี Flutter console error/overflow และไม่มี document horizontal overflow; เมื่อพื้นที่แคบกว่า 900px เปลี่ยนเป็น Card อัตโนมัติ, Caption ยังอ่านได้ที่ 360px
- Browser พบ `setState() or markNeedsBuild() called during build` จาก User Profile Theme Loader ก่อนแก้; หลังเลื่อนการอัปเดตธีมไปหลัง frame ทดสอบ Login/เปิดหน้า/ย่อจอซ้ำ ไม่พบ error
- ส่งรอบตรวจเดียวกันพร้อมกัน 2 คำขอด้วย fixture `DCL-1-20261008-1600`: ได้ `200,409`, เหลือ Version 1 ในสถานะ `IN_APPROVAL` เพียงรายการเดียว
- Negative API: ไม่มี token 401; ผู้อนุมัติที่ไม่มีเมนูอื่น 403; ส่งซ้ำ/อนุมัติซ้ำ/ส่งแจ้งซ่อมซ้ำ 409; ขาดข้อบังคับหรือ item ไม่อยู่ใน template 400; ไฟล์ไม่พบ 404
- API template items เลือก template ของ schedule เดิม (ID 1) แม้สร้าง template V2 (ID 4); งานอิสระเลือก V2

## งานที่ยังต้องพิสูจน์

- Popup/Touch/Keyboard ใน Browser ยังไม่ได้พิสูจน์ครบทุก Action และทุกเมนู; ภาพภาษาไทยของ 58006 ที่ 360px ตรวจแล้ว แต่อีก 9 หน้ายังต้องตรวจภาพละเอียด
- Negative แบบ Login จาก Company อื่น/ผู้ไม่มีแผนกยังขาดบัญชีทดสอบเฉพาะ; วันหยุดยังไม่มีข้อกำหนดว่าจะข้ามหรือสร้างรอบ; Email delivery ยังไม่ทดสอบ (fixture ปิด NotifyEmail)
- UI เลือกรูปก่อนส่งผล FAIL แล้ว; ถ้าอัปโหลดหลังส่งล้มเหลว มีปุ่มแนบรูปที่ค้างและ Backend กันอนุมัติจนหลักฐานครบ แต่ยังต้องทดสอบปุ่มนี้ใน Browser จริง
- Swagger JSON ที่ `/swagger/v1/swagger.json` ยังตอบ 500; พบตั้งแต่ API build เก่าก่อนเปิด Digital Checklist ต้องตรวจแยก

ไม่มีการ commit/push งานชุดนี้

## การแก้จาก Browser รอบนี้

- `LaooCaptionCard` ส่วนกลางแยก Action ลงแถวถัดไปเมื่อพื้นที่แคบ เพื่อไม่ให้ Caption หาย; ดาวยังอยู่ถัดจากชื่อ
- หน้า Digital Checklist ซ่อนปุ่มสลับ List/Card และใช้ Card แบบความสูงตามเนื้อหาอัตโนมัติเมื่อ Content Area <900px
- Card มือถือซ่อน key ภายใน (`scheduleId`, `typeId`) และแสดงรหัส/กำหนดตรวจ/สถานะด้วยหัวข้อภาษาไทย; ตรวจภาพจริงที่ 360px แล้ว
- ที่ 360px กด Action ใน Card งานตรวจแล้ว Popup ขั้นเลือกประเภทและขั้นกรอกรายการเปิดได้ ส่งผลผ่าน Browser สำเร็จเป็น Inspection ID 7 / Version 1 / `IN_APPROVAL` พร้อม 2 รายการและ 2 ขั้นอนุมัติ
- User Profile Theme Loader อัปเดต theme หลัง frame เพื่อลดการ notify ระหว่าง Flutter build
- `dart format` เฉพาะ 3 ไฟล์, `flutter analyze` เฉพาะ 3 ไฟล์และโมดูลผ่าน, route test 1 ผ่าน, `git diff --check` ผ่าน (มีเพียง LF/CRLF warning)

## ผลทดสอบเพิ่มเติมรอบ 2026-10-08

- ตรวจฐานจริง: เมนู 58001–58010 และ ProjectMenu ครบอย่างละ 10 รายการ; ตัวอย่าง `DCL_20261008_DEMO` อยู่ CompanyID 1
- Browser 360px: เปิด Popup งานตรวจ เลือกประเภท กรอกผล แล้วส่งสำเร็จ; `DCL-5-20261008-2100` กลายเป็น `IN_APPROVAL`, Version 1, มี InspectionItem 2 และ Approval 2 รายการ โดยไม่มี console error
- Browser เมนู 58001: บันทึกค่าเดิมผ่าน Popup แล้ว Alert สำเร็จแสดงทันทีและหายหลังเวลาที่กำหนด (`TimeAlert=3` วินาที); แก้ `setState() callback returned a Future` ใน `digital_checklist_page.dart` ด้วย `_reload()` ที่ callback คืนค่า `void`; ทดสอบซ้ำไม่พบ error
- ทดสอบส่งรอบเดียวกันพร้อมกัน 2 คำขอ: ได้ HTTP `200/409` และมี Version 1 เพียงรายการเดียว; ไม่เกิดผลตรวจซ้ำ
- จำลอง predicate ของ Scheduler ด้วยวันที่ขอบเดือน/ปี 7 กรณี: เดือนเมษายนไม่มีวันที่ 31, พฤษภาคมมีวันที่ 31, 29 กุมภาพันธ์ปีอธิกสุรทิน, กุมภาพันธ์ปีปกติ, วันรายสัปดาห์ตรง/ไม่ตรง และวันอาทิตย์แบบรายวัน; ผลตรงคาด 7/7 (ยังไม่ใช่การเร่งเวลา Worker จริง)
- API ปฏิเสธแผนกอ้างอิงต่าง Company, เวลาซ้ำ, weekday 8 และรายการเวลาเปล่า ด้วย HTTP 400; ตรวจฐานไม่พบแผนทดสอบที่ปฏิเสธ
- `verify-center.ps1 -Module digital_checklist` ผ่าน: Flutter root tests 243 ผ่าน, route test 1 ผ่าน, module analyze no issues, Center/API module Release build 0 warnings/errors; root analyze ยังมี 282 warnings/info เดิมนอกโมดูล
- ยังไม่มี credential สำหรับบัญชีต่าง Company หรือผู้ไม่มีแผนก จึงไม่ได้อ้างว่า runtime 403 สองกรณีนี้ผ่าน แม้ query ฐานพบผู้ใช้ Company 1 จำนวน 13 รายที่ไม่มีแผนกมีผล; การปฏิเสธ foreign department เป็นเพียงหลักฐานกัน reference ข้าม Company
- DEMO ปิด `NotifyEmail`; มี Notification ค้าง 22 รายการ หากเปิดส่งทันทีอาจส่งถึงผู้รับจริงย้อนหลัง จึงไม่ได้เปลี่ยนค่าและยังไม่อ้างว่า SMTP delivery ผ่าน ต้องใช้ mail sink/บัญชีทดสอบแยกและกำหนดนโยบายรายการค้างก่อน
- การบันทึกค่า Settings เดิมและการส่งผลตรวจตัวอย่างเพิ่ม Audit/ผลตรวจตาม Flow; ไม่มีการเปิดอีเมลจริง ไม่มี Migration และไม่มี commit/push ในรอบนี้
