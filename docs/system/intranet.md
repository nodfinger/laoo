# ระบบ Intranet

## ข้อกำหนดปัจจุบันที่ยืนยันจากคำสั่งงาน

- `43001` ตั้งค่า Intranet: การเปิดใช้เนื้อหา วันเกิด พนักงานใหม่ วันหยุด ข่าว วิดีโอ ภาพกิจกรรม และบริการอื่น; กำหนดช่วงแสดงวันเกิด, อายุข้อมูลพนักงานใหม่ และขนาดรูปข่าว/กิจกรรม
- `43002` เนื้อหา: ประเภทประกาศ เอกสาร ข่าว กิจกรรม วิดีโอ; การเลือกกลุ่มเป้าหมายเฉพาะประกาศ; ตั้งเวลาเผยแพร่/สิ้นสุด; อัลบั้มกิจกรรมและรูปปก
- `43006` วันหยุดประจำปี: ข้อมูล Intranet แยกจากระบบลงเวลา และแสดงตามสาขาเมื่อมีสาขา

## ยังไม่ยืนยัน

- คำสั่งงานในแชตไม่ใช่ API contract; ต้องเทียบ Controller/DTO/migration สำหรับชื่อ Field, สถานะ, ActionCode และ validation ก่อนเปลี่ยนพฤติกรรม

> สถานะหลักฐาน ณ 13 พ.ย. 2569: แยกข้อกำหนดที่เขียนไว้แล้วออกจาก Route/โค้ดที่พบจริง; ชื่อ Route ไม่ใช่ข้อกำหนดธุรกิจ

## ขอบเขตและเจ้าของ

- ระบบธุรกิจ: ระบบ Intranet
- โฟลเดอร์เจ้าของโค้ดหลัก: `projects/intranet`
- ProjectCode และเจ้าของข้อมูล: ระบุเฉพาะเมื่อมีหลักฐานใน Route/เอกสาร; ต้องตรวจ migration และ API ก่อนแก้ข้อมูล

## เมนูและพฤติกรรมที่พบในโค้ด

| MenuCode | Route / หน้าที่เห็นจากชื่อ | ScreenType | ProjectCode ใน Route | โค้ด | หลักฐาน |
|---|---|---:|---|---|---|
| `43001` | `/company/intranet-settings` | 2 | `LAOO_INTRANET` | true | [`projects/intranet/lib/intranet_feature.dart`](../../projects/intranet/lib/intranet_feature.dart) |
| `43002` | `/company/intranet-content` | 4 | `LAOO_INTRANET` | true | [`projects/intranet/lib/intranet_feature.dart`](../../projects/intranet/lib/intranet_feature.dart) |
| `43003` | `/company/intranet-approvals` | 2 | `LAOO_INTRANET` | true | [`projects/intranet/lib/intranet_feature.dart`](../../projects/intranet/lib/intranet_feature.dart) |
| `43004` | `/company/my-intranet` | 3 | `LAOO_INTRANET` | true | [`projects/intranet/lib/intranet_feature.dart`](../../projects/intranet/lib/intranet_feature.dart) |
| `43005` | `/company/intranet-reports` | 3 | `LAOO_INTRANET` | true | [`projects/intranet/lib/intranet_feature.dart`](../../projects/intranet/lib/intranet_feature.dart) |
| `43006` | `/company/intranet-annual-holidays` | 1 | `LAOO_INTRANET` | true | [`projects/intranet/lib/intranet_feature.dart`](../../projects/intranet/lib/intranet_feature.dart) |

## ข้อกำหนด Function ปัจจุบัน

ยังไม่พบสเปก Function ที่ยืนยันครบทุกเมนูในระบบนี้; ข้อกำหนดที่ย้ายและตรวจได้จะอยู่ในหัวข้อเฉพาะด้านล่าง

## Input / Validation / Flow / สถานะ / Permission / API

สำหรับเมนูที่ไม่มีสเปกเฉพาะ ยังไม่ยืนยันรายละเอียด Input, Validation, Flow, สถานะ, ActionCode, API และตารางข้อมูลจากการมี Route เพียงอย่างเดียว ต้องเปิด Controller, DTO, migration และสิทธิ์ของ MenuCode ก่อนพัฒนา

## ความเชื่อมโยงข้ามระบบและช่องว่าง

ดูแหล่ง Route รายเมนูและ [รายงานช่องว่าง](../reports/FUNCTION_DOC_AUDIT_20261113.md) ก่อนแก้ไขข้ามโมดูล

## สถานะรายละเอียดรายเมนู

| MenuCode | Input / Validation | Flow / สถานะ | Permission | API / DTO |
|---|---|---|---|---|
| `43001` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `43002` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `43003` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `43004` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `43005` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
| `43006` | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ตรวจข้อกำหนดเฉพาะด้านบนและ Source | ยังต้องตรวจ ActionCode | ยังต้องตรวจ API/DTO |
