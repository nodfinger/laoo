# LAOO_TIME Approval and Self-Service Technical Plan

เอกสารนี้แปลงมติใน ADR 0109–0114 เป็นแผนพัฒนา Database, API, Permission และ Integration สำหรับ `LAOO_TIME` โดยยังไม่อนุมัติให้เปลี่ยน Schema หรือกำหนด MenuCode/ScreenType แทนเจ้าของระบบ

## Current-state findings

- Git branch ปัจจุบันคือ `machine/time` แต่ Repository ยังไม่มี `projects/time` และ `local.machine.json`; Runbook, Center Flutter host, Center API host, migration runner และ `verify-center.ps1` รู้จักเฉพาะ Service, Meeting และ Visitor
- Core มี Person, Employee, User, User–Employee link, Role Group, Menu Permission และ Company Project Entitlement ให้ใช้งานต่อได้
- `EmployeeController` และ `CompanyPersonService` บังคับ Username, Password และ Role Group เมื่อสร้าง Company Employee และสร้าง Active Login ใน Transaction เดียว จึงยังรองรับ Employee ที่ไม่มี Login ตาม PROXY_ONLY ไม่ได้
- Core Employee มี `StartWorkDate` และ `IsActive` แต่ยังไม่มี Employment Period ที่ระบุสถานะการจ้างตามช่วงวันที่ครบถ้วน
- `TDADPermission` และ `TDADRoleGroupPermission` เก็บ ActionCode เพิ่มเติมได้ แต่หน้าจอ Permission ปัจจุบันจำกัด Flow หลักเป็น VIEW, CREATE, EDIT และ DELETE จึงยังจัดการ Action ของ Time ไม่ครบ
- Permission ปัจจุบันตรวจ Company และ Project ได้ แต่ยังไม่มีตัวประเมิน Employee Data Scope กลางสำหรับ SELF, ALL, Branch, Division, Department และ Supervisor ตามช่วงวันที่
- ยังไม่พบ Table, API หรือ Module ของ Attendance, Leave, OT, Approval Profile, Request Policy, Snapshot, Administrative Override และ Partner Delegation ใน Source ปัจจุบัน
- ตรวจ DBTDLaoo ผ่าน `laoo_api/local.json` แล้ว ไม่พบ Project `LAOO_TIME`, Module Code `TM`, Table Prefix `TDTM` หรือ Menu/Menu Group ช่วง `25–30` จึงใช้ Namespace ชุดนี้ได้โดยไม่ชนข้อมูลปัจจุบัน

## Ownership boundary

`LAOO_TIME` เป็นเจ้าของ Profile, Request Policy, Workflow, Approval, Attendance, Leave, OT, Period และ Audit ของระบบเวลา ส่วน Core เป็นเจ้าของ Person, Employee, User, Branch, Organization, Role Group และ Project/Menu infrastructure

การเปลี่ยน Root, Core หรือ Shared ต้องแยก PR ให้เครื่อง Center ตรวจและ Merge ก่อน ได้แก่การเพิ่ม Module `time` เข้า Center host, เพิ่ม role ใน Runbook/verification scripts, รองรับ Employee ที่ไม่มี Login, เพิ่ม Employment Period และทำให้ Permission UI จัดการ ActionCode ของ Time ได้

## Proposed module layout

```text
projects/time/
├─ pubspec.yaml
├─ lib/
│  ├─ time_feature.dart
│  └─ features/
├─ packages/dotnet/Laoo.Time.Module/
│  ├─ Laoo.Time.Module.csproj
│  ├─ TimeModuleExtensions.cs
│  └─ Controllers/
├─ database/migrations/
└─ test/
```

ชื่อ Project ในฐานข้อมูลใช้ `LAOO_TIME` และ Table ที่ Time เป็นเจ้าของใช้ Prefix `TDTM` เพื่อให้ Metadata Module Code เป็น `TM`

## Confirmed screen boundaries

### พนักงาน–ลงเวลาทำงาน

