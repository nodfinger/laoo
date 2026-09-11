# รองรับหลายรอบลงเวลาด้วย Session Rule ที่เรียงลำดับ

Shift Template มี Attendance Session Rule ได้หลายรายการ แต่ละรายการประกอบด้วย Classification Window ฝั่งเข้าและออกอย่างละหนึ่งช่วงเพื่อเลือก Primary Attendance Event และสร้าง Attendance Session ของรอบนั้น ทุก Window ภายใน Work Date ต้องเรียงลำดับและไม่ซ้อนกันเพื่อให้ Event มีความหมายเดียว รอบเช้าและรอบบ่ายที่ต้องลงเวลาแยกกันจึงสร้างคนละ Session ส่วนงานปกติที่ต่อเนื่องถึง OT ใช้ Session Rule เดียวครอบคลุมหลาย Shift Segment ได้ เหตุผลคือจำนวน Session ต้องสะท้อนรอบที่ธุรกิจกำหนดให้ลงเวลาจริง ไม่ใช่จำนวน Segment ที่ใช้แบ่งความหมายของนาที
