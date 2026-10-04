# แผนงานร่วมโครงการ LAOO

วันที่บันทึก: 16 กันยายน 2026  
สถานะ: ใช้เป็นแผนทำงานร่วมกันก่อนเริ่มหรือเปิดใช้ Business Feature ใหม่

## ข้อตกลงการทำงาน

1. สรุป requirement และ workflow ของ **ทีละ Project** ให้ชัดก่อนเริ่มพัฒนา
2. ระบุข้อมูล หน้าจอ และ lookup ที่ใช้ร่วมกับ Project อื่นก่อนกำหนดเจ้าของงาน
3. Core Bootstrap เมนู, entitlement, permission baseline, Feature Host และ root composition ให้ครบเพียงครั้งเดียว
4. หลัง Bootstrap merge แล้ว Project machine เป็นเจ้าของ migration, API, UI, route และ test ภายใน `projects/<project>/**`
5. Project PR เข้า `main` ได้โดยตรงเมื่อไม่เปลี่ยน Core/shared contract หรือ Project อื่น
6. เปิดใช้งานเมนูได้ทีละรายการเมื่อครบ: migration, API, route จริง, UI, permission, test และ Center verification
7. ห้ามเปิดเมนูที่ไม่มี GoRoute จริง เพื่อป้องกันอาการกดเมนูแล้วกลับ Home หรือเงียบ

## เจ้าของงาน

| เครื่อง/บทบาท | Project ที่พัฒนาได้อิสระ | ขอบเขต |
|---|---|---|
| Core | Shared/Root, `projects/service` ชั่วคราว | Navigation, entitlement, shared schema/contract, Person, Building/Room, Item, Authentication boundary และ root integration |
| Meeting + Visitor + Training | `projects/meeting`, `projects/visitor`, `projects/training` | Business migration, API, Flutter feature, route, test ของสาม Project นี้ |
| Time | `projects/time` | Business migration, API, Flutter feature, route, test ของ Time |

Project machine ต้องส่ง Core PR แยกเฉพาะเมื่อมีผลต่อ `TDADPerson`, shared schema/contract, root host, entitlement, Main Menu/permission baseline ใหม่ หรือ Project อื่น

## ข้อมูลและหน้าจอใช้ร่วมกัน

| ข้อมูล/หน้าจอกลาง | เจ้าของ | Project ที่ใช้ร่วม | หลักการ |
|---|---|---|---|
| ทะเบียนบุคคล `TDADPerson` / 13002 | Core | Service, Visitor, นำทรัพย์สินออก, ค่าใช้จ่าย, แบบสอบถาม, Project งานโครงการ | หนึ่ง Person ต่อ Company; บทบาทเกิดจากความสัมพันธ์จริงของแต่ละ Project |
| อาคาร, ชั้น, ห้อง | Core | Service, Visitor, 5S, งานโครงการ | เป็น master ชุดเดียว ห้ามสร้าง Room ซ้ำใน Project |
| ผู้พักอาศัย `TDADResident` | Service | Visitor, Service | Service เป็นเจ้าของช่วงพัก; Visitor อ่านเฉพาะ Resident ที่ active เพื่อเลือกผู้เข้าพบ/ห้องปลายทาง |
| พนักงาน/User/สิทธิ์ | Core | ทุก Project | ทุก Project ใช้ Employee/User/Permission เดิมและตรวจ Company scope ที่ backend |
| Item, Item Usage, Item Instance | Core/Inventory | นำทรัพย์สินออก, ค่าใช้จ่าย, งานโครงการ | ของมี serial ใช้ ItemInstance; ของทั่วไปใช้ Item พร้อมจำนวน |
| ค่าใช้จ่ายและเอกสารแนบ | Project ค่าใช้จ่าย | งานโครงการ, นำทรัพย์สินออก | หน้าจอเดียวเรียกใช้จากหลาย Project ผ่าน context/reference ไม่สร้างข้อมูลซ้ำ |