- เป็นหน้าจอของ `LAOO_TIME` แยกจากหน้าพนักงานส่วนกลางของ Core
- `ScreenType = 2` ตามที่พ่อกำหนด จึงให้ VIEW และ EDIT เท่านั้น ไม่มี CREATE หรือ DELETE Employee
- อ่านรายชื่อและโครงสร้างพนักงานจาก Core แต่บันทึกเฉพาะข้อมูลที่ Time เป็นเจ้าของ ได้แก่ Attendance Requirement แบบมีช่วงวันที่, Attendance Device Code Assignment, Work Schedule Group Assignment, Attendance Period Scheme Assignment และสถานะ Employee Request Access Gap
- การแก้ค่าที่มีผลย้อนหลังต้องสร้าง Version/Assignment ใหม่หรือปิดช่วงเดิมตาม ADR ห้ามเขียนทับประวัติ
- Caption ต้องอ่านจาก `TDADMainMenu.MenuName`; ใช้ `MenuCode='28001'` ตามมติวันที่ 2026-09-11

### ตั้งค่าระบบเวลา

- เป็นหน้าจอ Company setup ของ `LAOO_TIME` แยกจาก Company Setup ส่วนกลางของ Core และไม่เพิ่ม Field เฉพาะ Time ลง `TDSTCompanySetUp`
- ใช้กำหนด Approval Control Profile, Process Approval Policy, Employee Request Policy, ค่าเริ่มต้นการคำนวณ และการตรวจ Self-service Readiness
- Master ที่มีหลายรายการและวงจร CRUD ของตนเอง เช่น Shift Template, On-Behalf Reason, Time Adjustment Reason, Leave Type และ Attendance Period Scheme ยังคงเป็นหน้าจอ Master แยก ไม่ยัดรวมในหน้าตั้งค่าระบบเวลา
- Caption ต้องอ่านจาก `TDADMainMenu.MenuName`; ใช้ `MenuCode='28002'` และ `ScreenType = 2` ตามมติวันที่ 2026-09-11 เพราะเป็น Company configuration ชุดเดียวที่แก้ค่าได้แต่ไม่สร้างหรือลบ Company

### Time menu namespace

ผลตรวจฐานข้อมูลวันที่ 2026-09-11 พบว่า Menu Group `25–30` ยังไม่มีข้อมูล ขณะที่ Meeting ใช้ `21–24` และ Visitor ใช้ `31–36` พ่อจึงอนุมัติสงวนช่วงนี้ให้ `LAOO_TIME` ดังนี้:

| Menu Group | Proposed caption | Purpose |
| --- | --- | --- |
| `25` | งานเวลาและการลงเวลา | งานประจำวันและตรวจหลักฐานเวลา |
| `26` | การลาและคำขอ | Leave, Time Correction และ Approval inbox |
| `27` | กะและตารางทำงาน | Shift, Rotation และ Schedule Assignment |
| `28` | ตั้งค่าระบบเวลา | Company setup และ Master ของ Time |
| `29` | ปิดงวดและรายงานเวลา | Period review, Finalize และ Report |
| `30` | บริการตนเอง | My Attendance, My Leave และคำขอของ Employee |

สองหน้าจอที่พ่อยืนยันให้อยู่ Menu Group `28`:

| MenuCode | MenuName | ScreenType | RouteName | FeatureCode |
| --- | --- | --- | --- | --- |
| `28001` | พนักงาน–ลงเวลาทำงาน | `2` | `timeEmployeeSettings` | `TIME_EMPLOYEE_SETTINGS` |
| `28002` | กำหนดค่าระบบเวลา | `2` | `timeSystemSettings` | `TIME_SYSTEM_SETTINGS` |

รหัส `28001`, `28002` และ ScreenType `2` ได้รับอนุมัติแล้ว การ Bootstrap ต้อง Seed เป็นสถานะไม่ Active จนกว่า Route, API, Permission และ Center integration จะพร้อม

## Foundation data model

