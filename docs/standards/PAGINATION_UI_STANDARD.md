# LAOO Pagination UI Standard

## Fixed pagination card height

- The outer pagination card height must be exactly `56px` on all standard list/document screens.
- In Flutter, use the shared constant `LaooLayout.paginationCardHeight`; do not hardcode the value per page.
- Do not add outer card padding that increases the total height beyond `56px`.
- Keep the existing pagination behavior, page size, current page, and API/business logic unchanged.

- มีเส้น `LaooColors.border` สีเทาอ่อนยาวก่อนส่วน Pagination
- Pagination อยู่ใน Card สีขาวเต็มความกว้าง ไม่มีเส้นกรอบสี และใช้ `LaooLayout.cardPadding`
- ปุ่มก่อนหน้าและถัดไปใช้ Icon `<` และ `>`
- ปุ่มหน้าปัจจุบันใช้พื้น Primary ตาม User Style และข้อความสีที่อ่านชัด
- ปุ่มเลื่อนหน้าที่ไม่ใช่หน้าปัจจุบันหรือใช้งานไม่ได้ใช้สีเทา
- ปุ่มทุกปุ่มมีขนาดเท่ากัน มุมโค้ง `LaooRadius.xs` (`4px`) และไม่ใช้ทรงวงกลม
- แสดงข้อความ `รายการเริ่มต้น-รายการสุดท้าย จาก จำนวนทั้งหมด`
- เมื่อไม่มีข้อมูลให้แสดง `0-0 จาก 0` และปิดการทำงานปุ่มก่อนหน้า/ถัดไป
- Pagination ต้องไม่ Overflow บนหน้าจอแคบ; อนุญาตให้ Wrap โดยคงลำดับปุ่มและข้อความ
- รักษา Page Size, Current Page และ Business Logic เดิมของหน้าจอ

## Prompt สำหรับส่งให้ AI

```text
ปรับ Pagination ตาม docs/standards/PAGINATION_UI_STANDARD.md ให้อยู่ใน Card สีขาวเต็มความกว้าง มีเส้นเทาอ่อนก่อน Pagination ปุ่ม < และ > เป็นสีเทา หน้าปัจจุบันมีพื้น Primary ปุ่มทุกปุ่มมุมโค้ง 4px แสดงข้อความ เริ่มต้น-สุดท้าย จาก ทั้งหมด และต้องไม่ Overflow ห้ามเปลี่ยน Pagination Logic หรือ API
```
