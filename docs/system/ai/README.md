# ดัชนีระบบ AI

AI ส่วนกลางรับคำถาม ตรวจความสามารถและสิทธิ์ แล้วส่งต่อ Agent หรือการทำงานที่รองรับตาม Backend การมีรายการในทะเบียนไม่ได้ยืนยันว่าบริษัทเปิดใช้งานแล้ว

## เอกสาร

- [สถาปัตยกรรมและการตั้งค่า](architecture-settings.md)
- [ทะเบียนความสามารถและสิทธิ์](capabilities-permissions.md)
- [ติดตั้ง Local AI](local-runtime.md)
- [แจ้งซ่อม](service.md) · [เบิกเดินทาง](travel.md) · [ห้องประชุม](meeting.md) · [สต๊อก](stock.md) · [ค้นหาเมนู](menu-guide.md)
- [รายงานผลกระทบ](../../reports/AI_DOCUMENT_ORGANIZATION_20261113.md)

## หน้าจอ

เมนู `10008` จัดการความสามารถ AI; `64001` ทดสอบคำถาม; `64002` ตั้งค่า AI; `64003` Agent มี Route ใน registry แต่การแสดงจริงขึ้นกับทะเบียนและสิทธิ์ในฐานข้อมูล

## Agent และ CapabilityCode ที่พบในโค้ด

Agent `service`, `stock`, `meeting`, `travel` มีนิยามใน Backend ส่วน `core.menu_guide` เป็นความสามารถส่วนกลาง แหล่งจริงคือ `AssistantCapability.cs` และ `AssistantAgentRegistry.cs`

| CapabilityCode | ProjectCode | MenuCode | ScreenType | Action | ระบบ |
|---|---|---|---:|---|---|
| `repair.create_own` | `LAOO_SERVICE` | `20001` | 1 | `CREATE` | [repair.create_own](service.md) |
| `repair.track_own` | `LAOO_SERVICE` | `20002` | 3 | `VIEW` | [repair.track_own](service.md) |
| `repair.parts_cost` | `LAOO_SERVICE` | `19002` | 3 | `VIEW` | [repair.parts_cost](service.md) |
| `repair.pending` | `LAOO_SERVICE` | `17001` | 2 | `VIEW` | [repair.pending](service.md) |
| `stock.serial_lookup` | `LAOO_STOCK` | `08006` | 3 | `VIEW` | [stock.serial_lookup](stock.md) |
| `repair.serial_history` | `LAOO_SERVICE` | `19002` | 3 | `VIEW` | [repair.serial_history](service.md) |
| `meeting.availability` | `LAOO_MEETING` | `21001` | 1 | `VIEW` | [meeting.availability](meeting.md) |
| `meeting.own_bookings` | `LAOO_MEETING` | `21001` | 1 | `VIEW` | [meeting.own_bookings](meeting.md) |
| `meeting.invitations` | `LAOO_MEETING` | `21003` | 2 | `VIEW` | [meeting.invitations](meeting.md) |
| `travel.claim_summary` | `LAOO_MY` | `66001` | 4 | `VIEW` | [travel.claim_summary](travel.md) |
| `core.menu_guide` | `LAOO_AI` | `10008` | 1 | `VIEW` | [core.menu_guide](menu-guide.md) |

## ตำแหน่งโค้ด

- `lib/features/assistant/`: Flutter Chat, Settings, Capability, Agent และ Intent test
- `laoo_api/Services/Assistant/`: classifier, router, permissions, Agent และ local model
- `laoo_api/Controllers/Assistant*.cs`: API และ `ServiceRequestController.cs`, `TravelClaimController.cs`, `CompanySetupController.cs` มีส่วน AI ร่วมด้วย
- `database/migrations/`: ทะเบียน AI และข้อมูลตั้งต้น; `test/assistant/`, `tools/assistant-safety-tests/`, `tools/agent-registry-tests/`: ชุดตรวจ

ตัวอย่างคำถามที่บริษัทแก้ไขเก็บในฐานข้อมูล เช่น `TDADAiCapabilityCompany.ExamplesJson` การย้ายเอกสารไม่เปลี่ยนฐานข้อมูลหรือฝึกโมเดล
