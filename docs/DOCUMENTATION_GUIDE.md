# Documentation Guide

Version: 1.0  
Baseline: 2026-08-09

| เมื่อต้องทำเรื่อง | ต้องอ่านก่อน | อ่านประกอบ |
|---|---|---|
| เข้าใจภาพรวม | `PROJECT_CONTEXT.md` | `architecture/ARCHITECTURE.md` |
| Login/Session/User Type | `architecture/AUTHENTICATION_STRUCTURE.md` | `api/AUTH_LOGIN_API.md`, `api/POST_LOGIN_CONTEXT_API.md` |
| Partner/Customer/Branch | `business/ORGANIZATION_AND_MODULE_STANDARD.md` | `architecture/DATABASE_STRUCTURE.md` |
| เปิด–ปิด Module | `business/ORGANIZATION_AND_MODULE_STANDARD.md` | `standards/API_AND_SECURITY_STANDARD.md` |
| ออกแบบฐานข้อมูล | `architecture/DATABASE_STRUCTURE.md` | `standards/DATABASE_DELIVERY_STANDARD.md` |
| สร้างหรือแก้ API | `standards/API_AND_SECURITY_STANDARD.md` | Contract ใน `api/` |
| UX/UI, Workspace และ Screen Flow | `standards/UX_UI_STANDARD.md` | `standards/TYPOGRAPHY_STANDARD.md` |
| Pagination/List | `standards/PAGINATION_UI_STANDARD.md` | `standards/UX_UI_STANDARD.md` |
| Theme | `standards/THEME_STANDARD.md` | `standards/UX_UI_STANDARD.md`, `standards/WORKSPACE_STANDARD.md` |
| Routing/Route Guard | `standards/ROUTING_STANDARD.md` | `architecture/AUTHENTICATION_STRUCTURE.md` |
| Flutter State | `standards/STATE_MANAGEMENT_STANDARD.md` | `architecture/ARCHITECTURE.md` |
| Environment/Repository/Git | `standards/DEVELOPMENT_ENVIRONMENT_STANDARD.md` | `standards/REPOSITORY_STANDARD.md`, `standards/GIT_STANDARD.md` |
| ตรวจมติล่าสุด | `DECISIONS.md` | `history/LAOO_PLAZA_MEETING_SUMMARY_2026-08-09.md` |
| ตรวจไฟล์เก่าที่ถูกตัด | `DOCUMENT_CLEANUP_REPORT.md` | `DOCUMENT_INVENTORY.md` |

## กฎสำหรับทีมและ AI

- อ่านไฟล์บังคับก่อนแก้ Code หรือ Database
- หากเอกสารขัดกัน ให้ใช้ลำดับใน `README.md`
- ห้ามนำเอกสาร History มาแทน Standard ปัจจุบัน
- ห้ามสร้าง Project Master, Project mapping หรือ TenantCode กลับมาโดยไม่มีมติใหม่
- หากชื่อ Method/Class/Table จริงไม่แน่ชัด ให้ตรวจ Source/Schema ล่าสุด ห้ามเดา
- ก่อนแก้ UX/UI ให้สรุปเพื่ออนุมัติ เว้นแต่ได้รับคำสั่งให้ Code จริงทันที
- เมื่อเปลี่ยนข้อกำหนด ต้องอัปเดต Standard ที่เกี่ยวข้อง, `DECISIONS.md` และ Guide หากเส้นทางเอกสารเปลี่ยน
