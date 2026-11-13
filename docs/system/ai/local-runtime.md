# การติดตั้งและรัน Local AI

## ตำแหน่ง

เครื่องหลักใช้ `C:\RYPIT\local-ai` นอก repository: `ollama/` เป็น runtime, `models/` เป็นโมเดล, `fine-tuning/` และ log เป็นข้อมูลเฉพาะเครื่อง ไม่ใส่ Git

## การเริ่มบริการ

จาก `C:\RYPIT\laoo` ใช้ `powershell -ExecutionPolicy Bypass -File tools/start-local-assistant.ps1` สคริปต์ค้น runtime และ models ใน `C:\RYPIT\local-ai`, ตั้ง `OLLAMA_HOST=127.0.0.1:11434`, `OLLAMA_NO_CLOUD=1` และ `OLLAMA_MODELS`; หากมีบริการตอบอยู่แล้วจะไม่เปลี่ยนการตั้งค่าของบริการนั้น

เครื่องยืมต้องติดตั้ง runtime และโมเดลในโฟลเดอร์เดียวกันแยกจาก Git ตั้งค่า `Assistant:Model` และ `Assistant:Endpoint` ของเครื่องผ่านวิธีตั้งค่าที่ใช้งานอยู่โดยไม่ commit secrets แล้วตรวจชื่อโมเดลและสิทธิ์ใช้งานก่อนเริ่มบริการ ดู [LOCAL_SETUP](../../../tools/assistant-safety-tests/LOCAL_SETUP.md)

## ข้อจำกัด

การตั้งค่า loopback และ `OLLAMA_NO_CLOUD` ไม่ใช่ firewall; การเปิดบริการเดิมไม่ได้ยืนยันว่าใช้โมเดลหรือ path เดียวกัน ต้องตรวจแยกในเครื่องนั้น เอกสารนี้ไม่ได้เปลี่ยน runtime และไม่ยืนยันว่าบริการกำลังทำงาน

## โมเดลที่เอกสารการทดสอบเดิมระบุ

`qwen3:4b-instruct-2507-q4_K_M` ระบุ Apache 2.0; `qwen2.5:3b` ระบุใช้วิจัยไม่เชิงพาณิชย์ ต้องตรวจสิทธิ์รุ่นที่ติดตั้งก่อนใช้งานธุรกิจ ข้อมูลนี้เป็นบันทึกเดิม ไม่ยืนยันรุ่นที่บริการกำลังใช้
