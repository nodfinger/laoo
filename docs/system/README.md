# ดัชนีข้อกำหนด Function รายระบบ

ค้นด้วย `MenuCode` ก่อน แล้วเปิดไฟล์ระบบที่ลิงก์ไว้ ข้อความในหัวข้อ “พฤติกรรมที่พบในโค้ด” เป็นหลักฐานการทำงาน ไม่ใช่ข้อกำหนดใหม่

ดูขอบเขตเครื่องและเจ้าของข้อมูลได้ที่ [Project Ownership Registry](OWNERSHIP.md). หลัง Bootstrap แล้ว เครื่องระบบแก้โค้ด/API/ตารางของตนเองใต้ `projects/<project>` ได้ตามกติกา Green; งานที่กระทบ Core Contract ให้แยกเป็น Core Impact PR.

## AI ส่วนกลาง

ค้น Agent และ CapabilityCode ได้ที่ [ดัชนี AI](ai/README.md)

## ระบบ

| ระบบ | จำนวน MenuCode ที่พบ | ไฟล์ |
|---|---:|---|
| ระบบอนุมัติ | 2 | [approval.md](approval.md) |
| Booking | 10 | [booking.md](booking.md) |
| ระบบส่วนกลาง | 20 | [core.md](core.md) |
| Digital Checklist | 0 | [digital_checklist.md](digital_checklist.md) |
| Document Control | 8 | [document_control.md](document_control.md) |
| Evaluation | 1 | [evaluation.md](evaluation.md) |
| ระบบค่าใช้จ่าย | 3 | [expense.md](expense.md) |
| Five S | 10 | [five_s.md](five_s.md) |
| Gate Pass | 8 | [gate_pass.md](gate_pass.md) |
| ระบบ Intranet | 6 | [intranet.md](intranet.md) |
| Knowledge | 8 | [knowledge.md](knowledge.md) |
| ระบบกฎหมาย | 3 | [legal.md](legal.md) |
| Market | 0 | [market.md](market.md) |
| ระบบห้องประชุม | 47 | [meeting.md](meeting.md) |
| Memo | 9 | [memo.md](memo.md) |
| Patrol | 12 | [patrol.md](patrol.md) |
| Pet | 10 | [pet.md](pet.md) |
| Pos | 7 | [pos.md](pos.md) |
| Project | 5 | [project.md](project.md) |
| Provider | 9 | [provider.md](provider.md) |
| ระบบจัดซื้อ | 1 | [purchasing.md](purchasing.md) |
| Rental | 10 | [rental.md](rental.md) |
| ระบบขายและเอกสารการค้า | 13 | [sales.md](sales.md) |
| School | 1 | [school.md](school.md) |
| School Food | 12 | [school_food.md](school_food.md) |
| Service | 27 | [service.md](service.md) |
| Site | 8 | [site.md](site.md) |
| Sport | 11 | [sport.md](sport.md) |
| ระบบบริหารสต๊อก | 11 | [stock.md](stock.md) |
| Survey | 7 | [survey.md](survey.md) |
| Time | 33 | [time.md](time.md) |
| Training | 6 | [training.md](training.md) |
| Visitor | 23 | [visitor.md](visitor.md) |
| Vote | 5 | [vote.md](vote.md) |

## MenuCode → ไฟล์หลัก

