# Visitor Checklist

อัปเดต: 24/09/2569
ขอบเขต: `projects/visitor/**`

## Flow ที่ทำแล้ว

```text
กำหนดค่าระบบ Visitor
  → กำหนดจุดติดต่อและพนักงานประจำจุด
  → รปภ Login ที่จุดติดต่อ
  → รับผู้มาติดต่อ / เลือกผู้รับรอง / แนบหลักฐาน
  → รายการผู้ที่ยังอยู่ภายใน
  → ดูรายละเอียด / เพิ่มข้อความ / เพิ่มหลักฐาน
  → Check-out และเก็บประวัติ
```

## ทำแล้ว

- [x] `36004` กำหนดค่าระบบ Visitor: วิธีบันทึก, ข้อมูลบังคับ, นโยบายหลักฐาน และ Version/Audit
- [x] `33001` กำหนดจุดติดต่อ: จุดสังกัดสาขา, ผูกพนักงานหลายคน, พนักงาน Active อยู่ได้จุดเดียว
- [x] `31002` รับผู้มาติดต่อ: รู้จุดติดต่อและสาขาจากพนักงานที่ Login
- [x] รองรับผู้รับรองตาม Company Type ที่หน้า Check-in
- [x] รับข้อมูลแบบคีย์อิสระและถ่ายรูปบัตร
- [x] หลักฐาน Check-in: เอกสารบัตร, รูปรถ และรูปอื่น
- [x] Preview รูปก่อนบันทึก, ลบรูปที่เพิ่งเลือกได้, ลดรูปอัตโนมัติให้ไม่เกิน 1 MB
- [x] `31002` เปิดเป็น List ผู้ที่ยังอยู่ภายใน พร้อมรับผู้มาติดต่อและ Check-out ในเมนูเดียว
- [x] ดูรายละเอียด Visit, เพิ่มข้อความ, เพิ่มหลักฐาน และตรวจ Audit
- [x] Check-out: ผลการเข้าพบ, เหตุผล, หมายเหตุ, ผู้ปฏิบัติงาน และหลักฐานขาออก
- [x] `31005` ประวัติผู้มาติดต่อ: ค้นหาและดูรายการ Check-out แบบอ่านอย่างเดียว
- [x] Visitor migration ผลการเข้าพบ/หลักฐาน: `20260923100000_LAOO_VISITOR_visit_outcome_evidence.sql`

## กำลังทำ

- [ ] `32003` ยืนยันการเข้าพบ: UX Mobile-first แสดงทีละ 1 รายการ
- [x] UX Preview: สลับรายการผ่าน `รอเข้าพบอีก`, ดู Thumbnail/Preview หลักฐาน, ยืนยันเข้าพบ/ไม่ได้เข้าพบ
- [ ] เชื่อม API จริงสำหรับคิวผู้รับรอง, รายละเอียดหลักฐาน, และบันทึกผลยืนยัน
- [ ] เปิดรูปจริงผ่าน API ที่ตรวจสิทธิ์ผู้รับรอง
- [ ] Migration ยืนยันการเข้าพบ: `20260924100000_LAOO_VISITOR_host_confirmation.sql` (สร้างแล้ว แต่ยังไม่รัน)
- [ ] ทดสอบ Mobile, Permission, Company Scope และการยืนยันซ้ำ

## สิ่งที่รอ Core

- [ ] Shared API `GET /api/company/current-user/host-identities`
- [ ] Resolve User ที่ Login ไปยัง Employee, Resident, Service Customer และ Tenant Contact
- [ ] เปิด Menu `32003 ยืนยันการเข้าพบ` พร้อมสิทธิ์ `VIEW`, `EDIT`
- [ ] หลัง Core merge: Sync main, รัน Visitor migration ผ่านสคริปต์มาตรฐาน, เชื่อมและทดสอบจริง

## Scope ถัดไปที่คาดไว้

- [ ] แจ้งเตือนผู้รับรองในระบบหลัง Check-in เมื่อ Core Notification พร้อมใช้
- [ ] ประวัติการยืนยันเข้าพบสำหรับผู้ดูแล/รปภ
- [ ] Pre-register และสถานะอนุมัติ (`32001`, `32002`)
- [ ] Dashboard, Report, Exception และ Timeline Visitor
- [ ] Notification Inbox/History/Channel และ Audit/Watchlist/Retention ตามเมนูที่มีอยู่

## Checklist ทดสอบก่อน Push

- [ ] `dotnet build .\laoo_api\laoo_api.csproj`
- [ ] `flutter analyze projects/visitor`
- [ ] `flutter test projects/visitor/test`
- [ ] Boundary Check และ Verify Center ของ Visitor
- [ ] ทดสอบ Check-in → หลักฐาน → Detail → Check-out → History
- [ ] ทดสอบ Host Confirm หลัง Core Contract และ Migration พร้อม