## Visitor: แผนที่พักไว้

### สถานะปัจจุบัน

- `LAOO_VISITOR`, Feature Host, API module composition และ route contract 22 เมนูพร้อมแล้ว
- Root รวม `buildVisitorFeatureRoutes()` เพียงจุดเดียวตาม Project Bootstrap Standard
- ยังไม่มี Visitor business migration/table, API ธุรกิจ หรือ GoRoute จริง
- 31002 `รับผู้มาติดต่อ` ถูกเปิดเฉพาะ Company 1 เพื่อเตรียมทดสอบ และ C1/C2 ได้ VIEW/CREATE/EDIT
- แต่ `buildVisitorFeatureRoutes()` ยังว่าง จึงยังไม่ถือว่า 31002 พร้อมใช้งานจริง
- เมนู Visitor อื่นยังคงปิด

### ลำดับเปิดใช้

1. **31002 รับผู้มาติดต่อ** — เมนูแรก
   - Person กลาง: ชื่อ-นามสกุล และเลขบัตรในข้อมูล Visitor ที่เข้ารหัส
   - เลือก Resident ผู้เข้าพบ; เติม Room ปลายทางจาก Resident ณ ขณะรับเรื่อง
   - สร้าง Visit ที่อ้าง Person/Resident/Room พร้อมเวลาเข้า สถานะ และ audit
   - ป้าย `ผู้มาติดต่อ` ใน Person เป็นข้อมูลคำนวณจาก Visit จริง
2. **31004 บันทึกผู้มาติดต่อออก**
3. **31005 ประวัติผู้มาติดต่อ**
4. เมนูนัดหมาย/อนุมัติ, master ตามพื้นที่, รายงาน, notification และ security ตาม requirement ที่จะสรุปทีละหัวข้อ

### ขอบเขตเครื่อง Meeting + Visitor

- ทำงานใน `projects/visitor/**` ได้เอง: migration, API, UI/UX, GoRoute, tests และ activation ของเมนูที่ implementation พร้อม
- ห้ามแก้ Person, Resident, Room, Authentication หรือ root router
- หากต้องขยาย shared contract ให้แยก Core PR ก่อน แล้วจึงทำ Visitor PR

## แผนสรุป Project ถัดไป

ทำตามลำดับนี้ โดยไม่ข้าม requirement ของ Project ที่พ่อยังไม่สรุป:

1. Visitor — กลับมาสรุป workflow 31002 และเปิดใช้งานจริง
2. ระบบบริหารงานขาย — ลูกค้า, ใบเสนอราคา, ใบสั่งซื้อ, ส่งมอบ, วางบิล/รับชำระ และรายงานขาย
3. ระบบบริการโครงการ — งบประมาณ, เวลา, คน, มอบหมายงาน, ติดตาม, ผลงานและงบจริง
4. ระบบนำทรัพย์สินออกภายนอก — approval, หลักฐานภาพ, serial/จำนวน, จุด รปภ., ติดตามการนำกลับ
5. ระบบ 5S — พื้นที่, ทีมตรวจ, แบบประเมิน/คะแนน และเปรียบเทียบรอบตรวจ
6. ระบบบันทึกค่าใช้จ่าย — เบิกพนักงาน/ค่าใช้จ่ายบริษัท, advance/คืนเงิน, เอกสารแนบ และ reference โครงการ/นำทรัพย์สินออก
7. ระบบแบบสอบถาม — แบบสอบถาม, approval ทางเลือก, ผู้ตอบหลายประเภท, email delivery, tracking และสรุปผล

ในแต่ละ Project ต้องได้ข้อสรุป 4 เรื่องก่อนเริ่ม code:

1. ความสามารถและ workflow ทางธุรกิจ
2. เมนู/ScreenType/Permission และลำดับเปิดใช้
3. ข้อมูลหรือหน้าจอที่ reuse จาก Core/Project อื่น
4. เจ้าของ Project machine และจุดที่ต้องส่ง Core PR
