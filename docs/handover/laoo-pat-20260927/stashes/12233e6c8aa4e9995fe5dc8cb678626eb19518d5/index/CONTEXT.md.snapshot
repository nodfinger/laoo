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

**Time Management Project**:
Business Project สำหรับจัดการเวลาทำงาน ตารางการทำงาน การลา และผลสรุปเวลาของ Employee โดยใช้ข้อมูลบุคคลและโครงสร้างองค์กรจาก Core Project
_Avoid_: Core Project, ระบบพนักงาน, ระบบเงินเดือน

## Time Management Language

**Attendance Event**:
หลักฐานเวลาต้นฉบับของ Employee ณ เหตุการณ์เข้า ออก หรือเหตุการณ์เวลาอื่น ซึ่งต้องเก็บเวลาต้นฉบับจากเครื่อง เวลาไทยที่ใช้คำนวณ เวลา UTC ที่แปลงแล้ว และเวลาที่ระบบรับข้อมูลแยกกันโดยห้ามเขียนทับ เพื่อการตรวจสอบย้อนหลัง
_Avoid_: Time Adjustment, ผลคำนวณเวลาทำงาน

**Source Event Time**:
วันเวลาต้นฉบับที่เครื่องลงเวลาระบุ ซึ่งต้องรักษาไว้แม้นาฬิกาต้นทางผิด และตีความเป็นเวลาประเทศไทยสำหรับสร้างเวลาไทยและ Event Time UTC ที่ใช้คำนวณ
_Avoid_: Received Time, เวลาที่ผ่าน Time Adjustment

**Received Time**:
เวลา UTC ที่ LAOO_TIME รับข้อมูลเข้าระบบ ใช้ตรวจสอบความล่าช้าและลำดับการนำเข้าโดยไม่แทน Source Event Time
_Avoid_: Source Event Time, เวลาเข้าออกของ Employee

**Attendance Classification Window**:
ช่วงเวลาที่กำหนดในตารางเพื่อจัดประเภท Attendance Event ว่าเป็นการเข้างาน ออกงาน หรือเหตุการณ์เวลาอื่น แม้แหล่งบันทึกไม่ได้ส่งประเภทมาด้วย โดยรวมเวลาเริ่ม ไม่รวมเวลาสิ้นสุด และห้ามช่วงซ้อนกัน
_Avoid_: Attendance Tolerance, Shift Segment

**Calculated Attendance Direction**:
ความหมายเข้าออกที่ LAOO_TIME กำหนดจาก Attendance Classification Window เท่านั้น โดยไม่ใช้ประเภท IN/OUT ที่แหล่งบันทึกส่งมาเป็นผลคำนวณ
_Avoid_: Source Event Type, การเชื่อค่าทิศทางจากอุปกรณ์

**Attendance Session**:
ช่วงเวลาที่จับคู่ Primary Attendance Event ฝั่งเข้าและออก ซึ่งอาจครอบคลุมหลาย Shift Segment และถูกตัดกับงานปกติ พัก และ Approved OT Assignment เพื่อคำนวณผล
_Avoid_: Shift Segment, Attendance Event เดี่ยว

**Attendance Session Rule**:
กติกาหนึ่งรอบลงเวลาภายใน Shift Template ซึ่งประกอบด้วย Attendance Classification Window ฝั่งเข้าและออกอย่างละหนึ่งช่วงเพื่อสร้าง Attendance Session หนึ่งรายการ หนึ่ง Work Date มีได้หลายกติกาโดยทุกช่วงต้องเรียงลำดับและไม่ซ้อนกัน ส่วนรอบงานปกติที่ต่อเนื่องถึง OT ใช้กติกาเดียวครอบคลุมได้ แต่ละ Rule ระบุ Session Requirement Mode เป็น Required หรือ Optional
_Avoid_: Shift Segment, การบังคับสร้าง Session ใหม่ทุกช่วงงานหรือ OT

**Session Requirement Mode**:
ข้อกำหนดของ Attendance Session Rule ว่า Required ต้องมี Event ครบคู่ มิฉะนั้นเกิด Incomplete Attendance หรือ Optional ซึ่งเมื่อไม่มี Event เลยให้นับเวลาเป็นศูนย์โดยไม่ผิด แต่หากมี Event เพียงฝั่งเดียวให้เกิด Incomplete Attendance
_Avoid_: Attendance Requirement ของ Employee, การถือรอบ OT ที่ไม่เกิดขึ้นเป็นการขาดงาน

**Attendance Session Result**:
ผลตรวจเวลาของ Attendance Session Rule หนึ่งรอบ ซึ่งคำนวณ Late Arrival, Early Departure และข้อผิดปกติแยกจากรอบอื่น ก่อนรวมจำนวนนาทีเป็น Attendance Result ของ Work Date โดยยังเก็บรายละเอียดรายรอบ
_Avoid_: Attendance Segment Result, ผลรวมทั้ง Work Date

**Overlapping Attendance Conflict**:
สถานะเมื่อ Attendance Session ของ Employee คนเดียวกันมีช่วงเวลาซ้อนกัน ระบบรวมช่วงเวลาเพื่อไม่ให้นับแต่ละวินาทีเกินหนึ่งครั้ง แต่ Attendance Result ยังเป็น Unresolved และปิดงวดไม่ได้จนกว่าผู้มี Permission จะแก้ไข
_Avoid_: การนับเวลาซ้ำ, Replay Duplicate, Attendance Conflict ระหว่างงานกับการลา

**Work Date Offset**:
จำนวนวันที่เลื่อนจาก Work Date สำหรับระบุตำแหน่งเวลาของกะและ Classification Window ที่อาจข้ามเที่ยงคืน
_Avoid_: วันที่ของ Attendance Event, Time Zone

**Thailand Business Time**:
เขตเวลาคงที่ `Asia/Bangkok` (`UTC+07:00`) ที่ LAOO_TIME ใช้กับทุก Company และ Branch เพื่อตีความเวลาจากเครื่อง ตารางงาน Classification Window และ Work Date โดยไม่มีการกำหนด Time Zone แยกตาม Branch
_Avoid_: Branch Time Zone, การเปลี่ยนเขตเวลาตาม Company หรือ Branch

**Primary Attendance Event**:
Attendance Event ที่เลือกใช้คำนวณในแต่ละ Attendance Classification Window โดยช่วงเข้างานใช้รายการแรกสุดและช่วงออกงานใช้รายการสุดท้ายภายในช่วง
_Avoid_: Duplicate Attendance Event, Attendance Event ทุกเหตุการณ์

**Duplicate Attendance Event**:
Attendance Event อื่นใน Classification Window เดียวกับ Primary Attendance Event ซึ่งยังเก็บเป็นหลักฐานแต่ไม่ใช้คำนวณโดยอัตโนมัติ
_Avoid_: การลบเหตุการณ์ซ้ำ, Time Adjustment

**Unclassified Attendance Event**:
Attendance Event ที่ไม่อยู่ใน Classification Window ใดและยังไม่ใช้คำนวณจนกว่าผู้มี Permission จะจัดประเภทพร้อมเหตุผล
_Avoid_: การเดาประเภทอัตโนมัติ, การทิ้งเหตุการณ์

**Suspicious Attendance Event**:
Attendance Event ที่ผิดเกณฑ์ความสมเหตุสมผลซึ่ง Company กำหนด เช่น เวลาอยู่ในอนาคตมากหรือนาฬิกาแหล่งข้อมูลคลาดเกินกำหนด จึงยังไม่ใช้คำนวณจนกว่าผู้มี Permission จะยอมรับเวลาเดิมหรือสร้าง Time Adjustment
_Avoid_: Unclassified Attendance Event, การลบ Event, การนำไปคำนวณโดยอัตโนมัติ

**Incomplete Attendance**:
สถานะของช่วงงานที่ขาด Primary Attendance Event ฝั่งเข้าออกด้านใดด้านหนึ่ง จึงสรุปผลที่ต้องใช้เวลาคู่นั้นไม่ได้และห้ามสมมติเวลาแทน
_Avoid_: Full-day Absence, Schedule Gap, เวลาออกตามตารางที่ระบบสร้างเอง

