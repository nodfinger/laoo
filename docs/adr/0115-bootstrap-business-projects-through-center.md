# Bootstrap Business Project ผ่าน Center ก่อนแยกเครื่องพัฒนา

LAOO ให้เครื่อง Center สร้าง Project Bootstrap และสัญญาเชื่อมต่อกับ Core ก่อน แล้วจึงให้เครื่อง Project พัฒนาเฉพาะ Business Workflow ภายใต้ `projects/<project>` เพราะการสร้างทั้งระบบบนเครื่อง Core ทำให้แยก Ownership ภายหลังยาก ขณะที่การแยกเครื่องโดยไม่มี Bootstrap ทำให้พบปัญหา Authentication, Navigation, Shared Contract และ Migration ช้าเกินไป การเปลี่ยนที่มี Core Impact ต้องเป็น PR แยกและ Merge แบบ backward-compatible ก่อน Project PR ที่เรียกใช้เสมอ
