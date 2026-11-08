# LAOO Pagination UI Standard

## Fixed pagination card height

- Pagination ต้องอยู่ใน Pagination Card แยกจาก Table/List เสมอ และวางใต้ Table/List โดยเว้นระยะ `8px`; ต้องแสดง Card นี้แม้มีข้อมูลเพียงหน้าเดียวหรือไม่มีข้อมูล
- Pagination Card ใช้พื้นสีขาว เต็มความกว้าง Content Area ไม่มีเส้นกรอบสีและไม่มีเส้นคั่นภายใน Card มุมโค้ง `LaooRadius.xs` (`4px`)
- The outer pagination card height must be exactly `56px` on all standard list/document screens.
- In Flutter, use the shared constant `LaooLayout.paginationCardHeight`; do not hardcode the value per page.
- Do not add outer card padding that increases the total height beyond `56px`.
- Keep the existing pagination behavior, page size, current page, and API/business logic unchanged.

- ส่วนเนื้อหา Pagination ภายใน Card ใช้ `LaooLayout.cardPadding` โดยต้องไม่ทำให้ความสูงรวมเกิน `56px`
- ปุ่มก่อนหน้า, เลขหน้า และถัดไปใช้ขนาด `LaooLayout.paginationButtonSize` (`36 × 36px`); ปุ่มก่อนหน้าและถัดไปใช้ Icon Chevron ขนาด `22px`
- ชุด Pagination เรียงเป็น `<`, เลขหน้าปัจจุบัน, `>` โดยเว้นระยะระหว่างปุ่ม `6px`; ข้อความสรุปจำนวนรายการอยู่ถัดจากชุดปุ่มและเว้นระยะ `12px` ห้ามใช้ `Spacer` ดันข้อความไปชิดขวาสุด
- จัดชุดปุ่มและข้อความชิดซ้ายเสมอทุกขนาดหน้าจอ และกึ่งกลางแนวตั้งภายใน Pagination Card เต็มความกว้าง; เว้น Padding ภายในแนวนอน `10px` และไม่มีเส้นคั่นภายใน ห้ามจัดกึ่งกลางหรือชิดขวาแม้มีข้อมูลเพียงหน้าเดียวหรือไม่มีข้อมูล
- ปุ่มเลขหน้าที่ยังไม่ถูกเลือกมีเส้นกรอบ `1px` สี Primary; ทุกปุ่มใช้มุมโค้ง `LaooRadius.xs` (`4px`) ห้ามใช้ทรงวงกลม
- ปุ่มหน้าปัจจุบันใช้พื้น Primary ตาม User Style พร้อมเส้นกรอบ Primary และข้อความสีที่อ่านชัด
- ปุ่มก่อนหน้า/ถัดไปที่ใช้งานได้ใช้พื้น Primary และ Icon สีขาว
- ปุ่มที่ใช้งานไม่ได้ใช้พื้นสีเทาและ Icon สีเทาเข้ม
- แสดงข้อความ `รายการเริ่มต้น-รายการสุดท้าย จาก จำนวนทั้งหมด`
- เมื่อไม่มีข้อมูลให้แสดง `0-0 จาก 0` และปิดการทำงานปุ่มก่อนหน้า/ถัดไป
- Pagination ต้องไม่ Overflow บนหน้าจอแคบ; อนุญาตให้ Wrap โดยคงลำดับปุ่มและข้อความ
- รักษา Page Size, Current Page และ Business Logic เดิมของหน้าจอ

## Prompt สำหรับส่งให้ AI

```text
ปรับ Pagination ตาม docs/standards/PAGINATION_UI_STANDARD.md โดยใช้ Card สีขาว ปุ่ม 36px มุม 4px ปุ่มลูกศรที่ใช้งานได้ใช้พื้น Primary ปุ่มที่ปิดใช้งานใช้สีเทา แสดงช่วงรายการ และไม่เปลี่ยน Pagination Logic หรือ API
```