ทุก Table ต้องมี `CompanyID` ใน Unique Key และ Query boundary ที่เกี่ยวข้อง ใช้ `datetime2(3)` เก็บเวลาระบบ, `date` เก็บ Effective Date, `rowversion` สำหรับข้อมูลที่แก้ไขได้ และห้าม Hard Delete ข้อมูลธุรกรรมหรือ Audit

### Configuration and policy

| Table | Purpose | Important columns and constraints |
| --- | --- | --- |
| `TDTMApprovalProfileVersion` | Company default ของ Approval Control Profile | `ApprovalProfileVersionID`, `CompanyID`, `ProfileCode`, `EffectiveFrom`, `EffectiveTo`, audit columns; Profile เป็น `OWNER_OPERATED` หรือ `SEGREGATED_WORKFLOW`; ช่วงวันที่ห้ามซ้อน |
| `TDTMProcessApprovalPolicyVersion` | Override Profile ราย Process | `ProcessApprovalPolicyVersionID`, `CompanyID`, `ProcessCode`, `ProfileCode`, `EffectiveFrom`, `EffectiveTo`; Process เป็น `LEAVE`, `TIME`, `OT`, `ENTITLEMENT`, `PERIOD`; ช่วงของ Process เดียวกันห้ามซ้อน |
| `TDTMApprovalRouteVersion` | Route ที่ละเอียดกว่าระดับ Process | `ApprovalRouteVersionID`, `CompanyID`, `ProcessCode`, `QualifierTypeCode`, `QualifierID`, `EffectiveFrom`, `EffectiveTo`; ใช้กับ Leave Type, Time Adjustment Reason, OT Day Category หรือ Employee Group |
| `TDTMApprovalRouteStep` | Approval Step ของ SEGREGATED_WORKFLOW | `ApprovalRouteStepID`, `ApprovalRouteVersionID`, `StepOrder`, `AssigneeTypeCode`, `AssigneeRoleGroupID`, `RequiredPermissionCode`; StepOrder ไม่ซ้ำใน Route |
| `TDTMEmployeeRequestPolicyVersion` | Company default และ Override วิธีเริ่มคำขอ | `RequestPolicyVersionID`, `CompanyID`, `ProcessCode`, `PolicyCode`, `EffectiveFrom`, `EffectiveTo`; Policy เป็น `SELF_SERVICE_AND_PROXY`, `PROXY_ONLY` หรือ `SELF_SERVICE_ONLY`; ช่วงของ Process เดียวกันห้ามซ้อน |
| `TDTMOnBehalfReason` | Master เหตุผลทำแทน | `OnBehalfReasonID`, `CompanyID`, `ReasonCode`, `ReasonName`, `RequireRemark`, `RequireEvidence`, `IsActive`; Code ไม่ซ้ำใน Company และรายการที่เคยใช้ห้ามลบ |

### Employee time settings

| Table | Purpose | Important columns and constraints |
| --- | --- | --- |
| `TDTMAttendanceRequirement` | ประวัติว่าพนักงานต้องลงเวลาหรือได้รับยกเว้น | `AttendanceRequirementID`, `CompanyID`, `EmployeeID`, `RequirementCode`, `EffectiveFrom`, `EffectiveTo`, `Reason`, audit columns; ช่วงของ Employee เดียวกันห้ามซ้อน |
| `TDTMAttendanceDeviceCodeAssignment` | ประวัติรหัสที่เครื่องของพนักงาน | `DeviceCodeAssignmentID`, `CompanyID`, `EmployeeID`, `DeviceCode`, `EffectiveFromDateTime`, `EffectiveToDateTime`, audit columns; DeviceCode ต้องไม่ซ้ำภายใน Company ณ เวลาเดียวกันและ Employee มีรหัสที่มีผลได้หนึ่งค่า |
| `TDTMEmployeeTimeSettingAudit` | Log การแก้ค่าจากหน้าพนักงาน–ลงเวลาทำงาน | `EmployeeTimeSettingAuditID`, `CompanyID`, `EmployeeID`, `SettingTypeCode`, `BeforeJson`, `AfterJson`, `Reason`, `ActorUserID`, `OccurredDate`; Append-only |