**Attendance Segment Result**:
ผลคำนวณของ Shift Segment หนึ่งซึ่งสรุปแยกจากช่วงอื่นได้ แม้ Attendance Result ของ Work Date เดียวกันยังมีช่วงที่แก้ไม่ครบ
_Avoid_: Attendance Result ทั้งวัน, Attendance Event

**Unresolved Attendance Result**:
Attendance Result ของ Work Date ที่มี Incomplete Attendance หรือข้อขัดแย้งอย่างน้อยหนึ่งช่วง จึงยังปิดงวดไม่ได้โดยไม่ทิ้งผลช่วงที่สมบูรณ์
_Avoid_: การยกเลิกผลทั้งวัน, Finalized Attendance Result

**Replay Duplicate**:
ข้อมูลเหตุการณ์ที่ถูกส่งหรือนำเข้าซ้ำโดยมี Company, Employee, เวลา UTC, แหล่งที่มา และประเภท Event ตรงกับ Attendance Event เดิมทั้งหมด จึงต้องข้ามโดยไม่สร้าง Event ใหม่
_Avoid_: Duplicate Attendance Event, การบันทึกซ้ำเพื่อเก็บรอบนำเข้า

**Attendance Device Code**:
รหัสลงเวลาที่เครื่องของ Employee ซึ่งไม่ซ้ำภายใน Company ณ เวลาใดเวลาหนึ่ง ใช้ร่วมกันทุกแหล่งลงเวลา และเก็บประวัติ Assignment แบบช่วงเวลา `[EffectiveFrom, EffectiveTo)` เมื่อรับข้อมูลย้อนหลังต้องจับคู่ Employee จาก Assignment ที่มีผล ณ เวลา Attendance Event รหัสเดิมใช้กับ Employee คนใหม่ได้หลังปิด Assignment เดิมแล้วเท่านั้น
_Avoid_: EmployeeCode, User ID, รหัสแยกต่ออุปกรณ์

**Unmatched Attendance Import**:
ข้อมูลลงเวลาที่นำเข้าแล้วแต่ Attendance Device Code ยังจับคู่กับ Employee ไม่ได้ จึงเก็บ Company แหล่งข้อมูล รหัสที่เครื่อง เวลา และข้อมูลต้นฉบับไว้โดยไม่สร้าง Attendance Event เมื่อผู้มี Permission แก้การจับคู่แล้วจึงประมวลผลใหม่แบบป้องกัน Replay Duplicate
_Avoid_: Unclassified Attendance Event, การเดาจับคู่ Employee, การทิ้งข้อมูลนำเข้า

**Canonical Attendance Import Contract**:
รูปแบบข้อมูลกลางของ LAOO_TIME สำหรับรับหลักฐานเวลาจากทุกเทคโนโลยี โดยครอบคลุม Company แหล่งข้อมูล รหัสที่เครื่อง Source Event Time ข้อมูลต้นฉบับ และรหัสป้องกันการนำเข้าซ้ำ ก่อนผ่านการจับคู่ พักข้อมูล และสร้าง Attendance Event
_Avoid_: Contract เฉพาะยี่ห้อเครื่อง, Attendance Event ที่ข้ามขั้นตรวจนำเข้า, เวลาที่เจ้าหน้าที่คีย์เอง

**Attendance Source Connector**:
ตัวเชื่อมต่อเฉพาะเครื่องสแกนนิ้ว ใบหน้า GPS Mobile หรือเทคโนโลยีอื่นที่มีหน้าที่แปลงข้อมูลต้นทางเข้า Canonical Attendance Import Contract โดยอยู่นอกขอบเขตพัฒนาเฟสแรก
_Avoid_: กติกาคำนวณ Attendance Result ภายใน Connector, Contract กลาง

**Time Adjustment**:
รายการแก้ไขผลเวลาโดยไม่เปลี่ยนหลักฐานต้นฉบับ และต้องมีเหตุผลกับผู้ดำเนินการกำกับ เวลาที่เจ้าหน้าที่คีย์เพราะลืมลงเวลาหรือเครื่องเสียเป็น Time Adjustment เสมอและห้ามสร้าง Attendance Event หากรายการที่อนุมัติแล้วผิดให้สร้างรายการใหม่ที่อ้างอิงและยกเลิกผลรายการเดิมก่อนคำนวณใหม่
_Avoid_: Attendance Event, การเขียนทับเวลาเดิมหรือ Time Adjustment เดิม

**Time Adjustment Batch**:
รายการปรับเวลาพนักงานหลายคนจากเหตุการณ์ร่วม เช่น เครื่องเสียทั้งสาขา โดยใช้ Time Adjustment Reason และหลักฐานร่วมกัน เก็บรายละเอียดเวลาแยก Employee ตรวจความถูกต้องทั้งหมดก่อนส่ง Workflow ผู้อนุมัติตัดสิน อนุมัติ ปฏิเสธ หรือแก้พร้อม Log แยกราย Employee ได้ และรายการที่อนุมัติสร้าง Time Adjustment รายบุคคลที่อ้าง Batch
_Avoid_: Attendance Event แบบกลุ่ม, Time Adjustment รายการเดียวที่ไม่แยก Employee

**Superseding Time Adjustment**:
Time Adjustment รายการใหม่ที่อ้างอิงรายการเดิมเพื่อยกเลิกผลและแทนที่อย่างตรวจสอบย้อนหลังได้ โดยเก็บทั้งสองรายการไว้ตลอด
_Avoid_: การแก้ไขหรือลบ Time Adjustment เดิม

**Time Adjustment Approval Workflow**:
กระบวนการตัดสิน Time Adjustment ตาม Process Approval Policy และ Time Adjustment Reason ซึ่งอาจเป็น Direct Approval Decision ใน OWNER_OPERATED หรือหลาย Approval Step ใน SEGREGATED_WORKFLOW
_Avoid_: Time Adjustment Reason, Workflow ที่ไม่อ้าง Approval Control Profile

**Time Correction Request**:
คำขอเพื่อให้ตรวจและแก้ผลเวลาของ Employee หนึ่งคน โดย Employee อาจเริ่มเองหรือผู้มีสิทธิ์ทำ Proxy Submission ตาม Employee Request Policy หนึ่งคำขอจำกัดหนึ่ง Work Date มีรายละเอียดแก้ฝั่งเข้าออกของ Attendance Session Rule ได้หลายรายการและต้องตัดสินทั้งชุด เมื่ออนุมัติจึงก่อให้เกิด Time Adjustment และคำขอที่กระทบ Period Finalized ต้องผ่าน Elevated Approval Requirement โดย Employee เปิดงวดเองไม่ได้
_Avoid_: Time Adjustment โดยตรง, การแก้ Attendance Event

**Time Correction Request Detail**:
รายละเอียดจุดเวลาหนึ่งฝั่งเข้าออกของ Attendance Session Rule ภายใน Time Correction Request เดียว โดยหลายรายละเอียดใน Work Date เดียวกันใช้เหตุผลและหลักฐานร่วมกันและมีผลแบบทั้งชุด ผู้อนุมัติมี Permission แก้ค่าที่จะอนุมัติได้ แต่ต้องรักษาค่าที่ Employee ส่งและเก็บ Approval Edit Log ทุกครั้ง
_Avoid_: Time Correction Request แยกต่อจุดเวลา, การแก้โดยไม่มี Log

**Approval Edit Log**:
ประวัติแบบแก้ไม่ได้ของทุกครั้งที่ผู้มีสิทธิ์เปลี่ยนรายละเอียดคำขอ โดยเก็บค่าก่อนและหลัง เหตุผล ผู้ดำเนินการ วันเวลา และลำดับการแก้ โดยไม่ทำให้ค่าที่ผู้ขอส่งไว้สูญหาย
_Avoid_: Audit ข้อความรวมที่ไม่มีค่าก่อนหลัง, การเขียนทับคำขอต้นฉบับ

**Active Time Correction Request**:
Time Correction Request ที่ยังอยู่ระหว่างดำเนินการ โดยมีได้เพียงหนึ่งรายการต่อ Employee, Work Date, Attendance Session Rule และฝั่งเข้าออกเดียวกัน Employee แก้หรือยกเลิกได้ก่อนมีการอนุมัติ แต่คำขอที่อนุมัติและสร้าง Time Adjustment แล้วต้องคงเป็นประวัติและแก้ด้วยคำขอใหม่
_Avoid_: คำขอซ้ำจุดเวลาเดียวกัน, Approved Time Adjustment

