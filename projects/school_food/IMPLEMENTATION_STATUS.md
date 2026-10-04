# LAOO_SCHOOL_FOOD — บันทึกระยะแรกก่อนอนุมัติ Migration

> สถานะล่าสุดอยู่ใน [COMPLETION_REPORT.md](COMPLETION_REPORT.md) บันทึกด้านล่างเก็บไว้เป็นประวัติ ไม่ใช่สถานะปัจจุบัน

สถานะ: **อยู่ระหว่างพัฒนา ยังไม่พร้อมรับรองการใช้งานจริง**

## งานที่เพิ่ม

- Draft HTML: docs/drafts/school-food-draft.html ได้รับอนุมัติ Layout
- โมดูล .NET แยกใน projects/school_food/packages/dotnet/Laoo.SchoolFood.Module
- API ตั้งค่า ร้านค้า สินค้า อัตราหัก บัตร Wallet ขาย คืนสินค้า โอนสินค้า และรายงาน
- Transaction รวม Wallet/Sale/Stock/Commission พร้อม Idempotency Key
- ตัวตรวจ Subscription ของ SCHOOL และ SCHOOL_FOOD และ CompanyMenuAccess
- Shop Scope รวมกรณีปิดการผูกร้านโดยไม่ยกระดับสิทธิ์เป็นผู้ใช้ทั้งโรงเรียน
- Center ApplicationPart/ProjectReference และ Migration Runner mapping
- Migration เตรียมไว้ 2 ไฟล์ **ยังไม่รัน**

## ผลตรวจที่มีหลักฐาน

| การตรวจ | ผล |
|---|---|
| Build SchoolFood Module Release | ผ่าน ไม่มี Warning/Error |
| Build Center API Release | ผ่าน ไม่มี Warning/Error |
| Rule/contract executable tests | ผ่าน 21 ข้อ |
| Partial refund rounding | ครอบคลุมยอด 0–1,000 สตางค์ และจำนวน 1–20 หน่วย รวม 20,020 ชุด |
| Migration runner DryRun | พบ 2 ไฟล์ตาม Namespace; ไม่เชื่อมฐาน ไม่ตรวจ SQL runtime |
| git diff --check | ผ่าน; มีเพียงคำเตือน LF/CRLF |

คำสั่งทดสอบ:

```powershell
dotnet run --project projects/school_food/tests/Laoo.SchoolFood.Rules.Tests -c Release
dotnet build laoo_api/laoo_api.csproj -c Release
powershell -NoProfile -ExecutionPolicy Bypass -File tools/scripts/run-migrations.ps1 -Module school_food -DryRun
```

การทดสอบกติกาไม่ใช่หลักฐานว่า Transaction, SQL, HTTP Permission หรือ Concurrent Sale ผ่านแล้ว

## ผลกระทบ Migration ที่รออนุมัติ

- ฐานตาม local configuration: DBTDLaooService ต้องยืนยันก่อนรันอีกครั้ง
- Bootstrap: เพิ่ม Project, กลุ่ม 53, เมนู 53001–53012, Permission และ Package/Feature
- ก่อนรันมี Guard ป้องกันการทับ Project/กลุ่ม/MenuCode ที่มีอยู่
- เพิ่มตาราง TDSF จำนวน 20 ตาราง พร้อม Index, FK, Constraint และ Trigger ป้องกันแก้/ลบ Wallet Ledger
- ไม่ลบข้อมูลเดิม ไม่ ALTER ตารางนักเรียน/สินค้า/คลัง
- อ้างอิงข้อมูล SCHOOL และ Inventory เดิม; เมื่อเปิดใช้งานจริง API ขาย/รับโอน/คืนจะเขียน Stock Balance และ Movement กลาง
- ยังไม่เปิด Subscription หรือแจกสิทธิ์ให้ Company ใด
- ไม่ Seed ข้อมูลทดสอบหรือยอดเงินจริงในรอบนี้
- Runner ทำ Transaction ต่อไฟล์ ไม่ใช่ทั้งสองไฟล์พร้อมกัน; ถ้าไฟล์สองล้มเหลว Bootstrap อาจยังอยู่ ต้องปิดการเปิดสิทธิ์ไว้จนผ่านครบ
- ต้อง Sync main ตามกติกาก่อนรันผ่าน tools/scripts/run-migrations.ps1 เท่านั้น

## Gate และงานค้าง

1. อนุมัติ Bootstrap PR ของ Center และ Migration ตามกติกาโครงการใหม่; ยังไม่ Commit/Push
2. ตรวจ MenuName/ScreenType จากฐานหลัง Migration แล้วจึงสร้าง Flutter หน้าจอจริง 12 เมนู
3. เติม Action ที่ยังไม่ครบ: Delete Master/Identifier, แก้/ยกเลิก Transfer, Export และ Settlement Posting
4. Student Login/Portal และ Guardian Food Portal ยังไม่ได้ทำ; ต้องแยก Core authentication contract review ก่อน
5. Fingerprint Adapter/Simulator และ Device management ยังไม่ได้ทำ; ไม่มีผล Hardware Acceptance
6. เตรียมและรัน Seed ที่มี Run ID และ Cleanup แบบปลอดภัย หลังโครงสร้างพร้อม
7. ทดสอบ SQL/API จริง: Scope, Permission, Cross-company/shop, Request ซ้ำ/พร้อมกัน, Rollback, Wallet, สต๊อก, คืนบางส่วน
8. ทดสอบ Flutter Web/PWA/Android และ Responsive รวมเครือข่ายขาด; ยังไม่มีผลทดสอบหน้าจอจริง
9. รายงานปัจจุบันอ้างการคืนกลับไปวันที่ขายเดิม (ORIGINAL_SALE_DATE) ไม่ใช่รายงานเงินสดตามวันที่คืน และยังไม่ใช่การปิดกระทบยอด
10. Transfer ปัจจุบันตรวจ/เคลื่อนสต๊อกเมื่อรับ ไม่กันสต๊อกตอนส่ง ต้องแสดง Flow นี้ชัดเจนและทดสอบสินค้าคงเหลือเปลี่ยนระหว่างส่ง–รับ

ไม่มีการ Restart Runtime หรือแก้ข้อมูลของผู้ใช้ งาน Visitor ที่มีอยู่ก่อนถูกเก็บไว้ ไม่รวมเป็นผลงาน School Food
