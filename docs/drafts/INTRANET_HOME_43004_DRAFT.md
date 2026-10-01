# Draft หน้าหลัก Intranet ของฉัน

## Metadata

- MenuCode: 43004
- MenuName: Intranet ของฉัน
- ScreenType: 3 (ShowOnly)
- Route: /company/my-intranet
- Caption ต้องอ่านผ่าน Navigation resolver จาก TDADMainMenu

## Design signature

Digital Workplace ที่สงบ ทันสมัย และอ่านข้อมูลสำคัญได้รวดเร็ว โดยใช้สี Primary จาก User Profile เฉพาะจุดโต้ตอบและลำดับความสำคัญ พื้นหลังอ่อน Card สีขาว มุม 4px และไม่มีกรอบสีรอบ Card

## ลำดับเนื้อหา

1. Caption ของหน้าจอ
2. คำทักทายและคำอธิบายหน้าหลัก
3. ทางลัดจากเมนูที่ผู้ Login มีสิทธิ์ VIEW
4. รายการที่ต้องอ่านและยืนยัน
5. ข่าว ประกาศ กิจกรรม และเอกสาร
6. กำหนดการที่เกี่ยวข้องกับผู้ Login
7. เอกสารล่าสุดที่ผู้ Login มีสิทธิ์เข้าถึง

## Responsive

- Wide: Feed หลักอยู่ซ้าย ข้อมูลเร่งด่วนและกำหนดการอยู่ขวา
- Compact: เรียงหนึ่งคอลัมน์ โดยรายการต้องรับทราบอยู่ก่อน Feed ข่าว
- ทางลัดเป็น 4 คอลัมน์บน Wide และ 2 คอลัมน์บน Compact
- ข้อความยาวต้อง Wrap หรือ Ellipsis ตามชนิดข้อมูล และห้ามเกิด Horizontal Overflow

## State matrix

- Loading: รักษาโครง Caption, Hero, Shortcut และ Feed เพื่อลด Layout shift
- Loaded: แสดงข้อมูลสั้น ปกติ และหัวข้อยาว
- Empty: อธิบายว่าไม่มีข่าวหรือกำหนดการ โดยมี Action ที่เกี่ยวข้องเพียงรายการเดียว
- Filtered empty: แสดงปุ่ม ล้างตัวกรอง
- Partial error: แสดง Error เฉพาะ Section ที่โหลดไม่ได้ และคงข้อมูล Section อื่น
- Full error: แสดงรายละเอียดเพิ่มเติมและปุ่ม ลองอีกครั้ง ในพื้นที่ Error
- Stale/offline: คงข้อมูลล่าสุด พร้อมระบุเวลาที่อัปเดต
- Focus/hover: ใช้ Primary จาก User Profile และต้องเห็น Keyboard focus ชัดเจน

## ข้อมูลตัวอย่างสำหรับรอบพัฒนา

- ประกาศวันหยุดประจำปี 2570
- นโยบายคุ้มครองข้อมูลส่วนบุคคลที่ต้องยืนยัน
- Town Hall ประจำไตรมาส 4
- คู่มือความปลอดภัยฉบับปรับปรุง
- กำหนดการประชุม อบรม และแบบสำรวจ

ข้อมูลตัวอย่างต้องมี Run ID และสร้างหลัง Schema/API ได้รับอนุมัติ ห้ามใช้ Fixture ของ Draft เป็น Production data โดยอัตโนมัติ

## Landing หลัง Login

- Company User ที่มีสิทธิ์ VIEW เมนู 43004 ให้เข้า /company/my-intranet
- Company User ที่ไม่มีสิทธิ์ 43004 ให้กลับ /home เดิม
- Partner User และ LAOO Support ใช้ Landing เดิม
- Backend และ Navigation API ยังคงเป็น Source of Truth ของสิทธิ์

## งานหลังอนุมัติ Draft

1. สร้าง API และตารางธุรกิจผ่าน Migration มาตรฐาน
2. สร้างหน้า 43004 และ State ทั้งหมดด้วย Theme/Token กลาง
3. สร้างข้อมูลตัวอย่างที่ระบุ Run ID
4. เปิด Project mapping และสิทธิ์ตามบทบาทที่อนุมัติ
5. เปลี่ยน Login redirect ตามกฎ Landing ด้านบน
6. ทดสอบ Permission, API, Desktop/Mobile, Overflow และ Flow หลัง Login