**Time Correction Submission Window**:
จำนวนวันย้อนหลังที่ Company อนุญาตให้ Employee ส่ง Time Correction Request ตามกระบวนการปกติ คำขอที่เกินช่วงหรือกระทบ Period Finalized ต้องผ่านกติกาและ Approval Workflow ระดับสูงกว่า
_Avoid_: Attendance Period, การปิดสิทธิ์แก้ย้อนหลังทั้งหมด

**Time Adjustment Reason**:
Master ระดับ Company สำหรับจัดหมวดเหตุผลของ Time Correction Request และ Time Adjustment ซึ่งกำหนดข้อบังคับเรื่องหมายเหตุหรือหลักฐานและปิดใช้งานได้โดยไม่กระทบประวัติเดิม
_Avoid_: ข้อความอิสระเป็นเหตุผลหลัก, การลบค่าที่เคยใช้

**My Attendance History**:
มุมมองอ่านอย่างเดียวที่ Employee ใช้ตรวจตาราง หลักฐานเวลา รายการปรับ และ Attendance Result ของตนเอง
_Avoid_: หน้าจัดการเวลาของผู้อื่น, Time Correction Request

**Employee Data Scope**:
ขอบเขต Employee ที่ผู้ใช้จัดการหรือดูข้อมูลเวลาได้ตาม Company, Home Branch, ฝ่าย, แผนก หรือสายบังคับบัญชาที่มีผลตามช่วงวันที่ โดยต้องผ่านทั้ง Action Permission และ Scope และ Backend ตรวจทุก Request ส่วน Employee ทั่วไปมี Scope เฉพาะตนเอง
_Avoid_: Menu Permission อย่างเดียว, EmployeeID จาก Client ที่ไม่ตรวจ Owner

**Approval Control Profile**:
รูปแบบควบคุมการอนุมัติระดับ Company ที่มีรุ่นและวันเริ่มใช้ โดย Company กำหนดค่าเริ่มต้นและ Process Approval Policy แยกกระบวนการได้
_Avoid_: Employee Request Policy, User Permission

**OWNER_OPERATED**:
Approval Control Profile สำหรับธุรกิจที่ผู้มีสิทธิ์คนเดียวกันสามารถสร้างหรือทำแทน แก้ ตัดสิน และทำให้ผลมีผลใช้ได้ โดยทุก Action ยังต้องผ่าน Permission, Employee Data Scope, หลักฐาน และ Business Invariant
_Avoid_: การข้าม Audit, ผู้ดูแลเพียงคนเดียวแบบตายตัว

**SEGREGATED_WORKFLOW**:
Approval Control Profile ที่แยกผู้สร้างกับผู้อนุมัติตาม Approval Step และไม่ยอมให้ Self-approval เว้นแต่ Company Admin เปลี่ยน Profile ผ่าน Administrative Override
_Avoid_: OWNER_OPERATED, การแยกหน้าที่ที่ข้ามได้โดย Permission อย่างเดียว

**Process Approval Policy**:
ค่า Override ของ Approval Control Profile สำหรับ Leave, Time, OT, Entitlement หรือ Period โดยใช้ค่าเริ่มต้นของ Company เมื่อกระบวนการนั้นไม่มี Override
_Avoid_: Employee Request Policy, Approval Step

**Employee Request Policy**:
นโยบายระดับ Company ที่กำหนดแยกต่อ Leave Request, Leave Cancellation, Time Correction และ Reconfirmation ว่ารับ SELF_SERVICE_AND_PROXY, PROXY_ONLY หรือ SELF_SERVICE_ONLY โดยไม่กำหนดรูปแบบการอนุมัติ
_Avoid_: Approval Control Profile, Action Permission

**Employee Self-Service Role**:
บทบาทมาตรฐานของ Employee ที่มี Employee Data Scope เฉพาะตนเองและได้รับ VIEW, SUBMIT หรือ CANCEL ตาม Employee Request Policy ของกระบวนการ
_Avoid_: Company Admin, Scope ของ Employee คนอื่น

**Employee Request Access Gap**:
สถานะที่ Employee ใน Scope ของ SELF_SERVICE_ONLY ไม่มี Active Login ที่ผูกกับ Employee ซึ่งต้องบล็อกการเปิด Policy พร้อมแสดงรายชื่อ หรือแจ้ง Company Admin เป็นเหตุเร่งด่วนหากเกิดหลัง Policy มีผลแล้ว
_Avoid_: การเปลี่ยนเป็น PROXY_ONLY โดยปริยาย, Login Error ทั่วไป

**Proxy Submission**:
การที่ผู้มี ACT_ON_BEHALF เริ่ม Leave Request, Leave Cancellation, Time Correction หรือ Reconfirmation แทน Subject Employee โดยเก็บ Actor User, On-Behalf Reason, หมายเหตุหรือหลักฐาน และ Approval Decision แยกกัน
_Avoid_: Administrative Action, การปลอมว่า Employee เป็นผู้ทำรายการ

**On-Behalf Reason**:
Master ระดับ Company สำหรับเหตุผลของ Proxy Submission ซึ่งกำหนดได้ว่าต้องมีหมายเหตุหรือหลักฐานและปิดใช้ได้โดยไม่กระทบประวัติเดิม
_Avoid_: Approval Decision, ข้อความอิสระเป็นเหตุผลหลัก

**Proxy Notification Delivery**:
ผลการพยายามแจ้ง Subject Employee หลัง Proxy Submission ผ่านช่องทางที่มี โดยความล้มเหลวต้องถูกบันทึกเป็น Delivery Status แต่ไม่ย้อนกลับธุรกรรมหลัก
_Avoid_: เงื่อนไขสำเร็จของ Proxy Submission, การละทิ้ง Notification Failure

**Direct Approval Decision**:
การตัดสินแบบ OWNER_OPERATED ที่บันทึก Request, Approval Decision และผลธุรกิจครบใน Transaction เดียว แม้ผู้ใช้สั่งด้วยปุ่มบันทึกและอนุมัติเพียงครั้งเดียว
_Avoid_: การสร้างเฉพาะผลลัพธ์สุดท้าย, การข้าม Request

**Workflow Snapshot**:
สำเนา Approval Control Profile, Process Approval Policy และ Approval Step ที่ผูกกับคำขอเมื่อส่ง เพื่อให้รายการเดิมดำเนินต่อด้วยกติกาเดิมแม้ Company เปลี่ยนค่าในภายหลัง
_Avoid_: Policy ปัจจุบันที่เปลี่ยนรายการ Pending อัตโนมัติ, Workflow Migration

**Request Policy Snapshot**:
สำเนา Employee Request Policy ที่ผูกกับคำขอเมื่อส่ง เพื่อคงสิทธิ์ดำเนินการที่จำเป็นของรายการ Pending ตามกติกาเดิม
_Avoid_: Employee Request Policy ปัจจุบัน, การถอนสิทธิ์คำขอเดิมย้อนหลัง

**Administrative Override**:
การใช้อำนาจ Company Admin เปลี่ยน Approval Control Profile หรือแก้ Employee Request Access Gap นอก Flow ปกติ โดยบังคับเหตุผลและเก็บ Log แบบแก้ไม่ได้
_Avoid_: Admin Bypass ที่ไม่มีเหตุผล, การลบประวัติ

**Elevated Approval Requirement**:
ข้อกำหนดเพิ่มสำหรับ Action ความเสี่ยงสูง เช่น REOPEN หรือ SELF_APPROVE ซึ่งใน OWNER_OPERATED ใช้ Permission เหตุผลและหลักฐานเพิ่มได้โดยไม่บังคับผู้อนุมัติอีกคน
_Avoid_: Approval Step เพิ่มโดยอัตโนมัติ, การข้าม Business Invariant

**Delegated Time Administration**:
สิทธิ์ที่ Company มอบให้ Partner Admin ทำงานเวลาแทนภายในช่วงวันที่ Action Permission และ Employee Data Scope ที่ระบุ โดยไม่เกิดจากสถานะ Partner Admin เพียงอย่างเดียว
_Avoid_: Partner Admin access โดยปริยาย, Scope ไม่จำกัด