Company default ใช้ `ProcessCode='DEFAULT'`; ค่า Override ที่ตรง Process มีลำดับเหนือ Default และ Policy resolver ต้องคืน Version ID ที่ถูกเลือกเสมอ

### Scope, delegation, and access readiness

| Table | Purpose | Important columns and constraints |
| --- | --- | --- |
| `TDTMDelegatedTimeAdministration` | Company มอบสิทธิ์ให้ Partner Admin | `DelegationID`, `CompanyID`, `PartnerID`, `PartnerUserID`, `EffectiveFrom`, `EffectiveTo`, `StatusCode`, `Reason`, audit columns; ต้องตรวจ Company เป็นของ Partner |
| `TDTMDelegatedTimePermission` | Action ที่ Delegation ทำได้ | `DelegationID`, `ActionCode`; Unique ต่อ Delegation/Action |
| `TDTMEmployeeDataScopeGrant` | Employee Data Scope ของ User, Role Group หรือ Delegation | มี `UserID`, `RoleGroupID`, `DelegationID` โดยต้องมีค่าเพียงหนึ่งช่อง; `ScopeTypeCode` เป็น `SELF`, `ALL`, `BRANCH`, `DIVISION`, `DEPARTMENT` หรือ `SUPERVISOR`; `ScopeReferenceID`, `EffectiveFrom`, `EffectiveTo` |
| `TDTMEmployeeRequestAccessGap` | พนักงานใน SELF_SERVICE_ONLY ที่ Login ไม่พร้อม | `AccessGapID`, `CompanyID`, `EmployeeID`, `ProcessCode`, `DetectedDate`, `StatusCode`, `ResolvedDate`, `ResolvedByUserID`; Active Gap ไม่ซ้ำต่อ Employee/Process |

`SELF` ใช้ Employee ที่ผูกกับ User, `ALL` ไม่ต้องมี ScopeReferenceID และ Scope ประเภทอื่นต้องอ้างข้อมูล Core ที่อยู่ Company เดียวกัน ผู้ประเมิน Scope ต้องใช้ Organization Assignment ที่มีผลใน Work Date เมื่อ Core พร้อม; ระหว่างที่ Core ยังไม่มีประวัติดังกล่าว ห้ามอ้าง Division/Department ปัจจุบันเพื่อแก้ผลย้อนหลังแบบเงียบ ๆ

### Request, snapshot, decision, and audit

| Table | Purpose | Important columns and constraints |
| --- | --- | --- |
| `TDTMRequest` | Envelope กลางของคำขอจาก Employee หรือ Proxy | `RequestID`, `CompanyID`, `ProcessCode`, `SubjectEmployeeID`, `InitiationModeCode`, `ActorUserID`, `OnBehalfReasonID`, `StatusCode`, `SubmittedDate`, audit columns; Initiation Mode เป็น `SELF` หรือ `PROXY` |
| `TDTMWorkflowSnapshot` | Snapshot Profile/Route เมื่อ Submit | `WorkflowSnapshotID`, `RequestID`, Version IDs ที่ resolve แล้ว, `SnapshotJson`, `SnapshotHash`, `CreatedDate`; หนึ่งรายการต่อ Request และห้าม Update/Delete |
| `TDTMRequestPolicySnapshot` | Snapshot Request Policy เมื่อ Submit | `RequestPolicySnapshotID`, `RequestID`, `RequestPolicyVersionID`, `PolicyCode`, `SnapshotJson`, `SnapshotHash`; หนึ่งรายการต่อ Request และห้าม Update/Delete |
| `TDTMApprovalDecision` | การตัดสินแบบ Append-only | `ApprovalDecisionID`, `RequestID`, `StepOrder`, `DecisionCode`, `ActorUserID`, `ActorEmployeeID`, `IsSelfApproved`, `Reason`, `EvidenceReference`, `DecisionDate`; ห้าม Update/Delete |
| `TDTMRequestEditLog` | ค่าก่อน–หลังเมื่อผู้มีสิทธิ์แก้คำขอ | `RequestEditLogID`, `RequestID`, `FieldPath`, `BeforeValue`, `AfterValue`, `Reason`, `ActorUserID`, `ChangedDate`; Append-only |
| `TDTMAdministrativeOverride` | หลักฐาน Override | `AdministrativeOverrideID`, `CompanyID`, `OverrideTypeCode`, `TargetTypeCode`, `TargetID`, `BeforeJson`, `AfterJson`, `Reason`, `ActorUserID`, `OccurredDate`, `CorrelationID`; Append-only |
| `TDTMWorkflowMigration` | ย้าย Pending Request ไป Policy ใหม่ | `WorkflowMigrationID`, `CompanyID`, `PreviewJson`, `Reason`, `ActorUserID`, `CreatedDate`; Detail เก็บ Request และ Snapshot ก่อน–หลัง |
| `TDTMNotificationDelivery` | Outbox และ Delivery Status | `NotificationDeliveryID`, `CompanyID`, `RequestID`, `RecipientEmployeeID`, `ChannelCode`, `StatusCode`, `AttemptCount`, `LastAttemptDate`, `LastError`; Failure ไม่ย้อนกลับ Request transaction |

