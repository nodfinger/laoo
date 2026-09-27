# LAOO Handover — business machine — 2026-09-27

## สถานะการส่งมอบ

เอกสารนี้เป็น manifest สำหรับย้ายงานจากเครื่อง business ไปให้เครื่อง mon ชั่วคราว
ห้าม merge branch handover เข้าสู่ `main` โดยไม่ตรวจ conflict, Core impact และ migration ตามปกติ

`main` ณ เวลาส่งมอบ: `0137977` (`Merge pull request #85`)

## Branch ที่ต้องรับต่อ

| Branch | Commit | ขอบเขต | สถานะ |
| --- | --- | --- | --- |
| `handover/business-20260927` | เอกสารนี้ | manifest กลาง | พร้อมส่งมอบ |
| `handover/business-20260927-unified-runtime` | `f4b5193` | Evaluation + Meeting + Training + Core wiring ที่ค้างจาก unified runtime | ยังไม่ merge/ยังไม่ทดสอบครบ |
| `handover/business-20260927-training-template-selection` | `eaf7b46` | เลือกหลายชุดข้อสอบ PRE/POST และ migration | ยังไม่ merge |
| `handover/business-20260927-training-results-ui` | `8787870` | UI ผลอบรม/feature host | ยังไม่ merge |
| `handover/business-20260927-training-results-nav` | `2d321a0` | แก้ Navigation ผลอบรม | ยังไม่ merge |
| `handover/business-20260927-navigation-hotfix` | `075cbd3` | NavigationController hotfix | ยังไม่ merge |
| `business/training-results` | `ca1c86e` | branch เดิมผลอบรม | ต้องเก็บไว้เปรียบเทียบ |
| `core/navigation-results-syntax-fix` | `df3d04b` | branch เดิม Core navigation | ต้องเก็บไว้เปรียบเทียบ |
| `integration/evaluation-restore` | `dedcd03` | branch เดิม Evaluation restore | ต้องเก็บไว้เปรียบเทียบ |
| `training/results-card-standard` | `df3d04b` | branch เดิม training UI | ต้องเก็บไว้เปรียบเทียบ |
| `training/test-template-selection` | `df3d04b` | branch เดิม test selection | ต้องเก็บไว้เปรียบเทียบ |
| `training/unified-exam-results-runtime` | `a13f7bb` | base ของ unified runtime worktree | ต้องเก็บไว้เปรียบเทียบ |
| `integration/vote-feature` | `8d46c2d` | branch เดิม Vote | อยู่ใน main บางส่วนแล้ว |
| `meeting/booking-permissions-and-ux` | `b8ef72e` | branch เดิม Meeting activity type | ไม่มี source ค้าง; มีเพียง image test artifact |
| `runtime/main` | `cfdc805` | runtime worktree เดิม | ไม่มี source ค้าง; มีเฉพาะ generated files |
| `training/master-types-instructors` | `0bc2316` | master training type/instructor | ยังต้อง push branch เดิม |

## Project และ MenuCode ที่รับผิดชอบ

| Project | MenuCode | งานหลัก |
| --- | --- | --- |
| `LAOO_MEETING` | `21001–21006`, `22001–22006`, `23001`, `23002`, `23004`, `24001–24003` | จองห้อง, เชิญ/เช็กอิน/คืนห้อง, งานเตรียมห้อง, อาหาร, ปัญหาห้อง, รายงาน |
| `LAOO_TRAINING` | `37001–37005` | ประเภท/วิทยากร/ชุดข้อสอบ, ตั้งค่า, ผลอบรม, การสอบ PRE/POST หลายชุด |
| `LAOO_EVALUATION` | `47001–47007` | ตั้งค่า, template, รอบ, อนุมัติ, งานของฉัน, ผลและรายงาน |
| `LAOO_VOTE` | `44001–44005` | ตั้งค่า, หัวข้อ, อนุมัติ, โหวตของฉัน, Dashboard/รายงาน |

## งานเสร็จบน main

- PR #85 merge แล้ว: Meeting room operations/reports, Training multiple template assessment, Vote configuration/reporting
- Meeting: `22001`, `22002`, `24001`, `24002` มีหน้าจอและ API ในชุด main ปัจจุบัน
- Training: migration และ flow เลือกหลายชุด PRE/POST ใน main
- Vote: เมนู `44001–44005` และ data demo อยู่ใน main
- Migration ที่รันบนฐานข้อมูลเครื่องนี้แล้ว (ผลเป็น `SKIP` เพราะเคย apply):
  - Meeting: ถึง `20260927110000_LAOO_MEETING_room_return`
  - Training: ถึง `20260922170000_LAOO_TRAINING_booking_exam_sequence`
  - Vote: ถึง `20260926120000_LAOO_VOTE_demo_custom_target`

## งานค้าง / ต้องตรวจต่อ

### Unified runtime (`f4b5193`)