**Approval Action Permission**:
สิทธิ์ราย Action ของงานคำขอและการอนุมัติ ได้แก่ SUBMIT, CANCEL, ACT_ON_BEHALF, APPROVE, SELF_APPROVE, FINALIZE, REOPEN และ MANAGE_APPROVAL_PROFILE ซึ่งต้องตรวจร่วมกับ Profile และ Employee Data Scope
_Avoid_: Menu Permission, Approval Control Profile

**Work Date**:
วันที่ทางธุรกิจของการทำงานหนึ่งกะ โดยยึดวันที่เริ่มกะ แม้กะสิ้นสุดในวันถัดไป
_Avoid_: วันที่ตามปฏิทินของแต่ละ Attendance Event

**Shift Template**:
แม่แบบตารางทำงานที่มีชื่อและประกอบด้วย Shift Segment ตั้งแต่หนึ่งช่วงขึ้นไป เพื่อใช้จัดตารางให้ Employee หรือ Employee Group
_Avoid_: Shift Assignment, Attendance Event

**Policy Version**:
รุ่นของกะ เกณฑ์เวลา Classification Window หรือ Leave Policy ที่มีวันที่เริ่มใช้และคงเนื้อหาเดิมเมื่อถูกนำไปคำนวณแล้ว
_Avoid_: การแก้ค่าที่เคยใช้ย้อนหลัง, Attendance Result Version

**Shift Segment**:
ช่วงเวลาหนึ่งภายใน Shift Template ที่มีความหมายเป็นเวลาทำงาน เวลาพัก หรือ OT โดยช่วงต่าง ๆ ในกะเดียวกันต้องไม่ซ้อนกัน Segment ประเภท OT กำหนดเพียงช่วงที่รองรับการคำนวณและไม่ใช่การอนุมัติให้ Employee ทำ OT
_Avoid_: Shift Template, Attendance Event, Approved OT Assignment

**Break Deduction**:
จำนวนนาทีพักตาม Shift Segment ประเภท BREAK ที่ตัดออกจาก Attendance Session โดยคิดเฉพาะส่วนที่ซ้อนกับช่วงเวลาที่ Employee อยู่ทำงาน การแตะเครื่องระหว่างพักไม่เปลี่ยนนาทีพักและเก็บเป็น Unclassified Attendance Event เว้นแต่ Company เปิดใช้นโยบายเวลาพักจริงในอนาคต
_Avoid_: เวลาพักแบบเหมาจ่าย, การตีความ Event ช่วงพักโดยอัตโนมัติ

**Net Worked Minutes**:
จำนวนนาทีทำงานหลังหัก Break Deduction และรวมรายการปรับเวลาที่ได้รับอนุมัติแล้ว
_Avoid_: เวลาระหว่างเข้าออกทั้งหมด, Attendance Event

**Completed Minute**:
หน่วยเวลาที่นับจากระยะเวลาจริงครบทุก 60 วินาที โดยรวมวินาทีจาก Attendance Session ทั้งหมดที่ซ้อนกับ Shift Segment เดียวกันก่อน แล้วตัดเศษวินาทีครั้งเดียวเมื่อสรุป Segment
_Avoid_: การตัดเศษแยกแต่ละ Session, นาทีที่ปัดเวลาเข้าและออกแยกกัน, นาทีแบบนับรวมหัวท้าย

**Attendance Tolerance**:
จำนวนนาทีผ่อนผันที่ใช้ตัดสินว่า Employee มีสถานะสายหรือออกก่อนในแต่ละ Attendance Session Rule โดยไม่ใช้ลดจำนวนนาทีที่คลาดจากตารางจริงเมื่อเกินเกณฑ์แล้ว Company กำหนดค่าเริ่มต้นกลางและ Session Rule กำหนดทับได้ โดยค่าที่ใช้ต้องเป็น Policy Version ที่มีวันที่เริ่มใช้
_Avoid_: การปัดเวลา, การยกเว้นนาทีสายบางส่วน

**Expected Attendance Boundary**:
เวลาเข้าออกที่ Employee ควรปฏิบัติตามหลังตัดช่วง Leave Usage ออกจากตาราง และเป็นจุดอ้างอิงของ Attendance Tolerance
_Avoid_: เวลาเริ่มสิ้นสุดกะเดิมโดยไม่พิจารณาการลา

**Late Minutes**:
จำนวนนาทีตั้งแต่เวลาเริ่มงานตามตารางถึงเวลาเริ่มงานจริง เมื่อเกิน Attendance Tolerance แล้ว
_Avoid_: นาทีที่เกินเกณฑ์ผ่อนผันเท่านั้น

**Early Departure Minutes**:
จำนวนนาทีตั้งแต่เวลาออกจริงถึงเวลาสิ้นสุดงานตามตาราง เมื่อเกิน Attendance Tolerance แล้ว
_Avoid_: นาทีที่เกินเกณฑ์ผ่อนผันเท่านั้น

**Attendance Requirement**:
ข้อกำหนดตามช่วงวันที่ว่า Employee ต้องบันทึกเวลาทำงานหรือได้รับยกเว้น โดยช่วงที่มีผลของ Employee คนเดียวกันต้องไม่ซ้อนกัน ระหว่างได้รับยกเว้นระบบยังเก็บตาราง การลา และ Attendance Event แต่ไม่ตัดสิน Absence, Late Arrival, Early Departure หรือ Incomplete Attendance ส่วนเวลาจริงใช้เป็นข้อมูลประกอบโดยไม่เป็นผลตรวจวินัยเวลา
_Avoid_: สวิตช์ถาวรบน Employee, User Permission

**Work Schedule Group**:
กลุ่ม Employee สำหรับรับตารางและหมุนกะร่วมกัน โดยไม่กำหนดสิทธิ์ผู้ใช้หรือสิทธิ์การลา
_Avoid_: Role Group, Leave Policy, กลุ่มพนักงาน

**Work Schedule Group Assignment**:
การผูก Employee เข้ากับ Work Schedule Group ตามช่วงวันที่ โดย Employee มี Assignment ที่มีผลได้เพียงหนึ่งรายการต่อ Work Date และช่วงวันที่ห้ามซ้อนกัน Employee ที่เข้ากลางรอบใช้ Rotation Day ปัจจุบันของกลุ่มตาม Anchor Date เดียวกัน ไม่เริ่ม Day 1 ใหม่ หากเปลี่ยนเฉพาะวันให้ใช้ Schedule Override
_Avoid_: Schedule Override, การอยู่หลายกลุ่มพร้อมกัน

**Group Shift Rotation**:
การจัดให้ Work Schedule Group ใช้ Rotation Pattern พร้อม Anchor Date ของกลุ่มเพื่อเปลี่ยน Shift Template ตามวงรอบ โดย Pattern เดียวใช้กับหลายกลุ่มที่เริ่มต่างเฟสได้ ระบบตรวจความถูกต้องทั้งชุดก่อนบันทึกและนำไปใช้อัตโนมัติเมื่อถึงวันที่มีผล โดยไม่มีสถานะ Draft หรือ Published
_Avoid_: Shift Swap Request, Work Schedule Group

**Rotation Pattern**:
วงรอบตารางงานที่นำกลับมาใช้ซ้ำได้ โดยเรียง Rotation Day และวนซ้ำโดยไม่ผูกกับขอบเขตสัปดาห์หรือเดือน ตำแหน่งเริ่มจริงกำหนดด้วย Anchor Date ของ Group Shift Rotation เมื่อเริ่มใช้แล้วการแก้ต้องสร้าง Version ใหม่
_Avoid_: Shift Template, ตารางรายเดือน

**Rotation Anchor Date**:
วันที่ซึ่ง Group Shift Rotation กำหนดให้ตรงกับ Rotation Day ที่ 1 เพื่อหาตำแหน่งของวงรอบสำหรับ Work Schedule Group นั้น โดยหลายกลุ่มใช้ Pattern เดียวกันแต่มี Anchor Date ต่างกันได้
_Avoid_: วันที่ภายใน Rotation Pattern, วันที่เริ่ม Assignment ของ Employee

**Rotation Day**:
ตำแหน่งหนึ่งวันใน Rotation Pattern ซึ่งกำหนดเป็น Shift Template หรือ Day Off
_Avoid_: Work Date, วันที่ปฏิทินถาวร