Leave Request, Leave Cancellation, Time Correction และ Reconfirmation มี Detail Table ของตนเองและอ้าง `RequestID` แบบหนึ่งต่อหนึ่ง ส่วน OT, Time Adjustment, Entitlement และ Period เป็น Administrative Action และไม่สร้าง Proxy Submission ปลอม

## Existing permission infrastructure to reuse

ใช้ `TDADPermission`, `TDADRoleGroupPermission`, `TDADUserPermission` และ Company Admin baseline เดิม โดย Seed Action ต่อ Menu ของ Time ดังนี้:

- `SUBMIT`, `CANCEL`
- `ACT_ON_BEHALF`
- `APPROVE`, `SELF_APPROVE`
- `FINALIZE`, `REOPEN`
- `MANAGE_APPROVAL_PROFILE`

ทุก API ต้องผ่าน 4 ด่านตามลำดับ: Authentication/Company ownership → Project entitlement → Action Permission → Employee Data Scope จากนั้นจึงตรวจ Approval Control Profile และ Business Invariant Company Admin ข้าม Role Permission ได้ตาม Baseline แต่ห้ามข้าม Profile โดยเงียบ; การเปลี่ยน Profile ต้องสร้าง Administrative Override

Employee Self-Service Role เป็น Role Group มาตรฐานของ `LAOO_TIME` มี Own Scope และให้เฉพาะ VIEW/SUBMIT/CANCEL ตาม Process Policy ห้ามให้ ACT_ON_BEHALF, APPROVE, SELF_APPROVE, FINALIZE, REOPEN หรือ MANAGE_APPROVAL_PROFILE โดยปริยาย

## API boundary

### Configuration

- `GET /api/time/approval-control/effective?date=` คืน Company default, Process override และ Version IDs
- `POST /api/time/approval-control/versions` สร้าง Profile Version แบบเริ่มทันทีหรืออนาคต
- `POST /api/time/approval-control/administrative-override` เปลี่ยน Profile พร้อมเหตุผลและ Immutable Log
- `GET|POST|PUT /api/time/request-policies` จัดการ Employee Request Policy Versions
- `POST /api/time/request-policies/self-service-readiness` ตรวจพนักงานใน Scope ที่ไม่มี Active Login ก่อนเปิด SELF_SERVICE_ONLY
- `GET|POST|PUT /api/time/on-behalf-reasons` จัดการ Master เหตุผลทำแทน
- `GET|POST|PUT /api/time/delegations` จัดการ Partner Delegation, Action และ Scope แบบ Effective-dated
- `GET /api/time/employee-settings` อ่าน Employee จาก Core ร่วมกับค่าของ Time แบบ Filter/Pagination
- `GET /api/time/employee-settings/{employeeId}` อ่าน Version/Assignment ที่มีผลและประวัติ
- `PUT /api/time/employee-settings/{employeeId}` บันทึกค่าที่ Time เป็นเจ้าของโดยใช้ EDIT, Employee Data Scope และ RowVersion