- รวม source Evaluation กลางและ integration กับ Meeting/Training แต่ยังไม่ได้ rebase บน main ล่าสุดหรือทำ route/API/runtime test ครบ
- Meeting: food distribution, room slot usage, feedback report `24003`, support task variants และ worker ประเมิน
- Training: My Training, training settings, exam/result navigation และ multiple booking exam
- Core/shared ที่อยู่ใน branch นี้: `NavigationController`, `Program.cs`, `lib/main.dart`, app router และ `Laoo.Shared.Contracts/Evaluations`
- ต้องแยก Core impact ก่อน merge: Evaluation source contract, app router/feature registration และ hosted worker

### Migration ที่อยู่ใน branch handover แต่ยัง **ไม่ได้ apply** จากงาน unified

- Evaluation: `20260924120000` ถึง `20260924141000` (`LAOO_EVALUATION`)
- Meeting: `20260923100000_LAOO_MEETING_food_distribution_menu`, `20260924100000_LAOO_MEETING_room_slot_usage`, `20260925160000_LAOO_MEETING_booking_evaluation`
- Training: `20260922100000_LAOO_TRAINING_my_training_navigation`, `20260923100000_LAOO_TRAINING_multiple_booking_exams`
- `20260920100000_LAOO_TRAINING_booking_exam_template_selection` มีทั้ง main และ handover branch: ตรวจ checksum/เนื้อหาก่อนรันซ้ำ

### Known issues

- `dotnet build laoo_api/laoo_api.csproj --no-restore` ผ่านหลัง `dotnet restore` แต่มี warning ของ `SixLabors.ImageSharp 4.1.2` ว่าไม่มี license key/file
- Flutter analyze ทั้งโมดูลมี warning เดิมนอกชุดงาน; `projects/vote/lib/features/vote/vote_pages.dart` ผ่าน analyze หลังแก้
- Worktree บางตัวเป็น stale/prunable: `.worktrees/core-item-service-contract`, `.worktrees/meeting-item-service`, `worktrees/meeting-training-booking-phase1`, `laoo-training-main`, temporary verify worktree
- ไม่ได้ merge branch handover ใดในรอบนี้

## วิธี run / build / test ล่าสุด

```powershell
dotnet restore .\laoo_api\laoo_api.csproj
dotnet build .\laoo_api\laoo_api.csproj --no-restore
flutter analyze <changed files or project path>
dotnet run --project .\laoo_api\laoo_api.csproj --no-build
flutter run -d chrome --web-port 8080
```

- API: `http://localhost:5080` — ล่าสุดตรวจได้ `200`
- Flutter web: `http://localhost:8080` — ล่าสุดตรวจได้ `200`
- ใช้ `tools/scripts/run-migrations.ps1 -Module <module>` เท่านั้นสำหรับ migration
- ก่อน merge Project branch ให้รัน `tools/scripts/check-machine-boundaries.ps1` และ `tools/scripts/verify-center.ps1` ตาม module

## Dependency / Core impact

- Evaluation integration ต้องใช้ `Laoo.Shared.Contracts/Evaluations`, `Program.cs` registration และ route/feature host ส่วนกลาง จัดเป็น Yellow/Red impact; ให้ mon แยก Core PR แบบ backward-compatible ก่อน merge Project branches
- Meeting food distribution/feedback report ใช้ข้อมูล Evaluation และ food receipt เดิม; ห้ามสร้างตารางซ้ำ
- Training template-selection เปลี่ยน contract ร่วมกับ Meeting booking repository; ตรวจ API/Flutter ทั้งสอง Project พร้อมกัน
- Navigation hotfix 2 branch เปลี่ยน `NavigationController`; เลือกเพียง diff ที่จำเป็นก่อนรวม เพื่อลด conflict

## สิ่งที่ต้องส่งแยก ห้าม commit

- `local.machine.json` และ `laoo_api/local.json` (มี role/connection/config local)
- SQL Server database `DBTDLaoo` และข้อมูล migration history
- `laoo_api/App_Data/` และ `wwwroot/uploads/` (uploads/test template files)
- Git stash ในเครื่องเดิม: `wip-generated-files-after-flutter-analyze`, `wip-local-root-and-runtime-before-sync`
- runtime/build/cache: `.dart_tool`, `build`, generated plugin registrants, `pubspec.lock` ที่เปลี่ยนเพราะ runtime, screenshots/diagnostic images
- worktree path ทั้งหมดต้องส่งเป็นรายชื่อ branch ด้านบน ไม่ต้อง copy cache หรือ temporary worktree

## ขั้นตอนรับงานบนเครื่อง mon

1. `git fetch origin --prune`
2. ตรวจ branch handover ตามตาราง โดยเริ่มจาก `handover/business-20260927-unified-runtime`
3. แยก Core PR ก่อน Project PR สำหรับ shared contracts/router/Program registration
4. ตรวจ migration ซ้ำกับ `dbo.__LaooMigrationHistory` ก่อน apply
5. ย้าย config และ uploads ผ่านช่องทางปลอดภัยแยกจาก Git
6. รัน build/analyze/test แล้วจึงเลือก merge เฉพาะชุดที่ผ่าน