**Day Off**:
วันที่ Employee ไม่มีหน้าที่ทำงานตามตาราง และไม่ถือว่าขาดงานเพียงเพราะไม่มี Attendance Event
_Avoid_: Leave, Absence

**Schedule Override**:
ข้อยกเว้นตารางสำหรับ Employee ใน Work Date หนึ่งที่มีลำดับเหนือกว่าตารางจาก Work Schedule Group โดยไม่เปลี่ยน Rotation Pattern
_Avoid_: การแก้ Rotation Pattern, Shift Swap Request

**Leave Policy**:
ชุดกติกาที่กำหนดสิทธิ์การลาตามคุณสมบัติของ Employee เช่น อายุงานหรือประเภทการจ้าง โดยไม่ใช้จัดตารางกะหรือกำหนด Permission
_Avoid_: Work Schedule Group, Role Group, กลุ่มพนักงาน

**Leave Policy Tier**:
ระดับสิทธิ์ภายใน Leave Policy ที่เรียงตามเงื่อนไข เช่น อายุงาน โดยเลือกขั้นสูงสุดที่ Employee เข้าเงื่อนไขและไม่รวมทุกขั้น เว้นแต่ระบุว่าเป็นสิทธิ์เพิ่ม
_Avoid_: Leave Entitlement, การรวมทุกระดับอัตโนมัติ

**Leave Carryover Rule**:
กติกาต่อ Company และ Leave Type ว่าสิทธิ์คงเหลือเมื่อจบรอบไม่ยกยอด ยกทั้งหมด หรือยกได้ไม่เกินจำนวนที่กำหนด พร้อมกำหนดอายุของยอดที่ยกได้
_Avoid_: กติกากลางเดียวทุก Company, Leave Entitlement Adjustment

**Leave Expiration**:
รายการประวัติที่ทำให้สิทธิ์ลาส่วนหนึ่งใช้ไม่ได้เมื่อถึงกำหนด โดยการใช้สิทธิ์ต้องเลือกยอดที่หมดอายุก่อน
_Avoid_: การลบยอดคงเหลือ, Leave Usage

**Net Scheduled Minutes**:
จำนวนนาทีงานปกติตามตารางของ Work Date หลังหักช่วงพักและไม่รวม OT
_Avoid_: Net Worked Minutes, เวลารวมทั้งกะ

**Leave Day**:
หน่วยสิทธิ์ลาที่การลาครบ Net Scheduled Minutes ของ Work Date ใช้หนึ่งวันโดยไม่ขึ้นกับความยาวกะ และการลาบางช่วงใช้ตามสัดส่วนของนาทีงานปกติสุทธิ
_Avoid_: 24 ชั่วโมง, จำนวนชั่วโมงคงที่

**Leave Day Fraction**:
สัดส่วน Leave-covered Minutes ต่อ Net Scheduled Minutes ของ Work Date ซึ่งคำนวณจากค่าต้นทางเต็มและไม่ปัดแยกทีละคำขอ
_Avoid_: Leave Day แบบชั่วโมงคงที่, ค่าที่ปัดสะสม

**Minute-based Leave**:
สิทธิ์ลาที่กำหนดและใช้เป็นนาทีโดยตรงตาม Leave Type แทนการแปลงเป็น Leave Day
_Avoid_: Leave Day, ชั่วโมงที่ปัดเศษ

**Entitlement Cycle**:
รอบเวลาที่ Leave Policy ใช้ให้สิทธิ์ลาแก่ Employee ซึ่งอาจยึดวันครบรอบงานหรือปีปฏิทิน และรอบปีปฏิทินกำหนดการเฉลี่ยสิทธิ์ได้
_Avoid_: Leave Request, Work Schedule Group

**Leave Entitlement**:
สิทธิ์ลาที่ Employee ได้รับใน Entitlement Cycle หนึ่งตาม Leave Policy
_Avoid_: Leave Usage, Leave Balance Adjustment

**Leave Entitlement Adjustment**:
รายการเพิ่มหรือลด Leave Entitlement โดยผู้มี Permission ซึ่งต้องเก็บเหตุผลและผู้ดำเนินการโดยไม่เขียนทับสิทธิ์เดิม
_Avoid_: การแก้ยอดสิทธิ์เดิม, Leave Usage

**Leave Request**:
คำขอลาของ Employee ที่มีวงจรสถานะตั้งแต่รออนุมัติจนถึงอนุมัติ ปฏิเสธ หรือยกเลิก ผู้อนุมัติที่มี Permission แก้รายละเอียดได้พร้อม Approval Edit Log แต่หากเปลี่ยน Leave Type เพิ่มสิทธิ์ที่ใช้ หรือขยายช่วงลา ต้องส่งกลับให้ Employee ยืนยันและเริ่ม Approval Workflow ใหม่
_Avoid_: Leave Entitlement, Attendance Event

**Leave Request Reconfirmation**:
สถานะที่ Employee ต้องยืนยัน Leave Request อีกครั้งหลังผู้อนุมัติเปลี่ยน Leave Type เพิ่มจำนวนสิทธิ์ที่ใช้ หรือขยายช่วงลา โดยระบบแทนที่ Reserved Leave เดิมด้วยยอดตามฉบับแก้แบบ Transaction เดียว การยืนยันใหม่เริ่ม Leave Approval Workflow ใหม่ ส่วนการลดช่วงลาสามารถอนุมัติต่อได้พร้อม Log และการแจ้ง Employee Company กำหนดจำนวนวันรอยืนยันได้
_Avoid_: การอนุมัติการใช้สิทธิ์เพิ่มโดย Employee ไม่ทราบ, Leave Cancellation Request

**Reconfirmation Expired**:
สถานะเมื่อ Employee ไม่ยืนยัน Leave Request ฉบับแก้ที่ยังไม่เคยอนุมัติภายในจำนวนวันที่ Company กำหนด ระบบคืน Reserved Leave อัตโนมัติและคงคำขอกับ Approval Edit Log ไว้ หากยังต้องการลาต้องส่งคำขอใหม่ กติกานี้ไม่ใช้กับคำขอที่เคยอนุมัติแล้วและกลับมายืนยันเพราะตารางเปลี่ยน
_Avoid_: การลบ Leave Request, การกันสิทธิ์ไม่มีกำหนด, การยกเลิกลาเดิมที่เคยอนุมัติ

**Leave Request Mode**:
รูปแบบช่วงลาที่เลือกได้เป็นทั้ง Work Date ทั้ง Shift Segment หรือ Time Range ส่วนคำว่าครึ่งวันเป็นปุ่มลัดที่ Company กำหนด ไม่ใช่หน่วยคำนวณตายตัว
_Avoid_: ครึ่งวันแบบจำนวนชั่วโมงคงที่, Leave Day

**Leave Request Overlap**:
ช่วงเวลาที่ Leave Request สถานะรออนุมัติหรืออนุมัติของ Employee คนเดียวกันซ้อนกัน ซึ่งต้องแก้หรือยกเลิกรายการเดิมก่อนสร้างคำขอใหม่
_Avoid_: Attendance Conflict, คำขอที่ปฏิเสธหรือยกเลิกแล้ว

**Leave Cancellation Request**:
คำขอยกเลิก Leave Request ที่อนุมัติแล้ว โดยต้องผ่านการอนุมัติและคืนสิทธิ์พร้อมคำนวณผลเวลาใหม่โดยไม่ลบประวัติเดิม
_Avoid_: การลบ Leave Request, การยกเลิกคำขอที่ยังรออนุมัติ

**Reserved Leave**:
จำนวนสิทธิ์ที่กันไว้สำหรับ Leave Request ที่รออนุมัติหรือรอ Employee ยืนยันใหม่ ซึ่งลด Available Leave Balance แต่ยังไม่ถือเป็น Leave Usage เมื่อผู้อนุมัติแก้คำขอต้องแทนที่ยอดเดิมด้วยยอดใหม่แบบ Transaction เดียว ห้ามกันทั้งสองยอดพร้อมกัน
_Avoid_: Leave Usage, Leave Entitlement Adjustment, การกันยอดเดิมและยอดใหม่พร้อมกัน

**Leave Usage**:
จำนวนสิทธิ์ที่ใช้จาก Leave Request ที่อนุมัติแล้ว
_Avoid_: Reserved Leave, Leave Entitlement

