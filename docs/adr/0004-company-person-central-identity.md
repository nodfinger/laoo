# ใช้ Person เป็นตัวตนกลางของบุคคลใน Company

LAOO ใช้ Person เป็นเจ้าของข้อมูลตัวตนร่วม และให้ Employee, Resident และบทบาทในอนาคตเชื่อมมายัง Person เดียวกัน โดยหนึ่ง Person มีบัญชี User หลักหนึ่งบัญชี เหตุผลคือการใช้ Employee แทนทุกคนจะทำให้ความหมายผิดสำหรับธุรกิจหอพัก แต่การย้ายระบบเดิมออกจาก Employee ทั้งหมดในครั้งเดียวเสี่ยงกระทบ Authentication, Permission และ Business Project จึงคง Employee และ TDADUserEmployee ไว้เป็นชั้นความเข้ากันได้ระหว่างการย้ายทีละส่วน พนักงาน Partner ยังอยู่นอกขอบเขต Person ของ Company
