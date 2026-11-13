# MON completion audit — 2026-09-27

สถานะ: ยังไม่ครบ ไม่ใช่การรับรองพร้อมใช้งานทุกระบบ

## บัญชีและหลักฐาน

- HEAD ที่สำรวจ: `91920f1` (SHA เต็มอยู่ใน inventory.json)
- สคริปต์ `tools/scripts/audit-project-completion.ps1` อ่านฐานข้อมูลและ Git แบบไม่แก้ข้อมูล สร้าง inventory.json และ menu-checklist.md ใน TEMP/laoo-completion-audit
- พบ 241 Project-menu mappings (ไม่ใช่ 241 หน้าจอไม่ซ้ำ), 18 worktree records และ 16 handover refs
- รวมทั้งเมนู inactive และ mapping inactive; เมนู 14003 เป็น RETIRED ห้ามเปิดกลับ
- สถานะเริ่มต้น NOT_TESTED หมายถึงยังไม่มีหลักฐาน runtime ไม่ใช่ผ่านหรือเสีย
- งานส่งมอบ pat/mhon ไม่เป็น ancestor โดยตรง แต่ไฟล์ CurrentUserHostIdentityController และ visitor_exceptions_repository เทียบ final tree แล้วตรงกัน จึงห้ามสรุปว่างานหายจาก SHA
- ยังต้องตรวจ worktree ที่มีงานค้างและไฟล์ส่งมอบที่เหลือทีละชุด ไม่มีการ reset/merge/push

## แก้ไขในรอบนี้

1. MeetingRoomUsageController: ปิด respondent SQL reader ก่อนอ่านแบบประเมินที่เลือก เพื่อรองรับ connection ที่ไม่เปิด MARS; local config ปัจจุบัน MARS=False
2. Vote bootstrap regression: เลิกคาดว่าไม่มี Route ตรวจ 5 Route จริงและ ScreenType 2/4/3/3/3 ตาม metadata
3. เพิ่มสคริปต์สำรวจซ้ำได้และ Checklist รายเมนู ไม่ส่งออก secret หรือข้อมูลผู้ตอบ

## ผลตรวจ

- Evaluation Release module build ผ่าน 0 warnings/errors
- Meeting Release module build ผ่าน 0 warnings/errors
- Evaluation Flutter tests ผ่าน 2 tests
- ชุด Route/Navigation รอบแรกผ่าน 12 tests และพบ Vote test เก่า 1 test; หลังแก้รันทดสอบซ้ำผ่านครบ 13 tests
- HTTP 8080 และ Swagger 5080 ตอบ 200 เป็นเพียง availability ไม่ใช่การพิสูจน์ UI/Workflow
- ไม่ได้ restart Center จึงยังไม่ยืนยันว่า Meeting fix ถูกโหลดใน runtime
- ยังไม่ได้ทดสอบ Browser ตามบทบาท, cross-company negatives, source-to-destination workflow หรือครบทุก UX state

## ค้างและลำดับถัดไป

- ตรวจ Metadata/Permission/Route/API และหลักฐานจริงทีละเมนูจาก checklist; ห้ามเปลี่ยน NOT_TESTED เป็น PASS จาก static inspection
- Evaluation: Master ประเภทและ mapping แบบเริ่มต้นตามประเภทบริการยังต้องเสนอ schema/migration และ Draft ก่อนดำเนินการ
- Evaluation: ตรวจ duplicate source event ที่อาจเขียนทับชื่อรอบร่าง และ privacy ของรายงานทุกทางเข้า
- Service: 14001, 19003, 20005 ยังเป็น placeholder; 14003 ถูกยกเลิก ส่วน ScreenType ของ 20005 ยังต้องตัดสินใจ
- Meeting/Training: ทดสอบการเลือกแบบ การตอบรับ/check-in ผู้มีสิทธิ์จริง และคืนห้องส่งรอบประเมิน
- Time/Visitor/Vote: Route tests ไม่แทนการทดสอบ Action, Permission, transaction และข้อมูลเชื่อมโยง
- โครงการที่มีเพียงโครงต้องยืนยัน Requirement และ Draft ก่อนสร้างหน้าจอ ไม่เปิดเมนูเอง
- ไม่ apply migration, ไม่ commit/push ในรอบนี้