**Leave-covered Minutes**:
ส่วนของ Leave Request ที่ซ้อนกับ Net Scheduled Minutes และสร้าง Leave Usage โดยไม่นับ Day Off หรือ Holiday ที่ไม่มี Schedule Override หากตารางเปลี่ยนหลังอนุมัติต้องคำนวณใหม่และสร้าง Leave Schedule Change Review เมื่อจำนวนสิทธิ์หรือช่วงที่ครอบคลุมเปลี่ยน
_Avoid_: ช่วงวันปฏิทินทั้งหมดของคำขอ, Net Scheduled Minutes

**Leave Schedule Change Review**:
รายการตรวจสอบที่เกิดเมื่อการเปลี่ยนตารางหลัง Leave Request อนุมัติทำให้ Leave-covered Minutes, Leave Usage หรือช่วงที่ลาได้รับความคุ้มครองเปลี่ยน โดยคงคำขอเดิมไว้และห้ามเปลี่ยนผลอย่างเงียบ ๆ หาก Leave Usage เพิ่มต้องเข้า Leave Request Reconfirmation หากลดลงผู้มี Permission รับรองผลใหม่ได้พร้อมแจ้ง Employee
_Avoid_: Leave Request ใหม่, การคงผลคำนวณเดิมทั้งที่ตารางเปลี่ยน

**Leave Schedule Conflict**:
สถานะเมื่อ Leave Request ที่เคยอนุมัติได้รับผลจากตารางใหม่และ Employee ยังไม่ยืนยัน Leave Usage ที่เพิ่มขึ้น ระบบคงการอนุมัติเดิมไว้ ไม่ยกเลิกอัตโนมัติ และห้าม Finalize Period จนกว่าจะแก้ตาราง ปรับคำขอ หรือยืนยันผลใหม่
_Avoid_: Reconfirmation Expired ของคำขอที่ยังไม่เคยอนุมัติ, การยกเลิก Leave Request เดิมอัตโนมัติ

**Available Leave Balance**:
สิทธิ์ลาที่ Employee ยังยื่นขอได้หลังรวม Leave Entitlement และรายการปรับ แล้วหัก Leave Usage กับ Reserved Leave
_Avoid_: Leave Entitlement, ยอดที่ไม่รวมรายการรออนุมัติ

**Leave Balance Exceeded**:
เหตุผลของ Explained Absence สำหรับส่วนของ Leave Request ที่เกิน Available Leave Balance และไม่ทำให้ยอดลาติดลบ
_Avoid_: Negative Leave Balance, Leave Usage

**Leave Allocation Order**:
ลำดับการใช้ Available Leave Balance กับ Leave Request หลายช่วง โดยจัดสรรจาก Work Date และเวลาที่เก่ากว่าไปใหม่กว่า
_Avoid_: การเลือกวันแบบสุ่ม, การสร้างยอดลาติดลบ

**Leave Approval Workflow**:
กระบวนการตัดสิน Leave Request ตาม Process Approval Policy และ Leave Type ซึ่งอาจเป็น Direct Approval Decision ใน OWNER_OPERATED หรือหลาย Approval Step ใน SEGREGATED_WORKFLOW
_Avoid_: ผู้อนุมัติคนเดียวแบบตายตัว, Employee Request Policy

**Approval Step**:
ขั้นหนึ่งใน SEGREGATED_WORKFLOW ที่มอบหมายให้ผู้มี Permission หรือบทบาทองค์กรที่กำหนดโดยไม่ผูกชื่อบุคคลถาวร
_Avoid_: Request Status, ชื่อผู้ใช้คงที่, Direct Approval Decision

**Approved OT Assignment**:
ช่วง OT ที่ได้รับอนุมัติให้ Employee ทำใน Work Date หนึ่ง และเป็นเพดานช่วงเวลาที่สามารถนับเป็น OT ได้ โดยต้องมีแยกจาก Shift Segment ประเภท OT เสมอ
_Avoid_: Shift Segment, การอยู่เกินเวลาทำงาน, OT อัตโนมัติจากตาราง

**OT Approval Batch**:
รายการอนุมัติ OT ให้ Employee หลายคนหรือ Work Schedule Group ซึ่งเมื่ออนุมัติแล้วต้องเก็บ Snapshot สมาชิกและสร้าง Approved OT Assignment ราย Employee การเปลี่ยนสมาชิกกลุ่มภายหลังไม่เพิ่มหรือลดสิทธิ์เดิม
_Avoid_: Approved OT Assignment เดี่ยว, การอ้างสมาชิกกลุ่มแบบเปลี่ยนตามปัจจุบัน

**OT Approval Workflow**:
กระบวนการตัดสิน OT ตาม Process Approval Policy, OT Day Category หรือกลุ่ม Employee ซึ่งอาจเป็น Direct Approval Decision ใน OWNER_OPERATED หรือหลาย Approval Step ใน SEGREGATED_WORKFLOW
_Avoid_: ผู้อนุมัติชื่อบุคคลถาวร, Employee Request Policy

**OT Amendment**:
รายการเปลี่ยนช่วงเวลาหรือรายชื่อของ Approved OT Assignment ที่อ้างอิงรายการเดิมและผ่าน OT Approval Workflow โดยไม่แก้หรือลบประวัติการอนุมัติเดิม
_Avoid_: การเขียนทับ Approved OT Assignment, OT Cancellation

**OT Cancellation**:
รายการยกเลิกผลของ Approved OT Assignment ที่อ้างอิงรายการเดิม ระบุเหตุผล และผ่าน OT Approval Workflow โดยคงรายการเดิมไว้ตรวจสอบ
_Avoid_: การลบ Approved OT Assignment, OT Amendment

**OT Worked Minutes**:
จำนวนนาทีของ Attendance Session หรือ Time Adjustment ที่ได้รับอนุมัติซึ่งซ้อนกับ Approved OT Assignment โดยไม่เกินช่วงที่อนุมัติ แม้ Employee ได้รับยกเว้นการลงเวลาก็ไม่ให้ OT อัตโนมัติหากไม่มีหลักฐานสองชนิดนี้
_Avoid_: นาทีหลังเลิกงานทั้งหมด, เวลาที่อนุมัติแต่ไม่ได้ทำจริง, OT อัตโนมัติจากการยกเว้นลงเวลา

**Unapproved Extra Work Minutes**:
นาทีของ Attendance Session ที่อยู่นอกงานปกติและนอก Approved OT Assignment ซึ่งเก็บเป็นข้อมูลให้ตรวจสอบแต่ไม่รวมเป็น Net Worked Minutes หรือ OT Worked Minutes จนกว่าจะมีการอนุมัติ OT เพิ่มย้อนหลัง
_Avoid_: OT Worked Minutes, การทิ้งเวลาที่เกิดจริง, OT อัตโนมัติ

**OT Day Category**:
ประเภทของ OT Worked Minutes ว่าเกิดในวันทำงานปกติ Day Off หรือ Holiday โดยไม่หมายถึงอัตราหรือจำนวนเงินค่าจ้าง
_Avoid_: Payroll Rate, Wage Amount

**Attendance Conflict**:
ช่วงเวลาที่หลักฐานหรือผลอนุมัติให้ความหมายซ้อนกันจนสรุปผลไม่ได้ เช่น Attendance Event จริงซ้อน Leave Usage และต้องให้ผู้มี Permission แก้ก่อนปิดผล
_Avoid_: เวลาทำงานและเวลาลาที่นับซ้ำกัน, Warning ที่ไม่ต้องแก้

**Attendance Result**:
ผลสรุปของ Employee ต่อ Work Date ที่ได้จากตารางงาน หลักฐานเวลา การลา OT และรายการปรับ โดยต้องอธิบายย้อนกลับถึงข้อมูลต้นทางได้
_Avoid_: Attendance Event, รายงานที่แก้ตัวเลขโดยตรง

**Absence Minutes**:
Net Scheduled Minutes ที่ไม่มีทั้งเวลาทำงานจริงและ Leave Usage ครอบคลุม โดยอาจเกิดเพียงบางส่วนของ Work Date
_Avoid_: Late Minutes, Day Off

**Explained Absence**:
Absence Minutes ที่มีเหตุผลรับรอง เช่น การลาเกินสิทธิ์ โดยยังนับเป็นขาดงานและไม่สร้าง Leave Usage
_Avoid_: Leave Usage, การขาดงานที่ถูกยกเว้นจากสถิติ

