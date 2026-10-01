# Draft หน้าขายหน้าร้านแบบสัมผัส

## Metadata

- MenuCode: `46004`
- MenuName: ขายหน้าร้าน
- ScreenType: `4` (Document Header–Detail)
- Route: `/company/pos-sales`
- Caption อ่านจาก Navigation resolver/`TDADMainMenu`

## แนวคิดการออกแบบ

หน้าขายเป็น Touch-first retail workspace ที่พนักงานเห็นตัวตนของจุดขายตลอดเวลา เลือกสินค้าและชำระเงินได้ด้วยการแตะ โดยไม่ต้องเปิด Popup หลายชั้น พื้นหลัง Neutral, Card สีขาว มุม `4px` ไม่มีกรอบสี Primary และใช้สีจาก User Profile เฉพาะ Selection, Focus และ Primary Action

## ภาพ Draft

- [จอกว้าง](pos-touch-sales-46004-wide.png)
- [จอสัมผัสขนาดเล็ก](pos-touch-sales-46004-compact.png)
- Source: [Wide SVG](pos-touch-sales-46004-wide.svg) และ [Compact SVG](pos-touch-sales-46004-compact.svg)

## โครงสร้างหน้าจอกว้าง

- Identity bar: สาขา, จุดขาย, Terminal, กะ และพนักงานขาย แสดงคงที่ด้านบน
- Product workspace ประมาณ 60%: ค้นหา/สแกนบาร์โค้ด, หมวดสินค้า และ Product tiles แบบสัมผัส
- Cart workspace ประมาณ 40%: รายการสินค้า, ปรับจำนวน, ส่วนลด, สรุปยอด และปุ่มชำระเงิน
- จำนวนเงินรวมใช้ `40px` น้ำหนัก `700`; ราคาสินค้าและยอดต่อรายการใช้ `18–22px`
- Touch target ทั่วไปไม่น้อยกว่า `56px`; ปุ่มชำระเงินสูง `64px`
- สินค้าสต็อกศูนย์แสดง Disabled และแตะขายไม่ได้เมื่อไม่อนุญาต Negative Stock
- สินค้าราคาศูนย์แสดงสถานะ “ต้องกำหนดราคา” และห้ามเพิ่มลงตะกร้าจนกว่าจะมีสิทธิ์และระบุราคา

## Responsive

- Wide (`>= 1100px`): สินค้าและตะกร้าแสดงคู่กัน 60/40
- Medium: ลดจำนวนคอลัมน์สินค้าและรักษาตะกร้ากว้างอย่างน้อย `360px`
- Compact: ใช้ Tab `สินค้า` / `ตะกร้า`; แถบยอดรวมและปุ่มชำระเงินตรึงด้านล่าง
- ข้อความชื่อสินค้ายาวใช้ได้สูงสุด 2 บรรทัดแล้ว Ellipsis; ห้ามเกิด Horizontal Overflow
- รองรับ Touch, Barcode scanner, Mouse และ Keyboard focus

## ข้อมูลจริงที่ใช้ใน Draft

- CompanyID `1`
- สาขา `HO - สำนักงานใหญ่`
- คลัง `HO-A - Name-HO-A`
- Terminal ตัวอย่าง `POS-HO-01` (สร้างในรอบพัฒนา)
- ผู้ขาย `c111`
- สินค้าจาก `TDIVItem`: `NM001`, `NZ001`, `NK001`, `NW001`, `NA001`, `MT001`, `MT002`
- ครอบคลุมกรณีมีสต็อก, สต็อกศูนย์, ราคาศูนย์ และชื่อสินค้ายาว

## Flow

1. Login แล้ว Backend resolve User + Terminal Activation ID
2. ตรวจว่า Terminal Active, ผูกสาขา/จุดขาย/คลัง และผู้ใช้มีสิทธิ์สาขา/คลังเดียวกัน
3. ตรวจว่ามีกะเปิด หากตั้งค่าบังคับเปิดกะ
4. โหลดสินค้า ราคา และสต็อกตามจุดขาย/คลังจาก Server scope
5. เพิ่มสินค้าเข้าตะกร้า ปรับจำนวน/ส่วนลดตาม Permission
6. เปิด Payment sheet, รับเงินสด/วิธีชำระ และแสดงเงินทอนตัวใหญ่
7. Backend บันทึก Header, Detail, Payment และ Stock Movement ใน Transaction เดียว
8. แสดงเลขใบเสร็จและพิมพ์/เริ่มบิลใหม่ โดยยอดทุกบิลเก็บ BranchID, OutletID, TerminalID, ShiftID และ UserID

## State matrix

- Terminal not activated: Block หน้าขายและแสดงปุ่มเดียว `เปิดใช้งานเครื่องนี้`
- Terminal inactive/wrong branch: Block พร้อมข้อความให้ผู้ดูแลตรวจการผูกเครื่อง
- No open shift: Block พร้อมปุ่ม `เปิดกะ` เมื่อมี Permission
- Loading: Product skeleton และ Cart skeleton โดย Identity bar ไม่กระโดด
- Empty cart: แนะนำให้สแกนหรือแตะสินค้า
- Empty/filter empty: แยกข้อความไม่มีสินค้ากับไม่พบจากคำค้น
- Out of stock: Tile disabled พร้อมจำนวนคงเหลือ `0`
- Zero price: Tile warning และไม่เพิ่มเข้าตะกร้าโดยเงียบ
- Save/payment error: คง Cart เดิม ไม่สร้าง Stock Movement บางส่วน และ Retry เฉพาะ Payment area
- Offline/stale: Block Finalize; แสดงเวลา sync ล่าสุด ห้ามขายซ้ำจากการกดซ้ำ

## Permission และความปลอดภัย

- ตรวจ `VIEW`, `CREATE`, `EDIT`, `DELETE`, `CANCEL`, `DISCOUNT`, `FINALIZE`, `PRINT` แยกตาม Action
- Backend resolve Branch/Outlet/Warehouse จาก Terminal token และ User session ห้ามเชื่อ ID จาก Client
- Finalize ใช้ Idempotency key ต่อใบขายและ Transaction เดียวกับ Stock Movement
- Terminal Activation ID เป็น server-issued/app-generated key ไม่ใช้ hardware serial ของ Browser

## งานหลังอนุมัติ Draft

1. สร้าง Migration และ API ของ Settings, Outlet, Terminal, Shift, Sale, Payment และ Return
2. ทำหน้า `46001–46007` ตาม ScreenType และ Permission
3. Seed ข้อมูลตัวอย่างที่มี Run ID โดยอิงสาขา/คลัง/สินค้าจริง
4. ทดสอบ API, Permission, Data scope, Stock transaction, Responsive และ Browser flow
