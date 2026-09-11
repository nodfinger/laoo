# เตรียม Contract กลางก่อนพัฒนา Connector เครื่องลงเวลา

เฟสแรกของ LAOO_TIME สร้าง Canonical Attendance Import Contract พร้อมพื้นที่พักข้อมูล การจับคู่ Attendance Device Code การป้องกัน Replay Duplicate และ Audit แต่ยังไม่พัฒนา Attendance Source Connector เฉพาะเครื่องสแกนนิ้ว ใบหน้า GPS Mobile หรือเทคโนโลยีอื่น Connector ในอนาคตมีหน้าที่เพียงแปลงข้อมูลต้นทางเข้า Contract กลางและห้ามฝังกติกาคำนวณ Attendance Result เหตุผลคือเทคโนโลยีรับเวลาจะเปลี่ยนได้ แต่หลักฐานและกติกาคำนวณต้องคงรูปแบบเดียวเพื่อไม่ให้ผลต่างกันตามอุปกรณ์