**Full-day Absence**:
สถานะที่ Absence Minutes เท่ากับ Net Scheduled Minutes ทั้งหมดของ Work Date
_Avoid_: Partial Absence, ไม่มี Attendance Event โดยไม่ตรวจตารางและการลา

**Schedule Gap**:
สถานะที่ Employee ต้องลงเวลาแต่ไม่มีตารางงานหรือ Day Off สำหรับ Work Date จึงยังไม่สามารถคำนวณ Absence ได้
_Avoid_: Full-day Absence, Day Off

**Attendance Period**:
งวดวันที่จริงที่สร้างต่อ Company และ Attendance Period Scheme สำหรับตรวจและปิด Attendance Result ของ Employee ในกลุ่มรอบเวลานั้น โดย Company มีหลายงวดที่เดินพร้อมกันได้ Branch มีสถานะรับรองย่อยแต่ไม่สร้าง Period แยก ห้าม Finalize ขณะมี Unresolved Attendance Result และไม่มีการข้ามแบบเงียบ ๆ งวดที่ปิดแล้วต้องเปิดแก้พร้อมเหตุผลและปิดเป็นผลเวอร์ชันใหม่
_Avoid_: Attendance Period Scheme, Entitlement Cycle, งวดเดียวบังคับทั้ง Company

**Transition Attendance Period**:
Attendance Period พิเศษหนึ่งงวดที่ผู้มี Permission ยืนยันเพื่อเชื่อม Scheme Version เดิมกับใหม่เมื่อสูตรต่อกันไม่พอดี ระบบต้องแสดงวันที่ล่วงหน้าและยืนยันว่าไม่มี Work Date หายหรือซ้อนก่อนสร้าง
_Avoid_: การแก้ Period เดิม, ช่องว่างหรือช่วงซ้อนระหว่าง Scheme Version

**Attendance Period Scheme**:
Master ระดับ Company ที่กำหนด Period Generation Pattern สำหรับกลุ่มพนักงาน โดย Company มีได้หลาย Scheme และ Period ภายใน Scheme เดียวกันต้องครอบคลุมวันต่อเนื่องแบบไม่ซ้อนและไม่มีช่องว่าง เช่น 1–15 ต่อด้วย 16–วันสุดท้ายของเดือน
_Avoid_: Attendance Period, การ Hard-code รอบจากประเภทพนักงาน

**Default Attendance Period Scheme**:
Scheme ที่ Company เลือกให้ระบบสร้าง Employee Attendance Period Assignment จริงโดยอัตโนมัติเมื่อพนักงานใหม่ยังไม่มี Assignment โดยต้องเก็บที่มาและประวัติ การเปลี่ยน Default มีผลเฉพาะ Assignment ที่สร้างใหม่และไม่ย้ายพนักงานเดิมย้อนหลัง
_Avoid_: การเลือก Scheme โดยไม่สร้าง Assignment, การย้ายพนักงานเดิมย้อนหลัง

**Bulk Period Scheme Reassignment**:
รายการย้าย Employee หลายคนไป Attendance Period Scheme ใหม่ด้วยวันที่มีผลเดียวกัน โดยต้องตรวจ Assignment ซ้อนและแสดง Attendance Period กับ Attendance Result ที่ได้รับผลกระทบก่อนผู้มี Permission ยืนยัน การบันทึกเป็น Transaction เดียวและหาก Employee คนใดตรวจไม่ผ่านต้องไม่เปลี่ยนทั้งชุด
_Avoid_: การเปลี่ยน Default Scheme เพื่อย้ายพนักงานเดิม, การแก้ Assignment ทีละรายการโดยไม่มีภาพรวม

**Attendance Period Scheme Version**:
รุ่นกติกาสร้างงวดที่มีวันที่เริ่มใช้ ณ ขอบเขต Attendance Period โดยห้ามแก้ Pattern ของ Period ที่สร้างแล้วหรือมี Attendance Result หากจำเป็นต้องแก้ย้อนหลังต้องเปิด Period ที่เกี่ยวข้องและสร้าง Period ทดแทนพร้อมเหตุผลและประวัติ
_Avoid_: การแก้ Attendance Period เดิมโดยตรง, Policy Version ที่ไม่เกี่ยวกับงวด

**Period Review Deadline**:
จำนวนวันหลัง Attendance Period สิ้นสุดที่ Scheme กำหนดให้ Branch Period Review รับรองและให้ Company Finalize โดยระบบแจ้งเตือนเมื่อถึงกำหนดแต่ไม่ปิดงวดอัตโนมัติ
_Avoid_: Automatic Finalization, วันสิ้นสุด Attendance Period

**Period Generation Pattern**:
รูปแบบสร้าง Attendance Period ของ Scheme ซึ่งเลือกได้เป็นเดือนปฏิทิน แบ่งเดือนตามวันตัด รอบทุก N วันหรือสัปดาห์จากวันที่อ้างอิง หรือปฏิทินกำหนดเองล่วงหน้า โดยชื่อประเภทพนักงานไม่เป็นกติกาคำนวณวัน
_Avoid_: Attendance Period, คำว่า “รายวัน” หรือ “รายเดือน” ที่ใช้คำนวณวันโดยตรง

**Employee Attendance Period Assignment**:
การผูก Employee กับ Attendance Period Scheme ตามช่วงวันที่แบบไม่ซ้อนกัน เพื่อระบุว่า Attendance Result ของแต่ละ Work Date ต้องอยู่ในงวดชุดใด เมื่อเปลี่ยน Scheme กลางงวด Work Date ก่อนและหลังวันที่มีผลอยู่กับ Scheme ของช่วงตน หากกระทบวันที่ Finalized ต้องเปิดทุก Period ที่เกี่ยวข้องก่อนแก้
_Avoid_: Work Schedule Group Assignment, Assignment ที่ซ้อนกัน, การย้ายผลจากงวดที่ปิดแล้วโดยไม่เปิดงวด

**Attendance Period Membership**:
ช่วง Work Date ภายใน Attendance Period ที่ Employee มีทั้งสถานะการจ้างและ Employee Attendance Period Assignment ที่มีผล ใช้กำหนดวันที่ต้องคำนวณโดยไม่สร้างงวดย่อยรายบุคคล วันที่นอก Membership ไม่ถือเป็น Absence
_Avoid_: Attendance Period ใหม่ต่อ Employee, วันที่ก่อนเริ่มงานหรือหลังสิ้นสุดงาน

**Period Assignment Gap**:
สถานะของ Employee ที่มีสถานะการจ้างแต่ไม่มี Employee Attendance Period Assignment ครอบคลุม Work Date ทำให้ห้ามละรายการจากรายงานและห้าม Finalize Period ที่เกี่ยวข้องจนกว่าจะจัด Scheme ให้ถูกต้อง
_Avoid_: Schedule Gap, การใช้ Default Scheme แบบไม่สร้างประวัติ

**Branch Period Review**:
สถานะตรวจสอบและรับรองข้อมูลย่อยของ Home Branch ที่มีผลในแต่ละ Work Date ภายใน Attendance Period โดย Branch ที่มี Employee อยู่ใน Scheme ของงวดนั้นต้องรับรองเฉพาะวันที่ตนเป็น Home Branch ให้ครบก่อน Finalize ส่วน Work Branch ตรวจและยืนยันหลักฐานที่เกิดในพื้นที่ตนได้แต่ไม่เป็นเจ้าของการปิดผลหลัก หาก Event, Leave หรือ Time Adjustment เปลี่ยนผลหลังรับรอง ระบบต้องยกเลิกการรับรองเฉพาะ Branch ที่ได้รับผลกระทบพร้อมแสดงรายการเปลี่ยนแปลง
_Avoid_: Attendance Period แยก Branch, Final Attendance Report Version แยก Branch

**Provisional Attendance Report**:
รายงานจาก Attendance Period ที่ยังเปิดและเปลี่ยนแปลงได้ ต้องแสดงสถานะข้อมูลชั่วคราวอย่างชัดเจนและไม่เป็นค่าเริ่มต้นสำหรับการส่งต่ออย่างเป็นทางการ
_Avoid_: Final Attendance Report, รายงานที่ไม่แสดงสถานะงวด

