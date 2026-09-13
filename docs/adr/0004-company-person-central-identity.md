# ใช้ Person เป็นตัวตนกลางของบุคคลใน Company

LAOO ใช้ Person เป็นเจ้าของข้อมูลตัวตนร่วม และให้ Employee, Resident และบทบาทในอนาคตเชื่อมมายัง Person เดียวกัน โดยหนึ่ง Person มีบัญชี User หลักหนึ่งบัญชี เหตุผลคือการใช้ Employee แทนทุกคนจะทำให้ความหมายผิดสำหรับธุรกิจหอพัก แต่การย้ายระบบเดิมออกจาก Employee ทั้งหมดในครั้งเดียวเสี่ยงกระทบ Authentication, Permission และ Business Project จึงคง Employee และ TDADUserEmployee ไว้เป็นชั้นความเข้ากันได้ระหว่างการย้ายทีละส่วน พนักงาน Partner ยังอยู่นอกขอบเขต Person ของ Company

## Project-owned screens and roles

`TDADPerson` remains the Company-scoped identity and stores only shared person attributes. Business Projects own their role records and screens. Service owns menu `14004`, route `/service/persons`, and `TDADServiceCustomer`; resident details remain in `TDADResident`. The Service registry resolves only Service roles and never exposes Employee or User roles. The Core registry may summarize roles across Projects without owning or editing role-specific attributes.

Role labels are projections of active relationships, not editable tags. A Person can therefore be both Resident and Service Customer without duplication. Shared person edits require the `PERSON_EDIT` permission point and optimistic concurrency, while ordinary Service `EDIT` changes only Service-owned role data.
