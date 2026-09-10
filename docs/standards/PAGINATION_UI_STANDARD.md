# LAOO Pagination UI Standard

## Fixed pagination card height

- Pagination ต้องอยู่ใน Pagination Card แยกจาก Table/List เสมอ และวางใต้ Table/List โดยเว้นระยะ `LaooLayout.cardSpacing`; ต้องแสดง Card นี้แม้มีข้อมูลเพียงหน้าเดียวหรือไม่มีข้อมูล
- Pagination Card ใช้พื้นสีขาว เต็มความกว้าง Content Area ไม่มีเส้นกรอบสีและไม่มีเส้นคั่นภายใน Card มุมโค้ง `LaooRadius.xs` (`4px`)
- The outer pagination card height must be exactly `56px` on all standard list/document screens.
- In Flutter, use the shared constant `LaooLayout.paginationCardHeight`; do not hardcode the value per page.
- Do not add outer card padding that increases the total height beyond `56px`.
- Keep the existing pagination behavior, page size, current page, and API/business logic unchanged.

- ส่วนเนื้อหา Pagination ภายใน Card ใช้ `LaooLayout.cardPadding` โดยต้องไม่ทำให้ความสูงรวมเกิน `56px`
- ปุ่มก่อนหน้าและถัดไปใช้ Icon `<` และ `>`
- ชุด Pagination เรียงเป็น `<`, เลขหน้าปัจจุบัน, `>` โดยเว้นระยะระหว่างปุ่ม `6px`; ข้อความสรุปจำนวนรายการอยู่ถัดจากชุดปุ่มและเว้นระยะ `12px` ห้ามใช้ `Spacer` ดันข้อความไปชิดขวาสุด
- ปุ่มทุกปุ่มมีเส้นกรอบ `1px` สี Primary ตาม User Style และมุมโค้ง `LaooRadius.xs` (`4px`) ห้ามใช้ทรงวงกลม
- ปุ่มหน้าปัจจุบันใช้พื้น Primary ตาม User Style พร้อมเส้นกรอบ Primary และข้อความสีที่อ่านชัด
- ปุ่มก่อนหน้า/ถัดไปที่ใช้งานได้ใช้พื้นขาว ตัวอักษร/Icon และเส้นกรอบสี Primary ตาม User Style
- ปุ่มที่ใช้งานไม่ได้ใช้พื้นขาว ตัวอักษร/Icon และเส้นกรอบสีเทา
- แสดงข้อความ `รายการเริ่มต้น-รายการสุดท้าย จาก จำนวนทั้งหมด`
- เมื่อไม่มีข้อมูลให้แสดง `0-0 จาก 0` และปิดการทำงานปุ่มก่อนหน้า/ถัดไป
- Pagination ต้องไม่ Overflow บนหน้าจอแคบ; อนุญาตให้ Wrap โดยคงลำดับปุ่มและข้อความ
- รักษา Page Size, Current Page และ Business Logic เดิมของหน้าจอ

## Prompt สำหรับส่งให้ AI

```text
ปรับ Pagination ตาม docs/standards/PAGINATION_UI_STANDARD.md ให้อยู่ใน Card สีขาวเต็มความกว้าง ไม่มีเส้นเทาอ่อนภายใน Card ปุ่ม < และ > มีเส้นกรอบ 1px สีตาม User Style มุมโค้ง 4px หน้าปัจจุบันมีพื้น Primary ปุ่มที่ปิดใช้งานใช้สีเทา แสดงข้อความ เริ่มต้น-สุดท้าย จาก ทั้งหมด และต้องไม่ Overflow ห้ามเปลี่ยน Pagination Logic หรือ API
```