### Request and approval

- Domain API สร้าง `TDTMRequest` และ Detail ใน Transaction เดียว เช่น `POST /api/time/time-corrections`
- `POST /api/time/requests/{requestId}/approve` ใช้ APPROVE; ถ้า Actor เป็น Subject ต้องมี SELF_APPROVE และ Profile เป็น OWNER_OPERATED
- `POST /api/time/requests/save-and-approve` ใช้กับ OWNER_OPERATED และต้องสร้าง Request, Snapshot, Decision และ Business Result ใน Transaction เดียว
- `POST /api/time/requests/{requestId}/cancel` ใช้ CANCEL และกติกาจาก Request Policy Snapshot
- `POST /api/time/workflow-migrations/preview` และ `/apply` แยก Preview ออกจากการยืนยัน Migration

API ต้องอ่าน CompanyID, PartnerID, UserID และ EmployeeID ของผู้ Login จาก Claims/ฐานข้อมูล ห้ามรับ Scope จาก Client เป็นข้อสรุป และทุก Write ใช้ Idempotency Key หรือ Unique Business Key เพื่อป้องกันการกดซ้ำ

## Transaction rules

### Self-service submission

1. Resolve Employee จาก Active User–Employee link และตรวจสถานะการจ้างในวันที่คำขอมีผล
2. Resolve Employee Request Policy; ปฏิเสธ Employee submission เมื่อเป็น PROXY_ONLY
3. ตรวจ SUBMIT และ Own Scope
4. Resolve Approval Profile/Route และสร้าง Snapshot ทั้งสองชนิด
5. สร้าง Request และ Domain Detail ใน Transaction เดียว

### Proxy save and approve

1. ตรวจ ACT_ON_BEHALF, Employee Data Scope, Policy และ On-Behalf Reason/Remark/Evidence
2. ตรวจ APPROVE และ SELF_APPROVE เมื่อ Actor เป็น Subject
3. Lock Policy Version และ Business aggregate ที่เกี่ยวข้อง
4. สร้าง Request, Detail, Snapshots, Approval Decision และผลธุรกิจใน Transaction เดียว
5. สร้าง Notification Delivery สถานะ `PENDING` ใน Transaction เดียว แล้วส่งหลัง Commit; การส่งล้มเหลวเปลี่ยนเป็น `FAILED` โดยไม่ Rollback ผลธุรกิจ

### Administrative override

1. ตรวจ Company Admin หรือ MANAGE_APPROVAL_PROFILE ตาม Flow ปกติ
2. บังคับ Reason และบันทึก Before/After
3. สร้าง Profile Version ใหม่ ห้ามแก้ Version เดิม
4. Commit Version และ Immutable Log พร้อม Correlation ID เดียวกัน
5. Pending Request ใช้ Snapshot เดิมจนกว่าจะผ่าน Workflow Migration

## Business invariants enforced in the database/service boundary

- ห้าม Update/Delete Attendance Event ต้นฉบับ
- Available Leave Balance ห้ามติดลบและเวลาห้ามถูกนับซ้ำ
- OWNER_OPERATED ไม่ทำให้ข้าม Unresolved Attendance Result, Period Assignment Gap หรือ Reconfirmation Pending
- FINALIZE ต้อง Lock Attendance Period และยืนยันว่า Branch Review กับ Unresolved Result เป็นศูนย์ใน Transaction เดียว
- REOPEN, SELF_APPROVE และการแก้ผลย้อนหลังต้องมี Permission, Reason และ Evidence ตาม Elevated Approval Requirement
- Partner Admin ที่ไม่มี Delegation ซึ่งมีผลต้องได้ `403` ก่อนอ่านข้อมูล Employee
- Policy/Profile Version ใหม่ไม่เปลี่ยน Pending Request โดยอัตโนมัติ

