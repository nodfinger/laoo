# ตรวจ Permission และ Employee Data Scope ร่วมกัน

การดูหรือจัดการข้อมูล LAOO_TIME ต้องผ่านทั้ง Action Permission และ Employee Data Scope ซึ่งกำหนดจาก Company, Home Branch, ฝ่าย, แผนก หรือสายบังคับบัญชาที่มีผลตามช่วงวันที่ Backend ต้องตรวจ Scope ทุก Request และห้ามเชื่อ EmployeeID หรือขอบเขตที่ Client ส่งมา Employee ทั่วไปมี Scope เฉพาะตนเอง เหตุผลคือ Menu Permission ระบุว่าผู้ใช้ทำ Action ใดได้แต่ไม่ระบุว่าทำกับพนักงานคนใด การตรวจเพียงเมนูเปิดช่องให้เข้าถึงข้อมูลต่างสาขาหรือของบุคคลอื่นได้