**Final Attendance Report**:
รายงานทางการจาก Attendance Result Version ของ Attendance Period ที่ Finalized แล้ว และเป็นค่าเริ่มต้นสำหรับการส่งออกหรือส่งต่อให้ระบบอื่น หากรายงานรวมหลาย Scheme ทุก Period ที่ครอบคลุมช่วงรายงานต้อง Finalized ครบจึงถือเป็นรายงานทางการ
_Avoid_: Provisional Attendance Report, ข้อมูลจากงวดเปิดที่ไม่มีคำเตือน

**Consolidated Attendance Report**:
รายงานรวม Employee จากหลาย Attendance Period Scheme ซึ่งเป็น Final Attendance Report ได้เมื่อทุก Period ที่ครอบคลุมช่วงรายงาน Finalized แล้วเท่านั้น หากมีงวดเปิดแม้หนึ่งรายการ รายงานทั้งฉบับเป็นข้อมูลชั่วคราวและต้องระบุ Scheme กับ Period ที่ค้าง
_Avoid_: การผสมผล Finalized กับผลชั่วคราวโดยไม่แสดงสถานะ

**Final Attendance Report Version**:
ฉบับรายงานทางการที่ผูกกับ Attendance Result Version หนึ่งโดยห้ามลบ เมื่อเปิดงวดแก้และ Finalize ใหม่ต้องสร้างฉบับใหม่ที่อ้างอิงฉบับเดิมพร้อมเหตุผล ผู้เปิดงวด และเวลาสร้าง โดยการส่งออกใหม่ใช้ฉบับล่าสุด
_Avoid_: การเขียนทับหรือลบรายงานเดิม, Provisional Attendance Report

**Late Period Event**:
Attendance Event ที่มาถึงหลัง Attendance Period ถูกปิดและต้องรอตรวจสอบก่อนเปลี่ยนผลที่สรุปแล้ว
_Avoid_: Unclassified Attendance Event, Event ที่ถูกทิ้ง

**Holiday Calendar**:
ปฏิทินวันหยุดของ Company ที่ Branch สามารถใช้ชุดเฉพาะหรือเพิ่มและยกเว้นบางวันได้ โดยวันหยุดอยู่เหนือตารางหมุนกะแต่ต่ำกว่า Schedule Override
_Avoid_: Day Off, Leave, ปฏิทินกลางที่บังคับทุก Branch

**Menu Group**:
หมวดเมนูภายใน Project ซึ่งรวมหน้าจอที่เกี่ยวข้องและยุบหรือขยายได้
_Avoid_: Project, System

**Main Menu**:
หน้าจอปลายทางภายใน Menu Group ซึ่งมี MenuCode และ Permission ของตนเอง
_Avoid_: Menu Group, Project

**Company Project Entitlement**:
สิทธิ์ระดับ Company ที่ระบุว่า Partner เปิด Business Project ใดให้ลูกค้าใช้งาน
_Avoid_: User Permission, Menu Permission

**User Project Access**:
สิทธิ์ระดับ User ที่ระบุว่าผู้ใช้เข้า Project ใดได้ ภายใต้ Project ที่ Company ได้รับสิทธิ์แล้ว
_Avoid_: Company Project Entitlement

**Canonical Workspace**:
Git repository `laoo` ที่เป็นแหล่งโค้ดจริงเพียงแห่งเดียวของ LAOO Core, Business Project และ Shared Package
_Avoid_: สำเนา Project ภายนอก, Shared Folder

**Project Application**:
แอป Flutter ของ Business Project ที่อยู่ใต้ `projects/<project>` ภายใน Canonical Workspace
_Avoid_: Repository แยก, สำเนา Core

**Legacy Project Copy**:
โฟลเดอร์หรือ repository เดิมที่เก็บไว้เพื่อกู้คืนหรือเทียบประวัติเท่านั้น และห้ามใช้พัฒนา Feature ใหม่
_Avoid_: Active Project, Source of Truth

## Inventory Language

**Item**:
ทะเบียนกลางของสิ่งที่ Company ซื้อ ขาย ใช้ หรือนำไปให้บริการ โดยรหัสเดียวอาจมีหลายวัตถุประสงค์
_Avoid_: Product, Spare Part, Material เมื่อหมายถึงทะเบียนหลัก

**Item Kind**:
ลักษณะพื้นฐานของ Item ว่าเป็นสิ่งของ (`GOODS`) หรือบริการ (`SERVICE`)
_Avoid_: Item Type, Usage

**Stock Tracking**:
ระดับการควบคุมคงเหลือของ Item ได้แก่ไม่ควบคุม (`NONE`), ตามจำนวน (`QUANTITY`) หรือตาม Serial (`SERIAL`)
_Avoid_: Item Kind, Usage

**Item Usage**:
วัตถุประสงค์ที่ Item ถูกนำไปใช้ ได้แก่ขาย วัสดุ อุปกรณ์ หรืออะไหล่ โดย Item หนึ่งรายการมีได้หลาย Usage
_Avoid_: Item Group, Item Type

**Warehouse**:
สถานที่เก็บ Item ภายใต้ Branch ซึ่งเป็นขอบเขตของยอดคงเหลือและการเคลื่อนไหว
_Avoid_: Branch, Room

**Item Project Availability**:
ขอบเขต Project ที่นำ Item ของ Company ไปใช้ได้ แยกจากวัตถุประสงค์และไม่ทดแทนสิทธิ์ของผู้ใช้
_Avoid_: Item Usage, User Permission

**Item Classification Default**:
ค่าเริ่มต้นของชนิด วิธีควบคุมสต็อก และวัตถุประสงค์สำหรับสินค้าใหม่ในกลุ่มหรือประเภทนั้น ไม่ใช่คำสั่งเปลี่ยนสินค้าที่มีอยู่แล้ว
_Avoid_: Item Project Availability

**Item Instance**:
หน่วยจริงหนึ่งชิ้นของ Item แบบ Serial ซึ่งมี Serial สถานะ และตำแหน่งปัจจุบันเฉพาะตัว
_Avoid_: Item, Stock Balance

**Inventory Fulfillment**:
หลักฐานว่ารายการต้นทางถูกตัดสต็อกโดยเอกสารใดแล้ว เพื่อป้องกันการตัดจำนวนหรือ Serial ซ้ำ
_Avoid_: Stock Movement, Invoice Line

## People Language

**Person**:
ตัวตนกลางของบุคคลหนึ่งคนภายใน Company ซึ่งอาจมีหลายบทบาทและมีบัญชีเข้าใช้งานเดียวกัน
_Avoid_: Employee, Resident, User เมื่อต้องการกล่าวถึงตัวบุคคล

**Employee**:
บทบาทการทำงานของ Person ภายใน Company ซึ่งมีข้อมูลเฉพาะงาน เช่น รหัสพนักงาน ฝ่าย แผนก และตำแหน่ง
_Avoid_: Person, User

**Employee Organization Assignment**:
ประวัติช่วงวันที่ที่ Employee สังกัด Branch ฝ่าย และแผนก เพื่อให้ทุก Project อ้างโครงสร้างองค์กรตามวันที่เกิดรายการแทนค่าปัจจุบัน
_Avoid_: สังกัดปัจจุบันบน Employee, Work Schedule Group

**Home Branch**:
Branch ที่ Employee สังกัดตาม Employee Organization Assignment ใน Work Date
_Avoid_: Work Branch, Branch ของอุปกรณ์ที่รับ Event

**Work Branch**:
Branch ที่ Employee ถูกจัดให้ปฏิบัติงานตามตารางหรือ Schedule Override ใน Work Date ซึ่งอาจต่างจาก Home Branch
_Avoid_: Home Branch, การย้ายสังกัด

**Resident**:
บทบาทการพักอาศัยของ Person ซึ่งผูกกับสถานที่พักและช่วงเวลาการเข้าพัก
_Avoid_: Employee, User, Tenant เมื่อหมายถึงผู้พักอาศัยทุกประเภท

**User**:
บัญชีที่ Person ใช้ยืนยันตัวตนและเข้าสู่ระบบ โดยหนึ่ง Person ภายใน Company มีบัญชีหลักเพียงหนึ่งบัญชี
_Avoid_: Person, Employee, Resident