## Required automated tests

### Policy and identity

- Employee ส่งคำขอได้เมื่อ Policy, Active Login, Employee link, Own Scope และสถานะการจ้างพร้อม
- PROXY_ONLY ปฏิเสธ Employee submission
- SELF_SERVICE_ONLY setup ถูกปฏิเสธพร้อมรายการ Employee ที่ Login ไม่พร้อม
- Login ถูกปิดหลัง Policy มีผลแล้วสร้าง Employee Request Access Gap

### Approval

- OWNER_OPERATED save-and-approve สร้าง Request, Snapshot, Decision และ Business Result ครบหรือ Rollback ทั้งหมด
- SELF_APPROVE ใช้ได้เฉพาะ Permission ที่กำหนดและติดธง `IsSelfApproved`
- SEGREGATED_WORKFLOW ปฏิเสธ Self-approval จนกว่า Company Admin สร้าง Profile Version ผ่าน Administrative Override
- Profile/Policy ใหม่ไม่เปลี่ยน Pending Request; Workflow Migration ต้องมี Preview และ Audit

### Scope and reliability

- Company และ Employee Data Scope ป้องกันการอ่านหรือแก้ข้อมูลข้าม Company/Employee
- Partner Admin ไม่มี Delegation ถูกปฏิเสธ และ Delegation หมดอายุถูกปฏิเสธ
- Notification Failure เก็บ Delivery Status โดย Request transaction ยังสำเร็จ
- OWNER_OPERATED ไม่สามารถ Finalize Period ที่มี Unresolved Result
- Request ซ้ำด้วย Idempotency Key เดิมไม่สร้างข้อมูลซ้ำ

## Delivery sequence

1. **Center bootstrap PR**: เพิ่มบทบาท `time`, `projects/time`, Center Flutter/API composition, migration runner และ `verify-center.ps1 -Module time`
2. **Core identity PR**: แยกการสร้าง Employee ออกจากการสร้าง Login และเพิ่ม API เปิด/ปิด Login โดยคง Person/User invariant
3. **Core employment PR**: เพิ่ม Effective Employment Period และ Organization Assignment ที่ Time อ่านได้
4. **Time foundation migration**: สร้าง Configuration, Scope, Request, Snapshot, Decision, Audit, Delegation และ Notification tables หลังพ่ออนุมัติ Schema
5. **Time foundation API**: Implement policy resolver, scope evaluator, profile resolver, atomic approval service และ tests
6. **First vertical slice**: Time Correction Request + Proxy save-and-approve เพราะทดสอบ Self-service, Proxy, Snapshot, Approval และ Time Adjustment ได้ครบใน Flow เดียว
7. **Leave, OT, Entitlement, Period**: เพิ่ม Domain aggregate ตาม ADR เดิมโดยใช้ Foundation ชุดเดียวกัน
8. **Flutter UI**: เริ่มหลังได้รับ MenuCode และ ScreenType จาก `TDADMainMenu` พร้อมอ่าน UX/UI standards ตามประเภทหน้าจอ

## Decisions required before schema migration

- `28001`, `28002`, ScreenType `2` และ Menu Group `25–30` ได้รับอนุมัติแล้วเมื่อวันที่ 2026-09-11
- เครื่อง Center ต้องรับรองการเพิ่ม role `time` และ Root/Shared integration เพราะเครื่อง Time แก้และ Merge Root โดยตรงไม่ได้
- ตรวจ Schema จริงของ DBTDLaoo แล้วว่า Module Code `TM`, Prefix `TDTM` และ Menu Group `25–30` ไม่ชนของเดิม ณ วันที่ 2026-09-11
- Schema ทั้งหมดข้างต้นเป็นข้อเสนอและต้องได้รับอนุมัติตาม Database Write Approval ก่อนสร้าง Migration
