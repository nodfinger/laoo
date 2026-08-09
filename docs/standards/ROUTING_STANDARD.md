# Routing Standard

Version: 1.0  
Updated: 2026-08-09

- ใช้ Central Router ของ Flutter Project ห้ามกระจาย Route definition โดยไม่มีเหตุผล
- Landing เป็นหน้าเริ่มต้นก่อน Login และมีปุ่ม Login ด้านขวาบน
- Protected route ต้องตรวจ Authentication และ Permission ก่อนเปิด
- Route ของ Module ที่ไม่ Effective ต้องเข้าไม่ได้ แม้พิมพ์ URL หรือ Route โดยตรง
- ไม่มี Permission ให้ซ่อนเมนูและ Action ที่นำไป Route นั้น
- Deep link ต้องผ่าน Guard เดียวกับการกดเมนู
- เมื่อ Session หมดอายุให้ล้างข้อมูล Sensitive และกลับหน้า Login โดยรักษา Return URL เฉพาะเมื่อปลอดภัย
- Route name/path ใช้ค่าคงที่ส่วนกลางและชื่อสื่อความหมาย
- ห้ามใช้ `projectCode` เพื่อเลือก Router tree ของ Laoo Plaza