| MenuCode | ระบบ | Route | สถานะหลักฐาน |
|---|---|---|---|
| `01001` | [ระบบห้องประชุม](meeting.md) | `partner` | พบ Route |
| `01003` | [service](service.md) | `branch` | พบ Route |
| `01004` | [ระบบห้องประชุม](meeting.md) | `technicalInfo` | พบ Route |
| `01005` | [service](service.md) | `globalSettings` | พบ Route |
| `01006` | [service](service.md) | `globalPermissionSettings` | พบ Route |
| `01007` | [ระบบส่วนกลาง](core.md) | `laooMenuManagement` | พบ Route |
| `01008` | [ระบบส่วนกลาง](core.md) | `qrCodeGenerator` | พบ Route |
| `02001` | [ระบบห้องประชุม](meeting.md) | `laooUser` | พบ Route |
| `02002` | [ระบบห้องประชุม](meeting.md) | `partnerUser` | พบ Route |
| `02003` | [ระบบห้องประชุม](meeting.md) | `companyUser` | พบ Route |
| `03001` | [ระบบห้องประชุม](meeting.md) | `module` | พบ Route |
| `03002` | [ระบบห้องประชุม](meeting.md) | `customerModule` | พบ Route |
| `03003` | [ระบบห้องประชุม](meeting.md) | `permission` | พบ Route |
| `04001` | [ระบบห้องประชุม](meeting.md) | `audit` | พบ Route |
| `04002` | [ระบบห้องประชุม](meeting.md) | `loginLog` | พบ Route |
| `05001` | [ระบบห้องประชุม](meeting.md) | `companySetup` | พบ Route |
| `05002` | [ระบบห้องประชุม](meeting.md) | `masterData` | พบ Route |
| `05003` | [service](service.md) | `companySetupAdditional` | พบ Route |
| `05004` | [ระบบส่วนกลาง](core.md) | `companyDocumentNumberFormat` | พบ Route |
| `06001` | [ระบบห้องประชุม](meeting.md) | `partnerCompanies` | พบ Route |
| `06002` | [ระบบห้องประชุม](meeting.md) | `partnerBranches` | พบ Route |
| `07001` | [ระบบห้องประชุม](meeting.md) | `partnerUsers` | พบ Route |
| `08001` | [ระบบบริหารสต๊อก](stock.md) | `companyProducts` | พบ Route |
| `08002` | [ระบบบริหารสต๊อก](stock.md) | `/inventory/items` | พบ Route |
| `08003` | [ระบบบริหารสต๊อก](stock.md) | `/inventory/usage` | พบ Route |
| `08004` | [ระบบบริหารสต๊อก](stock.md) | `/inventory/warehouses` | พบ Route |
| `08005` | [ระบบบริหารสต๊อก](stock.md) | `/inventory/stock-receipts` | พบ Route |
| `08006` | [ระบบบริหารสต๊อก](stock.md) | `/inventory/item-instances` | พบ Route |
| `08007` | [ระบบบริหารสต๊อก](stock.md) | `companyVendors` | พบ Route |
| `08008` | [ระบบบริหารสต๊อก](stock.md) | `ไม่พบ` | พบรหัสในโมดูล |
| `08009` | [ระบบบริหารสต๊อก](stock.md) | `ไม่พบ` | พบรหัสในโมดูล |
| `08010` | [ระบบบริหารสต๊อก](stock.md) | `ไม่พบ` | พบรหัสในโมดูล |
| `08011` | [ระบบบริหารสต๊อก](stock.md) | `ไม่พบ` | พบรหัสในโมดูล |
| `09001` | [ระบบขายและเอกสารการค้า](sales.md) | `/company/customers` | พบ Route |
| `09002` | [ระบบขายและเอกสารการค้า](sales.md) | `companyBranches` | พบ Route |
| `09003` | [ระบบขายและเอกสารการค้า](sales.md) | `/company/quotations` | พบ Route |
| `09004` | [ระบบขายและเอกสารการค้า](sales.md) | `/company/pre-orders` | พบ Route |
| `09005` | [ระบบขายและเอกสารการค้า](sales.md) | `/company/temporary-receipts` | พบ Route |
| `09006` | [ระบบขายและเอกสารการค้า](sales.md) | `/company/delivery-notes` | พบ Route |
| `09007` | [ระบบขายและเอกสารการค้า](sales.md) | `/company/tax-invoices` | พบ Route |
| `09008` | [ระบบขายและเอกสารการค้า](sales.md) | `/company/vat-settings` | พบ Route |
| `09009` | [ระบบขายและเอกสารการค้า](sales.md) | `/company/purchase-deliveries` | พบ Route |
| `09010` | [ระบบขายและเอกสารการค้า](sales.md) | `/company/purchase-tax-invoices` | พบ Route |
| `09019` | [ระบบขายและเอกสารการค้า](sales.md) | `/company/sales-tax-report` | พบ Route |
| `09020` | [ระบบขายและเอกสารการค้า](sales.md) | `/company/purchase-tax-report` | พบ Route |
| `10001` | [ระบบห้องประชุม](meeting.md) | `companyEmployees` | พบ Route |
| `10002` | [ระบบห้องประชุม](meeting.md) | `companyUsers` | พบ Route |
| `10003` | [ระบบห้องประชุม](meeting.md) | `companyRoleGroups` | พบ Route |
| `10004` | [ระบบห้องประชุม](meeting.md) | `companyMenuPermissions` | พบ Route |
| `10005` | [ระบบห้องประชุม](meeting.md) | `organizationStructure` | พบ Route |
| `10006` | [service](service.md) | `companySubPermissions` | พบ Route |
| `10007` | [ระบบห้องประชุม](meeting.md) | `companySupervisors` | พบ Route |
| `10008` | [ระบบส่วนกลาง](core.md) | `companyAiCapabilities` | พบ Route |
| `10009` | [ระบบส่วนกลาง](core.md) | `/company/position-levels` | พบ Route |
| `10010` | [ระบบส่วนกลาง](core.md) | `/company/menu-data-access` | พบ Route |
| `10011` | [ระบบส่วนกลาง](core.md) | `/company/approval-pattern` | พบ Route |
| `11001` | [ระบบห้องประชุม](meeting.md) | `partnerEmployees` | พบ Route |
| `11002` | [ระบบห้องประชุม](meeting.md) | `partnerUsers` | พบ Route |
| `11003` | [ระบบห้องประชุม](meeting.md) | `partnerRoleGroups` | พบ Route |
| `11004` | [ระบบห้องประชุม](meeting.md) | `partnerMenuPermissions` | พบ Route |
| `11005` | [ระบบห้องประชุม](meeting.md) | `organizationStructure` | พบ Route |
| `12001` | [ระบบห้องประชุม](meeting.md) | `customerEmployees` | พบ Route |
| `12002` | [ระบบห้องประชุม](meeting.md) | `laooUsers` | พบ Route |
| `12005` | [service](service.md) | `organizationStructure` | พบ Route |
| `13001` | [ระบบส่วนกลาง](core.md) | `companyBranches` | พบ Route |
| `13002` | [ระบบส่วนกลาง](core.md) | `companyPersons` | พบ Route |
| `14001` | [ระบบส่วนกลาง](core.md) | `assetLocations` | พบ Route |
| `14002` | [service](service.md) | `/asset/items` | พบ Route |
| `14003` | [service](service.md) | `/asset/customers` | พบ Route |
| `14005` | [service](service.md) | `/service/customers` | พบ Route |
| `14006` | [service](service.md) | `/service/residents` | พบ Route |
| `15001` | [service](service.md) | `/cm/tickets` | พบ Route |
| `15002` | [service](service.md) | `/cm/qr-portal` | พบ Route |
| `16001` | [service](service.md) | `/pm/plans` | พบ Route |
| `16002` | [service](service.md) | `/pm/checklists` | พบ Route |
| `16003` | [service](service.md) | `/pm/calendar` | พบ Route |
| `17001` | [service](service.md) | `/jobs/dispatch` | พบ Route |
| `17002` | [service](service.md) | `/jobs/work-orders` | พบ Route |
| `17003` | [service](service.md) | `/jobs/closeout` | พบ Route |
| `18001` | [service](service.md) | `/company/service-settings` | พบ Route |
| `18002` | [service](service.md) | `/company/service-request-subjects` | พบ Route |
| `19001` | [service](service.md) | `/reports/dashboard` | พบ Route |
| `19002` | [service](service.md) | `/reports/history` | พบ Route |
| `20001` | [service](service.md) | `/portal/request` | พบ Route |
| `20002` | [service](service.md) | `/portal/tracking` | พบ Route |
| `20003` | [service](service.md) | `/portal/history` | พบ Route |
| `20004` | [service](service.md) | `/portal/pm-schedule` | พบ Route |
| `20006` | [service](service.md) | `/portal/complaint` | พบ Route |
| `21001` | [ระบบห้องประชุม](meeting.md) | `/company/meeting-room-bookings` | พบรหัสในโมดูล |
| `21002` | [ระบบห้องประชุม](meeting.md) | `/company/meeting-room-calendar` | พบรหัสในโมดูล |
| `21003` | [ระบบห้องประชุม](meeting.md) | `/company/meeting-invitations` | พบรหัสในโมดูล |
| `21004` | [ระบบห้องประชุม](meeting.md) | `/company/meeting-room-approvals` | พบรหัสในโมดูล |
| `21005` | [ระบบห้องประชุม](meeting.md) | `/company/meeting-food-plans` | พบรหัสในโมดูล |
| `21006` | [ระบบห้องประชุม](meeting.md) | `/company/meeting-food-order-summary` | พบรหัสในโมดูล |
| `21007` | [ระบบห้องประชุม](meeting.md) | `/company/meeting-food-distribution` | พบรหัสในโมดูล |
| `22001` | [ระบบห้องประชุม](meeting.md) | `/company/room-check-in` | พบรหัสในโมดูล |
| `22002` | [ระบบห้องประชุม](meeting.md) | `/company/room-support-tasks` | พบรหัสในโมดูล |
| `22003` | [ระบบห้องประชุม](meeting.md) | `/company/room-issues` | พบรหัสในโมดูล |
| `22004` | [ระบบห้องประชุม](meeting.md) | `/company/meeting-attendance` | พบรหัสในโมดูล |
| `22005` | [ระบบห้องประชุม](meeting.md) | `/company/meeting-equipment-requests` | พบรหัสในโมดูล |
| `22006` | [ระบบห้องประชุม](meeting.md) | `/company/meeting-system-settings` | พบรหัสในโมดูล |
| `23001` | [ระบบห้องประชุม](meeting.md) | `/company/meeting-buildings` | พบรหัสในโมดูล |
| `23002` | [ระบบห้องประชุม](meeting.md) | `/company/meeting-rooms` | พบรหัสในโมดูล |
| `23004` | [ระบบห้องประชุม](meeting.md) | `/company/meeting-foods` | พบรหัสในโมดูล |
| `24001` | [ระบบห้องประชุม](meeting.md) | `/company/reports/meeting-room-utilization` | พบรหัสในโมดูล |
| `24002` | [ระบบห้องประชุม](meeting.md) | `/company/reports/meeting-no-show` | พบรหัสในโมดูล |
| `24003` | [ระบบห้องประชุม](meeting.md) | `/company/reports/meeting-feedback` | พบรหัสในโมดูล |
| `25001` | [time](time.md) | `/company/time-attendance-events` | พบ Route |
| `25002` | [time](time.md) | `/company/time-attendance-results` | พบ Route |
| `25003` | [time](time.md) | `/company/time-payroll-export` | พบ Route |
| `25004` | [time](time.md) | `/company/time-payroll-export-history` | พบ Route |
| `26001` | [time](time.md) | `/company/time-corrections` | พบ Route |
| `26002` | [time](time.md) | `/company/time-approval-inbox` | พบ Route |
| `26003` | [time](time.md) | `/company/time-leave-requests` | พบ Route |
| `26004` | [time](time.md) | `/company/time-leave-approval-inbox` | พบ Route |
| `27001` | [time](time.md) | `/company/time-shift-templates` | พบ Route |
| `27002` | [time](time.md) | `/company/time-schedule-groups` | พบ Route |
| `27003` | [time](time.md) | `/company/time-rotation-patterns` | พบ Route |
| `27004` | [time](time.md) | `/company/time-employee-schedules` | พบ Route |
| `28001` | [time](time.md) | `/company/time-employee-settings` | พบ Route |
| `28002` | [time](time.md) | `/company/time-system-settings` | พบ Route |
| `28003` | [time](time.md) | `/company/time-on-behalf-reasons` | พบ Route |
| `28004` | [time](time.md) | `/company/time-adjustment-reasons` | พบ Route |
| `28005` | [time](time.md) | `/company/time-holiday-calendars` | พบ Route |
| `28006` | [time](time.md) | `/company/time-holiday-dates` | พบ Route |
| `28007` | [time](time.md) | `/company/time-branch-holiday-calendars` | พบ Route |
| `28008` | [time](time.md) | `/company/time-branch-holiday-exceptions` | พบ Route |
| `28009` | [time](time.md) | `/company/time-leave-types` | พบ Route |
| `28010` | [time](time.md) | `/company/time-leave-entitlement-policies` | พบ Route |
| `28011` | [time](time.md) | `/company/time-leave-balances` | พบ Route |
| `28012` | [time](time.md) | `/company/time-leave-report` | พบ Route |
| `28013` | [time](time.md) | `/company/time-payroll-export-profiles` | พบ Route |
| `29001` | [time](time.md) | `/company/time-attendance-period-schemes` | พบ Route |
| `29002` | [time](time.md) | `/company/time-attendance-period-assignments` | พบ Route |
| `29003` | [time](time.md) | `/company/time-attendance-periods` | พบ Route |
| `29004` | [time](time.md) | `/company/time-attendance-summary-report` | พบ Route |
| `30001` | [time](time.md) | `/company/my-time-corrections` | พบ Route |
| `30002` | [time](time.md) | `/company/my-attendance-history` | พบ Route |
| `30003` | [time](time.md) | `/company/my-leave-requests` | พบ Route |
| `30004` | [time](time.md) | `/company/my-leave-balance` | พบ Route |
| `31001` | [visitor](visitor.md) | `/visitor/gate-dashboard` | พบ Route |
| `31002` | [visitor](visitor.md) | `/visitor/check-in` | พบ Route |
| `31003` | [visitor](visitor.md) | `/visitor/inside` | พบ Route |
| `31004` | [visitor](visitor.md) | `/visitor/check-out` | พบ Route |
| `31005` | [visitor](visitor.md) | `/visitor/history` | พบ Route |
| `32001` | [visitor](visitor.md) | `/visitor/pre-register` | พบ Route |
| `32002` | [visitor](visitor.md) | `/visitor/approval-status` | พบ Route |
| `32003` | [visitor](visitor.md) | `/visitor/host-confirm` | พบ Route |
| `33001` | [visitor](visitor.md) | `/visitor/site-zone-gate` | พบ Route |
| `33002` | [visitor](visitor.md) | `/visitor/residential` | พบ Route |
| `33003` | [visitor](visitor.md) | `/visitor/corporate` | พบ Route |
| `33004` | [visitor](visitor.md) | `/visitor/common-master` | พบ Route |
| `34001` | [visitor](visitor.md) | `/visitor/admin-dashboard` | พบ Route |
| `34002` | [visitor](visitor.md) | `/visitor/reports` | พบ Route |
| `34003` | [visitor](visitor.md) | `/visitor/exceptions` | พบ Route |
| `34004` | [visitor](visitor.md) | `/visitor/timeline` | พบ Route |
| `35001` | [visitor](visitor.md) | `/visitor/notifications` | พบ Route |
| `35002` | [visitor](visitor.md) | `/visitor/notification-history` | พบ Route |
| `35003` | [visitor](visitor.md) | `/visitor/notification-channels` | พบ Route |
| `36001` | [visitor](visitor.md) | `/visitor/audit` | พบ Route |
| `36002` | [visitor](visitor.md) | `/visitor/watchlist` | พบ Route |
| `36003` | [visitor](visitor.md) | `/visitor/retention-policy` | พบ Route |
| `36004` | [visitor](visitor.md) | `/visitor/system-settings` | พบ Route |
| `37001` | [training](training.md) | `/company/training-types` | พบ Route |
| `37002` | [training](training.md) | `/company/training-instructors` | พบ Route |
| `37003` | [training](training.md) | `/company/training-test-templates` | พบ Route |
| `37004` | [training](training.md) | `/company/training-settings` | พบ Route |
| `37005` | [training](training.md) | `/company/training-results` | พบ Route |
| `37006` | [training](training.md) | `/company/my-training` | พบ Route |
| `38001` | [gate_pass](gate_pass.md) | `/company/gate-pass-settings` | พบ Route |
| `38002` | [gate_pass](gate_pass.md) | `/company/gate-pass-purposes` | พบ Route |
| `38003` | [gate_pass](gate_pass.md) | `/company/gate-passes` | พบ Route |
| `38004` | [gate_pass](gate_pass.md) | `/company/gate-pass-approvals` | พบ Route |
| `38005` | [gate_pass](gate_pass.md) | `/company/gate-pass-exit-check` | พบ Route |
| `38006` | [gate_pass](gate_pass.md) | `/company/gate-pass-returns` | พบ Route |
| `38007` | [gate_pass](gate_pass.md) | `/company/my-gate-passes` | พบ Route |
| `38008` | [gate_pass](gate_pass.md) | `/company/gate-pass-reports` | พบ Route |
| `39001` | [five_s](five_s.md) | `/company/five-s/inspection-areas` | พบ Route |
| `39002` | [five_s](five_s.md) | `/company/five-s/templates` | พบ Route |
| `39003` | [five_s](five_s.md) | `/company/five-s/inspection-teams` | พบ Route |
| `39004` | [five_s](five_s.md) | `/company/five-s/inspection-plans` | พบ Route |
| `39005` | [five_s](five_s.md) | `/company/five-s/inspections` | พบ Route |
| `39006` | [five_s](five_s.md) | `/company/five-s/inspection-confirmations` | พบ Route |
| `39007` | [five_s](five_s.md) | `/company/five-s/findings` | พบ Route |
| `39008` | [five_s](five_s.md) | `/company/five-s/inspection-history` | พบ Route |
| `39009` | [five_s](five_s.md) | `/company/five-s/reports` | พบ Route |
| `39010` | [five_s](five_s.md) | `/company/five-s/settings` | พบ Route |
| `40001` | [survey](survey.md) | `/company/survey-settings` | พบ Route |
| `40002` | [survey](survey.md) | `/company/surveys` | พบ Route |
| `40003` | [survey](survey.md) | `/company/survey-approvals` | พบ Route |
| `40004` | [survey](survey.md) | `/company/survey-delivery` | พบ Route |
| `40005` | [survey](survey.md) | `/company/survey-results` | พบ Route |
| `40006` | [survey](survey.md) | `/company/survey-reports` | พบ Route |
| `40007` | [survey](survey.md) | `/company/my-surveys` | พบ Route |
| `41001` | [ระบบค่าใช้จ่าย](expense.md) | `/company/expense-settings` | พบ Route |
| `42001` | [project](project.md) | `/company/project-settings` | พบ Route |
| `42002` | [project](project.md) | `/company/project-budget-categories` | พบ Route |
| `42003` | [project](project.md) | `/company/projects` | พบ Route |
| `42004` | [project](project.md) | `/company/my-project-tasks` | พบ Route |
| `42005` | [project](project.md) | `/company/project-reports` | พบ Route |
| `43001` | [ระบบ Intranet](intranet.md) | `/company/intranet-settings` | พบ Route |
| `43002` | [ระบบ Intranet](intranet.md) | `/company/intranet-content` | พบ Route |
| `43003` | [ระบบ Intranet](intranet.md) | `/company/intranet-approvals` | พบ Route |
| `43004` | [ระบบ Intranet](intranet.md) | `/company/my-intranet` | พบ Route |
| `43005` | [ระบบ Intranet](intranet.md) | `/company/intranet-reports` | พบ Route |
| `43006` | [ระบบ Intranet](intranet.md) | `/company/intranet-annual-holidays` | พบ Route |
| `44001` | [vote](vote.md) | `/company/vote-settings` | พบ Route |
| `44002` | [vote](vote.md) | `/company/votes` | พบ Route |
| `44003` | [vote](vote.md) | `/company/vote-approvals` | พบ Route |
| `44004` | [vote](vote.md) | `/company/my-votes` | พบ Route |
| `44005` | [vote](vote.md) | `/company/vote-results` | พบ Route |
| `45001` | [ระบบขายและเอกสารการค้า](sales.md) | `/company/sales-settings` | พบ Route |
| `46001` | [pos](pos.md) | `/company/pos-settings` | พบ Route |
| `46002` | [pos](pos.md) | `/company/pos-outlets-terminals` | พบ Route |
| `46003` | [pos](pos.md) | `/company/pos-outlet-items` | พบ Route |
| `46004` | [pos](pos.md) | `/company/pos-sales` | พบ Route |
| `46005` | [pos](pos.md) | `/company/pos-cash-shifts` | พบ Route |
| `46006` | [pos](pos.md) | `/company/pos-returns` | พบ Route |
| `46007` | [pos](pos.md) | `/company/pos-reports` | พบ Route |
| `47001` | [evaluation](evaluation.md) | `/company/evaluation-settings` | พบ Route |
| `48001` | [document_control](document_control.md) | `/company/document-control-settings` | พบ Route |
| `48002` | [document_control](document_control.md) | `/company/document-types` | พบ Route |
| `48003` | [document_control](document_control.md) | `/company/controlled-documents` | พบ Route |
| `48004` | [document_control](document_control.md) | `/company/document-approvals` | พบ Route |
| `48005` | [document_control](document_control.md) | `/company/general-documents` | พบ Route |
| `48006` | [document_control](document_control.md) | `/company/document-library` | พบ Route |
| `48007` | [document_control](document_control.md) | `/company/document-acknowledgements` | พบ Route |
| `48008` | [document_control](document_control.md) | `/company/document-control-reports` | พบ Route |
| `49001` | [knowledge](knowledge.md) | `/company/knowledge-settings` | พบ Route |
| `49002` | [knowledge](knowledge.md) | `/company/knowledge-taxonomy` | พบ Route |
| `49003` | [knowledge](knowledge.md) | `/company/knowledge-articles` | พบ Route |
| `49004` | [knowledge](knowledge.md) | `/company/knowledge-reviews` | พบ Route |
| `49005` | [knowledge](knowledge.md) | `/company/knowledge-library` | พบ Route |
| `49006` | [knowledge](knowledge.md) | `/company/knowledge-questions` | พบ Route |
| `49007` | [knowledge](knowledge.md) | `/company/my-knowledge` | พบ Route |
| `49008` | [knowledge](knowledge.md) | `/company/knowledge-reports` | พบ Route |
| `50001` | [memo](memo.md) | `/company/memo-settings` | พบ Route |
| `50002` | [memo](memo.md) | `/company/memo-types` | พบ Route |
| `50003` | [memo](memo.md) | `/company/memo-approval-routes` | พบ Route |
| `50004` | [memo](memo.md) | `/company/memo-templates` | พบ Route |
| `50005` | [memo](memo.md) | `/company/memos` | พบ Route |
| `50006` | [memo](memo.md) | `/company/memo-approvals` | พบ Route |
| `50007` | [memo](memo.md) | `/company/memo-inbox` | พบ Route |
| `50008` | [memo](memo.md) | `/company/memo-history` | พบ Route |
| `50009` | [memo](memo.md) | `/company/memo-reports` | พบ Route |
| `51001` | [provider](provider.md) | `/company/provider-settings` | พบ Route |
| `51002` | [provider](provider.md) | `/company/provider-locations` | พบ Route |
| `51003` | [provider](provider.md) | `/company/provider-service-types` | พบ Route |
| `51004` | [provider](provider.md) | `/company/provider-profile` | พบ Route |
| `51005` | [provider](provider.md) | `/company/provider-approvals` | พบ Route |
| `51006` | [provider](provider.md) | `/company/provider-review-links` | พบ Route |
| `51007` | [provider](provider.md) | `/company/provider-reviews` | พบ Route |
| `51008` | [provider](provider.md) | `/company/provider-reports` | พบ Route |
| `51009` | [provider](provider.md) | `/company/provider-portfolio` | พบ Route |
| `52001` | [school](school.md) | `ไม่พบ` | พบรหัสในโมดูล |
| `53001` | [school_food](school_food.md) | `/company/school_food-settings` | พบ Route |
| `53002` | [school_food](school_food.md) | `/company/school_food-shops` | พบ Route |
| `53003` | [school_food](school_food.md) | `/company/school_food-items` | พบ Route |
| `53004` | [school_food](school_food.md) | `/company/school_food-commission` | พบ Route |
| `53005` | [school_food](school_food.md) | `/company/school_food-identifiers` | พบ Route |
| `53006` | [school_food](school_food.md) | `/company/school_food-transfers` | พบ Route |
| `53007` | [school_food](school_food.md) | `/company/school_food-wallet` | พบ Route |
| `53008` | [school_food](school_food.md) | `/company/school_food-pos` | พบ Route |
| `53009` | [school_food](school_food.md) | `/company/school_food-sales` | พบ Route |
| `53010` | [school_food](school_food.md) | `/company/school_food-students` | พบ Route |
| `53011` | [school_food](school_food.md) | `/company/school_food-settlements` | พบ Route |
| `53012` | [school_food](school_food.md) | `/company/school_food-dashboard` | พบ Route |
| `54001` | [sport](sport.md) | `/company/sport-settings` | พบ Route |
| `54002` | [sport](sport.md) | `/company/sport-types` | พบ Route |
| `54003` | [sport](sport.md) | `/company/sport-facilities` | พบ Route |
| `54004` | [sport](sport.md) | `/company/sport-levels` | พบ Route |
| `54005` | [sport](sport.md) | `/company/sport-packages` | พบ Route |
| `54006` | [sport](sport.md) | `/company/sport-members` | พบ Route |
| `54007` | [sport](sport.md) | `/company/sport-enrollments` | พบ Route |
| `54008` | [sport](sport.md) | `/company/sport-bookings` | พบ Route |
| `54009` | [sport](sport.md) | `/company/sport-checkins` | พบ Route |
| `54010` | [sport](sport.md) | `/company/sport-pos-pricing` | พบ Route |
| `54011` | [sport](sport.md) | `/company/sport-dashboard` | พบ Route |
| `55001` | [ระบบส่วนกลาง](core.md) | `companyBusinessCardOcrSettings` | พบ Route |
| `55002` | [ระบบส่วนกลาง](core.md) | `companyContacts` | พบ Route |
| `56001` | [patrol](patrol.md) | `/company/patrol-settings` | พบ Route |
| `56002` | [patrol](patrol.md) | `/company/patrol-checkpoints` | พบ Route |
| `56003` | [patrol](patrol.md) | `/company/patrol-devices` | พบ Route |
| `56004` | [patrol](patrol.md) | `/company/patrol-credentials` | พบ Route |
| `56005` | [patrol](patrol.md) | `/company/patrol-checklists` | พบ Route |
| `56006` | [patrol](patrol.md) | `/company/patrol-routes` | พบ Route |
| `56007` | [patrol](patrol.md) | `/company/patrol-schedules` | พบ Route |
| `56008` | [patrol](patrol.md) | `/company/patrol-runs` | พบ Route |
| `56009` | [patrol](patrol.md) | `/company/patrol-monitor` | พบ Route |
| `56010` | [patrol](patrol.md) | `/company/patrol-incidents` | พบ Route |
| `56011` | [patrol](patrol.md) | `/company/patrol-audit` | พบ Route |
| `56012` | [patrol](patrol.md) | `/company/patrol-dashboard` | พบ Route |
| `59003` | [ระบบส่วนกลาง](core.md) | `ไม่พบ` | พบรหัสในโมดูล |
| `60001` | [rental](rental.md) | `/company/rental-settings` | พบ Route |
| `60002` | [rental](rental.md) | `/company/rental-items` | พบ Route |
| `60003` | [rental](rental.md) | `/company/rental-availability` | พบ Route |
| `60004` | [rental](rental.md) | `/company/rental-bookings` | พบ Route |
| `60005` | [rental](rental.md) | `/company/rental-payments` | พบ Route |
| `60006` | [rental](rental.md) | `/company/rental-handover` | พบ Route |
| `60007` | [rental](rental.md) | `/company/rental-returns` | พบ Route |
| `60008` | [rental](rental.md) | `/company/rental-settlements` | พบ Route |
| `60009` | [rental](rental.md) | `/company/rental-history` | พบ Route |
| `60010` | [rental](rental.md) | `/company/rental-dashboard` | พบ Route |
| `61001` | [booking](booking.md) | `/company/booking-settings` | พบ Route |
| `61002` | [booking](booking.md) | `/company/booking-services` | พบ Route |
| `61003` | [booking](booking.md) | `/company/booking-providers` | พบ Route |
| `61004` | [booking](booking.md) | `/company/booking-resources` | พบ Route |
| `61005` | [booking](booking.md) | `/company/booking-members` | พบ Route |
| `61006` | [booking](booking.md) | `/company/booking-promotions` | พบ Route |
| `61007` | [booking](booking.md) | `/company/booking-calendar` | พบ Route |
| `61008` | [booking](booking.md) | `/company/booking-usage` | พบ Route |
| `61009` | [booking](booking.md) | `/company/booking-member-history` | พบ Route |
| `61010` | [booking](booking.md) | `/company/booking-dashboard` | พบ Route |
| `62001` | [pet](pet.md) | `/company/pet-settings` | พบ Route |
| `62002` | [pet](pet.md) | `/company/pet-services` | พบ Route |
| `62003` | [pet](pet.md) | `/company/pet-rooms` | พบ Route |
| `62004` | [pet](pet.md) | `/company/pet-profiles` | พบ Route |
| `62005` | [pet](pet.md) | `/company/pet-packages` | พบ Route |
| `62006` | [pet](pet.md) | `/company/pet-appointments` | พบ Route |
| `62007` | [pet](pet.md) | `/company/pet-work` | พบ Route |
| `62008` | [pet](pet.md) | `/company/pet-history` | พบ Route |
| `62009` | [pet](pet.md) | `/company/pet-owner-portal` | พบ Route |
| `62010` | [pet](pet.md) | `/company/pet-dashboard` | พบ Route |
| `63001` | [site](site.md) | `/company/site-site-settings` | พบ Route |
| `63002` | [site](site.md) | `/company/site-site-projects` | พบ Route |
| `63003` | [site](site.md) | `/company/site-site-daily-reports` | พบ Route |
| `63004` | [site](site.md) | `/company/site-site-publications` | พบ Route |
| `63005` | [site](site.md) | `/company/site-site-issues` | พบ Route |
| `63006` | [site](site.md) | `/company/site-site-handovers` | พบ Route |
| `63007` | [site](site.md) | `/company/site-site-customer-portal` | พบ Route |
| `63008` | [site](site.md) | `/company/site-site-dashboard` | พบ Route |
| `64001` | [ระบบส่วนกลาง](core.md) | `companyAiIntentTest` | พบ Route |
| `64002` | [ระบบส่วนกลาง](core.md) | `companyAiSettings` | พบ Route |
| `64003` | [ระบบส่วนกลาง](core.md) | `companyAiAgents` | พบ Route |
| `65001` | [ระบบส่วนกลาง](core.md) | `/company/my-system/settings` | พบ Route |
| `65002` | [ระบบส่วนกลาง](core.md) | `/company/my-system/sap-pms` | พบ Route |
| `66001` | [ระบบส่วนกลาง](core.md) | `/company/my-system/travel` | พบ Route |
| `66002` | [ระบบส่วนกลาง](core.md) | `/company/my-system/purchase` | พบ Route |
| `67001` | [ระบบค่าใช้จ่าย](expense.md) | `/company/my-system/travel-settings` | พบ Route |
| `67002` | [ระบบค่าใช้จ่าย](expense.md) | `/company/my-system/travel-route-rates` | พบ Route |
| `68001` | [ระบบอนุมัติ](approval.md) | `/company/approval-settings` | พบ Route |
| `68002` | [ระบบอนุมัติ](approval.md) | `/company/approval-assignment` | พบ Route |
| `69001` | [ระบบจัดซื้อ](purchasing.md) | `/company/my-system/purchase-settings` | พบ Route |
| `70001` | [ระบบกฎหมาย](legal.md) | `/company/my-system/legal-settings` | พบ Route |
| `70002` | [ระบบกฎหมาย](legal.md) | `/company/my-system/legal-document-request` | พบ Route |
| `70003` | [ระบบกฎหมาย](legal.md) | `/company/my-system/legal-document-types` | พบ Route |

เมนูที่มีเฉพาะในฐานข้อมูลแต่ไม่ปรากฏใน Route/โมดูล จะต้องตรวจทะเบียน `TDADMainMenu` จากฐานข้อมูลที่ใช้งานจริงอีกครั้ง; ดัชนีนี้อ้างอิง repository ณ วันที่ระบุเท่านั้น
