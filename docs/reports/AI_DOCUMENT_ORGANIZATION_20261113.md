# รายงานจัดเอกสาร AI — 13 พฤศจิกายน 2569

- ย้ายสเปกปัจจุบัน 5 ไฟล์จาก docs/AI_AGENT_ARCHITECTURE.md, AI_CHAT_SETTINGS.md, AI_CAPABILITY_REGISTRY.md, ai_meeting_capability_inventory.md, ai_travel_claim_summary.md เข้า docs/system/ai/ โดยรักษาเนื้อหาและลบต้นฉบับ; แบบร่างและรายงานประวัติยังคงอยู่
- รูป AI Chat: เอกสารเก่าระบุ 1 MB แต่ AGENTS.md และ `lib/features/assistant/ai_image_picker.dart` กำหนด 3 × 1024 × 1024 bytes; `CompanySetupController.cs` และ `AssistantCapabilitiesController.cs` ตรวจเพดานเดียวกัน ข้อความหน้าจอใช้คำว่า 3 MB เอกสารใหม่ระบุ 3 MiB ตามจำนวน bytes ที่พบ
- สต๊อก: เอกสาร Agent เก่าระบุยังไม่มีความสามารถ แต่ `StockAssistantAgent.cs` และ `AssistantCapability.cs` ลงทะเบียน `stock.serial_lookup` แล้ว; การเปิดใช้จริงต้องตรวจฐานข้อมูลและสิทธิ์
- `tools/start-local-assistant.ps1` คำนวณ path ไป `C:\RYPIT\local-ai` เมื่อ repo อยู่ที่ `C:\RYPIT\laoo`; เครื่องยืมต้องติดตั้งแยก หาก repo อยู่คนละโครงสร้าง path ต้องตรวจสคริปต์ก่อนใช้งาน
- ไม่ย้าย runtime, โมเดล หรือแก้ API/ฐานข้อมูล; ตัวอย่างคำถามและการเปิด capability ของบริษัทอยู่ในฐานข้อมูลและไม่ถูกเปลี่ยนจากการย้ายเอกสาร
- สถานะในเอกสารเป็นหลักฐาน repository ไม่ยืนยัน migration, สิทธิ์ หรือบริการของเครื่องปลายทาง
