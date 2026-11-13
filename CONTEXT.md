> คำศัพท์และประวัติการตัดสินใจ: ดูข้อกำหนด Function รายระบบที่ [ดัชนีระบบ](docs/system/README.md) และหลักฐานการตัดสินใจใน `docs/adr/`; ตรวจ Source และข้อมูลปัจจุบันเมื่อมีข้อความขัดกัน

## Shared Location Master and Project Context

- `TDADBuilding`, `TDADFloor`, and `TDADRoom` are the single physical-location master for one Company. `14001 ผังสถานที่และพื้นที่` is Core-owned and is the only UI that creates, changes, or deactivates physical locations.
- Service, Visitor, and Meeting own only their business context. They reference the shared `BuildingID`, `FloorID`, and/or `RoomID`; they never duplicate a physical location master.
- Service resident records reference an active `RESIDENTIAL` `RoomID`. Visitor destination rules, when implemented, will reference the same `RoomID`. Location records with business references are deactivated instead of deleted.

# LAOO Platform

LAOO Platform รวมข้อมูลส่วนกลางและระบบธุรกิจหลายระบบไว้ในพื้นที่ทำงานเดียว โดยลูกค้าแต่ละรายเปิดใช้ระบบได้ไม่เท่ากัน

## Language

**Project**:
ระบบระดับบนสุดที่แบ่งขอบเขตผลิตภัณฑ์ใน Platform เช่น ข้อมูลส่วนกลาง ระบบห้องประชุม และระบบแจ้งซ่อม
_Avoid_: Module, Feature, กลุ่มเมนู

**Core Project**:
Project ข้อมูลส่วนกลางที่ทุก Company ใช้ร่วมกันและไม่ถือเป็นระบบธุรกิจที่ Partner จำหน่ายแยก
_Avoid_: Shared Menu, Common Screen

**Business Project**:
Project ระบบธุรกิจที่ Partner สามารถเปิดหรือปิดให้แต่ละ Company ได้
_Avoid_: Core Project, Feature

**Shared Person Identity**:
Company-scoped identity in `TDADPerson` used by every Project. It owns shared name and contact attributes but does not own Employee, Resident, or Service role details.
_Avoid_: copying one real person into separate Project person tables

**Project Person Role**:
A Project-owned relationship from one shared Person to a business meaning. Service roles currently include Resident (`TDADResident`) and Service Customer (`TDADServiceCustomer`); labels are derived from these relationships rather than edited independently.
_Avoid_: free-form role tags, exposing another Project's roles in a Project registry

**Time Management Project**:
Business Project สำหรับจัดการเวลาทำงาน ตารางการทำงาน การลา และผลสรุปเวลาของ Employee โดยใช้ข้อมูลบุคคลและโครงสร้างองค์กรจาก Core Project
_Avoid_: Core Project, ระบบพนักงาน, ระบบเงินเดือน

## คำศัพท์รายระบบ

- [ระบบลงเวลา](docs/system/time.md) — เวลา งาน กะ การลา และการอนุมัติ
- [ระบบสต๊อก](docs/system/stock.md) — สินค้า คลัง และรายการเคลื่อนไหว
- [ข้อมูลส่วนกลาง](docs/system/core.md) — บุคคล พนักงาน และข้อมูลร่วม

เอกสารรายระบบเก็บข้อความที่ย้ายครบจาก CONTEXT; ADR ยังคงเป็นประวัติการตัดสินใจ
