# Document Inventory

Source: `docs(1).zip`  
Baseline date: 2026-08-09

ตารางนี้ระบุผลการพิจารณาไฟล์ต้นฉบับทุกไฟล์ โดยไม่รวม `.gitkeep` และโฟลเดอร์ว่าง

| ไฟล์เดิม | ผล | ปลายทาง | หมายเหตุ |
|---|---|---|---|
| `AGENTS.md` | MERGE/RETIRE | `เอกสาร Baseline ที่เกี่ยวข้อง` | ไม่เก็บเป็นไฟล์แยกเพื่อลดความซ้ำซ้อน |
| `DECISIONS.md` | REPLACE | `README.md / DOCUMENTATION_GUIDE.md / DECISIONS.md` | แทนด้วย Entry point และมติ Baseline ใหม่ |
| `DOCUMENTATION_CHANGELOG.md` | MERGE/RETIRE | `เอกสาร Baseline ที่เกี่ยวข้อง` | ไม่เก็บเป็นไฟล์แยกเพื่อลดความซ้ำซ้อน |
| `FILE_MANIFEST.md` | REPLACE | `README.md / DOCUMENTATION_GUIDE.md / DECISIONS.md` | แทนด้วย Entry point และมติ Baseline ใหม่ |
| `PROJECT_CONTEXT.md` | REPLACE | `README.md / DOCUMENTATION_GUIDE.md / DECISIONS.md` | แทนด้วย Entry point และมติ Baseline ใหม่ |
| `PROJECT_WORKFLOW_STANDARD.md` | MERGE/RETIRE | `เอกสาร Baseline ที่เกี่ยวข้อง` | ไม่เก็บเป็นไฟล์แยกเพื่อลดความซ้ำซ้อน |
| `README.md` | REPLACE | `README.md / DOCUMENTATION_GUIDE.md / DECISIONS.md` | แทนด้วย Entry point และมติ Baseline ใหม่ |
| `SYSTEM_MAP.md` | REPLACE | `README.md / DOCUMENTATION_GUIDE.md / DECISIONS.md` | แทนด้วย Entry point และมติ Baseline ใหม่ |
| `api/API_ERROR_STANDARD.md` | MERGE/REPLACE | `standards/API_AND_SECURITY_STANDARD.md หรือ api/ contract` | รวมมาตรฐาน; Contract หลักเขียนใหม่ตาม Baseline |
| `api/API_RESPONSE_STANDARD.md` | MERGE/REPLACE | `standards/API_AND_SECURITY_STANDARD.md หรือ api/ contract` | รวมมาตรฐาน; Contract หลักเขียนใหม่ตาม Baseline |
| `api/AUTH_LOGIN_API.md` | MERGE/REPLACE | `standards/API_AND_SECURITY_STANDARD.md หรือ api/ contract` | รวมมาตรฐาน; Contract หลักเขียนใหม่ตาม Baseline |
| `api/MENU_API.md` | MERGE/REPLACE | `standards/API_AND_SECURITY_STANDARD.md หรือ api/ contract` | รวมมาตรฐาน; Contract หลักเขียนใหม่ตาม Baseline |
| `api/PERMISSION_API.md` | MERGE/REPLACE | `standards/API_AND_SECURITY_STANDARD.md หรือ api/ contract` | รวมมาตรฐาน; Contract หลักเขียนใหม่ตาม Baseline |
| `api/POST_LOGIN_CONTEXT_API.md` | MERGE/REPLACE | `standards/API_AND_SECURITY_STANDARD.md หรือ api/ contract` | รวมมาตรฐาน; Contract หลักเขียนใหม่ตาม Baseline |
| `api/SESSION_API.md` | MERGE/REPLACE | `standards/API_AND_SECURITY_STANDARD.md หรือ api/ contract` | รวมมาตรฐาน; Contract หลักเขียนใหม่ตาม Baseline |
| `api/SYSTEM_INFO_API.md` | MERGE/REPLACE | `standards/API_AND_SECURITY_STANDARD.md หรือ api/ contract` | รวมมาตรฐาน; Contract หลักเขียนใหม่ตาม Baseline |
| `architecture/ARCHITECTURE.md` | MERGE/REPLACE | `architecture/ARCHITECTURE.md` | รวมเฉพาะ Architecture ปัจจุบัน |
| `architecture/AUTHENTICATION_STRUCTURE.md` | MERGE/REPLACE | `architecture/ARCHITECTURE.md` | รวมเฉพาะ Architecture ปัจจุบัน |
| `architecture/DATABASE_STRUCTURE.md` | MERGE/REPLACE | `architecture/ARCHITECTURE.md` | รวมเฉพาะ Architecture ปัจจุบัน |
| `architecture/MULTI_PROJECT_ARCHITECTURE.md` | RETIRE | `-` | อ้างอิง Project Master/Project routing model ที่ถูกยกเลิก |
| `architecture/PROJECT_CONNECTION_RESOLVER.md` | RETIRE | `-` | อ้างอิง Project Master/Project routing model ที่ถูกยกเลิก |
| `architecture/PROJECT_DATABASE_ARCHITECTURE.md` | RETIRE | `-` | อ้างอิง Project Master/Project routing model ที่ถูกยกเลิก |
| `authentication/API_AUTHENTICATION.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/AUDIT_LOG_STANDARD.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/AUTHENTICATION_CHANGELOG.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/AUTHENTICATION_SEQUENCE.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/AUTHENTICATION_STRUCTURE.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/DASHBOARD_ROUTING.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/DASHBOARD_SELECTION_STANDARD.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/DATABASE_STRUCTURE.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/DESIGN_DECISION.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/ERROR_CODE_STANDARD.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/JWT_STANDARD.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/LAOO_SUPPORT_LOGIN.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/MENU_GENERATION_STANDARD.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/MENU_LOADING.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/NORMAL_USER_LOGIN.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/PASSWORD_STANDARD.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/PERMISSION_API_IMPLEMENTATION_PLAN.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/PERMISSION_API_IMPLEMENTED.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/PERMISSION_DATABASE_MAPPING.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/PERMISSION_IMPLEMENTATION_REVIEW.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/PERMISSION_LOADING.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/PERMISSION_REQUIREMENTS_FOR_DATABASE.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/POST_LOGIN_FLOW.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/POST_LOGIN_SEQUENCE_DIAGRAM.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/README.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/SECURITY_STANDARD.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/SESSION_BOOTSTRAP.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/SESSION_STANDARD.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `authentication/SESSION_STORAGE_STANDARD.md` | MERGE | `architecture/AUTHENTICATION_STRUCTURE.md` | รวมสาระที่ยังใช้ได้และตัด Project-based model |
| `business/BRANCH_MODULE_STANDARD.md` | MERGE | `business/ORGANIZATION_AND_MODULE_STANDARD.md` | รวม Organization, ownership และ Module rule |
| `business/BRANCH_STANDARD.md` | MERGE | `business/ORGANIZATION_AND_MODULE_STANDARD.md` | รวม Organization, ownership และ Module rule |
| `business/BUSINESS_CODE_STANDARD.md` | MERGE | `business/ORGANIZATION_AND_MODULE_STANDARD.md` | รวม Organization, ownership และ Module rule |
| `business/COMPANY_BRANCH_IMPLEMENTATION_FLOW.md` | MERGE | `business/ORGANIZATION_AND_MODULE_STANDARD.md` | รวม Organization, ownership และ Module rule |
| `business/COMPANY_BRANCH_TEST_CASE.md` | MERGE | `business/ORGANIZATION_AND_MODULE_STANDARD.md` | รวม Organization, ownership และ Module rule |
| `business/COMPANY_MODULE_STANDARD.md` | MERGE | `business/ORGANIZATION_AND_MODULE_STANDARD.md` | รวม Organization, ownership และ Module rule |
| `business/COMPANY_STANDARD.md` | MERGE | `business/ORGANIZATION_AND_MODULE_STANDARD.md` | รวม Organization, ownership และ Module rule |
| `business/ORGANIZATION_STANDARD.md` | MERGE | `business/ORGANIZATION_AND_MODULE_STANDARD.md` | รวม Organization, ownership และ Module rule |
| `business/PARTNER_CHANGELOG.md` | MERGE | `business/ORGANIZATION_AND_MODULE_STANDARD.md` | รวม Organization, ownership และ Module rule |
| `business/PARTNER_CRUD_INTEGRATION.md` | MERGE | `business/ORGANIZATION_AND_MODULE_STANDARD.md` | รวม Organization, ownership และ Module rule |
| `business/PARTNER_MODULE_SPRINT_6_4.md` | MERGE | `business/ORGANIZATION_AND_MODULE_STANDARD.md` | รวม Organization, ownership และ Module rule |
| `business/PARTNER_STANDARD.md` | MERGE | `business/ORGANIZATION_AND_MODULE_STANDARD.md` | รวม Organization, ownership และ Module rule |
| `business/PARTNER_TEST_CASE.md` | MERGE | `business/ORGANIZATION_AND_MODULE_STANDARD.md` | รวม Organization, ownership และ Module rule |
| `business/PROJECT_STANDARD.md` | RETIRE | `-` | อ้างอิง Project Master/Project routing model ที่ถูกยกเลิก |
| `business/SUPPORT_WORKSPACE_STANDARD.md` | MERGE | `business/ORGANIZATION_AND_MODULE_STANDARD.md` | รวม Organization, ownership และ Module rule |
| `business/USER_STANDARD.md` | MERGE | `business/ORGANIZATION_AND_MODULE_STANDARD.md` | รวม Organization, ownership และ Module rule |
| `deployment/IMPLEMENTATION_PLAN_LAOO_SQLSERVER_PHASE1.md` | MERGE/RETIRE | `เอกสาร Baseline ที่เกี่ยวข้อง` | ไม่เก็บเป็นไฟล์แยกเพื่อลดความซ้ำซ้อน |
| `docs/business/PARTNER_MANAGEMENT_V1.md` | MERGE | `business/ORGANIZATION_AND_MODULE_STANDARD.md` | รวม Organization, ownership และ Module rule |
| `engines/THEME_ENGINE.md` | MERGE/RETIRE | `เอกสาร Baseline ที่เกี่ยวข้อง` | ไม่เก็บเป็นไฟล์แยกเพื่อลดความซ้ำซ้อน |
| `meeting/DECISIONS.md` | RETIRE | `-` | Decision history เก่ามีมติที่ถูกแทนที่; สาระล่าสุดอยู่ DECISIONS.md |
| `meeting/LAOO_PLAZA_MEETING_SUMMARY_2026-08-09.md` | MOVE-HISTORY | `history/LAOO_PLAZA_MEETING_SUMMARY_2026-08-09.md` | เก็บเป็นประวัติ ไม่ใช่ Source of Truth |
| `platform/MULTI_DATABASE_STANDARD.md` | MERGE/REPLACE | `architecture/ARCHITECTURE.md` | รวมเฉพาะ Architecture ปัจจุบัน |
| `platform/PLATFORM_ARCHITECTURE.md` | MERGE/REPLACE | `architecture/ARCHITECTURE.md` | รวมเฉพาะ Architecture ปัจจุบัน |
| `platform/PROJECT_DATABASE_ROUTING.md` | RETIRE | `-` | อ้างอิง Project Master/Project routing model ที่ถูกยกเลิก |
| `platform/VISION.md` | MERGE/REPLACE | `architecture/ARCHITECTURE.md` | รวมเฉพาะ Architecture ปัจจุบัน |
| `standards/API_ENDPOINT_STANDARD.md` | MERGE/RETIRE | `เอกสาร Baseline ที่เกี่ยวข้อง` | ไม่เก็บเป็นไฟล์แยกเพื่อลดความซ้ำซ้อน |
| `standards/COMPANY_PARTNER_BRANCH_STANDARD.md` | MERGE/RETIRE | `เอกสาร Baseline ที่เกี่ยวข้อง` | ไม่เก็บเป็นไฟล์แยกเพื่อลดความซ้ำซ้อน |
| `standards/CONNECTION_PROFILE_STANDARD.md` | MERGE/RETIRE | `เอกสาร Baseline ที่เกี่ยวข้อง` | ไม่เก็บเป็นไฟล์แยกเพื่อลดความซ้ำซ้อน |
| `standards/CRUD_FLOW_STANDARD.md` | KEEP/UPDATE | `standards/CRUD_FLOW_STANDARD.md` | เก็บไว้ใน Baseline และตรวจ/แก้จุดที่เกี่ยวข้องแล้ว |
| `standards/DATABASE_DELIVERY_STANDARD.md` | KEEP/UPDATE | `standards/DATABASE_DELIVERY_STANDARD.md` | เก็บไว้ใน Baseline และตรวจ/แก้จุดที่เกี่ยวข้องแล้ว |
| `standards/DATABASE_ROUTING_STANDARD.md` | MERGE/RETIRE | `เอกสาร Baseline ที่เกี่ยวข้อง` | ไม่เก็บเป็นไฟล์แยกเพื่อลดความซ้ำซ้อน |
| `standards/DEVELOPMENT_ENVIRONMENT_STANDARD.md` | KEEP/UPDATE | `standards/DEVELOPMENT_ENVIRONMENT_STANDARD.md` | เก็บไว้ใน Baseline และตรวจ/แก้จุดที่เกี่ยวข้องแล้ว |
| `standards/GIT_STANDARD.md` | KEEP/UPDATE | `standards/GIT_STANDARD.md` | เก็บไว้ใน Baseline และตรวจ/แก้จุดที่เกี่ยวข้องแล้ว |
| `standards/PAGINATION_UI_STANDARD.md` | KEEP/UPDATE | `standards/PAGINATION_UI_STANDARD.md` | เก็บไว้ใน Baseline และตรวจ/แก้จุดที่เกี่ยวข้องแล้ว |
| `standards/PROJECT_DATABASE_STANDARD.md` | RETIRE | `-` | อ้างอิง Project Master/Project routing model ที่ถูกยกเลิก |
| `standards/PROJECT_NAMING_STANDARD.md` | MERGE/RETIRE | `เอกสาร Baseline ที่เกี่ยวข้อง` | ไม่เก็บเป็นไฟล์แยกเพื่อลดความซ้ำซ้อน |
| `standards/PROJECT_ONBOARDING_STANDARD.md` | RETIRE | `-` | อ้างอิง Project Master/Project routing model ที่ถูกยกเลิก |
| `standards/REPOSITORY_STANDARD.md` | KEEP/UPDATE | `standards/REPOSITORY_STANDARD.md` | เก็บไว้ใน Baseline และตรวจ/แก้จุดที่เกี่ยวข้องแล้ว |
| `standards/ROUTING_STANDARD_v1.0.md` | MERGE/RETIRE | `เอกสาร Baseline ที่เกี่ยวข้อง` | ไม่เก็บเป็นไฟล์แยกเพื่อลดความซ้ำซ้อน |
| `standards/STATE_MANAGEMENT_STANDARD.md` | KEEP/UPDATE | `standards/STATE_MANAGEMENT_STANDARD.md` | เก็บไว้ใน Baseline และตรวจ/แก้จุดที่เกี่ยวข้องแล้ว |
| `standards/TYPOGRAPHY_STANDARD.md` | KEEP/UPDATE | `standards/TYPOGRAPHY_STANDARD.md` | เก็บไว้ใน Baseline และตรวจ/แก้จุดที่เกี่ยวข้องแล้ว |
| `standards/UX_UI_STANDARD.md` | KEEP/UPDATE | `standards/UX_UI_STANDARD.md` | เก็บไว้ใน Baseline และตรวจ/แก้จุดที่เกี่ยวข้องแล้ว |
| `standards/WORKSPACE_STANDARD.md` | KEEP/UPDATE | `standards/WORKSPACE_STANDARD.md` | เก็บไว้ใน Baseline และตรวจ/แก้จุดที่เกี่ยวข้องแล้ว |
| `templates/PROJECT_TEMPLATE.md` | KEEP/UPDATE | `templates/PROJECT_TEMPLATE.md` | เก็บไว้ใน Baseline และตรวจ/แก้จุดที่เกี่ยวข้องแล้ว |

รวมไฟล์ที่ตรวจ: **95 ไฟล์**
