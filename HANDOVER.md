# ส่งมอบ LAOO-Pat (Core / Service) ให้ mon — 2026-09-27

## ขอบเขตและสถานะ

- Branch: `handover/laoo-pat-20260927`; repository: https://github.com/nodfinger/laoo
- นี่คือชุดรวบรวมงานทั้งเสร็จและไม่เสร็จ **ไม่ใช่ release ที่ผ่าน UAT ทุกระบบ**
- Source ที่เปิดทำงานได้ตั้งต้นจาก Service `68bbe459cc94f589e0a692582d0daa8f9e852cee` รวมกับ main `5c457a06e97dbe2823fae2b6297375a601e1cef6` ใน branch ส่งมอบเท่านั้น
- Integration commit: `444cd33`; ไม่แก้/merge เข้า main และไม่ reset/rebase/force push ต้นฉบับ
- เก็บ 44 worktree ของ monorepo + 2 repository เก่า + source Service เดิมที่ไม่ได้อยู่ใน Git
- หลัง push หยุดแก้ชุดนี้จนกว่าพ่อแจ้งว่า mon รับครบ
- ไม่สามารถยืนยันงานที่ยังอยู่เฉพาะเครื่องอื่น: เครื่องเหล่านั้นต้องส่ง handover branch/SHA ของตนเองให้ mon

## ไฟล์ส่งมอบและวิธีอ่าน

ทั้งหมดอยู่ใน `docs/handover/laoo-pat-20260927/`:

| ไฟล์ | ความหมาย |
|---|---|
| worktrees.json | Path, branch, baseCommit, MERGE_HEAD, รายการไฟล์แต่ละ worktree และ SHA256 |
| <label>/files/*.snapshot | Working copy ที่ยังไม่ commit; เติม suffix .snapshot เพื่อไม่ให้ compiler/analyzer โหลดเป็น source |
| <label>/index-stage-N/*.snapshot | Index เดิม: 0=staged, 1=base, 2=ours, 3=theirs |
| git-refs.txt | Local/remote branch และ SHA ตอนรวบรวม |
| local-commits/*.patch | 8 commit ที่ยังไม่มีใน remote; เก็บเนื้อหาและ commit message |
| stashes.json / stashes/<SHA>/<working,index,untracked>/*.snapshot | Git stash เก่า 9 ชุด แยก working/index/untracked และบันทึก baseCommit; คง stash ต้นฉบับไว้ |
| legacy-service-unversioned.json | รายการ source Service เดิม 461 ไฟล์และ SHA256 |
| legacy-service-unversioned/files/*.snapshot | Source ของ C:\laooplatform\laoo_service ที่ไม่ได้เป็น repository |
| migration-ledger.csv | Ledger ฐานข้อมูลเครื่องนี้ 161 รายการ |
| migration-status.csv | เทียบ SQL source ปัจจุบัน 153 รายการกับ ledger |
| menu-metadata.csv | MenuCode/MenuName/ScreenType/Route/สถานะจาก DB |
| separate-transfer.csv | ตำแหน่ง private/local config ต้องส่งผ่านช่องทางปลอดภัย ไม่ใช่เนื้อหา config |
| uploads-separate-transfer.csv | ตำแหน่ง uploads และขนาดรวม ต้องส่งแยก |
| withheld.json | ผลตรวจ credential ขั้นต้นของ working/index snapshots |

ผลเก็บ worktree: saved 219 ไฟล์, deleted 65 รายการ (เก็บสถานะการลบ ไม่สร้างไฟล์เปล่า), excluded 158 รายการ (generated/config/runtime), index 77 เวอร์ชัน และ source standalone 461 ไฟล์ ตรวจ SHA256 working source และ standalone ตรงทั้งหมด

การกู้งานค้าง: เปิด worktree ใหม่ที่ baseCommit ตาม manifest, คัดลอก snapshot โดยตัด suffix .snapshot ออกทีละชุด, ตรวจรายการ deleted ก่อนลบใน worktree ใหม่ และตรวจ staged/index เดิมเมื่อจำเป็น **ห้ามคัดลอกทุก snapshot ทับ active source พร้อมกัน** เพราะเป็นงานหลายยุคและมีไฟล์ซ้อนกัน

Repository เก่า C:\Work\laoo_visitor และ C:\Work\Laoo\รวมprojectต้นแบบ\laoo_meeting ใช้ base `ec68d1fdf7ec28101ad11a5dc8ee89eb216052d3` และ remote เดิม `https://github.com/nodfinger/laoo_meeting.git` ทั้งคู่ ชื่อ visitor ไม่ได้หมายความว่า remote เป็น Visitor ใหม่ ห้าม push ทับ remote เก่าโดยเดา

## งานที่รับผิดชอบ / MenuCode

สถานะด้านล่างอ้าง source/checklist ไม่ใช่การรับรอง UAT ใหม่ทั้งหมด ดูรายละเอียด `docs/architecture/LAOO_SERVICE_CHECKLIST.md` และ metadata CSV ประกอบ

| Project / MenuCode | งาน | สถานะส่งมอบ |
|---|---|---|
| Core 09001 | บริษัท/ลูกค้า, ownership, shared location/person/employee, navigation | มี implementation; WIP เพิ่มเติมแยก snapshot |
| Inventory 08002–08006 | สินค้า, Usage, คลัง, รับสินค้า, Serial/Asset | มี implementation; ทดสอบ workflow จริงที่ mon อีกครั้ง |
| Sales 09003–09007 | ใบเสนอราคา, Pre-order, ใบเสร็จชั่วคราว, ใบส่งของ, ใบกำกับภาษี | มี implementation ตาม checklist; ยังไม่ทดสอบครบในรอบนี้ |
| Service 14001/14002 | สถานที่กลาง / Asset และ QR | ทำแล้ว รอรับมอบ |
| Service 14005/14006 | ผู้ใช้บริการภายนอก / ผู้พักอาศัยและบัญชีเข้าใช้ | ทำแล้ว รอรับมอบ |
| Service 15001/15002 | รับแจ้งซ่อม / QR แจ้งซ่อม | ทำแล้ว; ข้อความบังคับ รูปแนบ optional |
| Service 17001 | จ่ายงานช่าง | ทำแล้ว |
| Service 17002/17003 | ทะเบียนใบงาน / เริ่มงาน / ปิดงาน / อะไหล่และตัด stock | ทำแล้ว; 17003 รวม UI ใน 17002 แต่คง route/permission เดิม; รอ UAT stock transaction |
| Service 16001–16003 | แผน PM / Checklist / ปฏิทิน PM | ทำแล้ว รอรับมอบ; มี PM WIP เก่าอีก 3 ไฟล์ใน snapshot |
| Service 18001 | ตั้งค่า Service | ทำแล้ว |
| Service 19001/19002 | Dashboard / ประวัติซ่อมและค่าใช้จ่าย | ทำแล้ว รอรับมอบ |
| Service 20001–20004 | แจ้งซ่อมเอง / ติดตาม / ประวัติ / PM | ทำแล้ว รอรับมอบ |
| Service 20006 | ร้องเรียน | ทำแล้ว รอรับมอบ |
| Service 14003 | ทะเบียนลูกค้าภายนอกอีกเมนู | พ่อสั่งยังไม่ทำ; placeholder |
| Service 20005/19003 | ประเมินความพึงพอใจ / รายงาน | ยังไม่เริ่ม; ประเมินแยกต่อการซ่อมโดยผู้ใช้บริการ ไม่เชื่อมระบบ Evaluation |
| Core shared Visitor | Host identity, Employee hosts, Host notification recipient, In-app notification, menu 32001/32002/32003/34003 | อยู่ใน baseline ตามประวัติ; ไม่ยืนยัน E2E Visitor ในรอบนี้ |
| Meeting/Training/Time/Visitor/Evaluation/Expense/Sales/Survey/Vote/Intranet และ bootstrap อื่น | งานเก่าใน branch/worktree | เก็บ refs/patch/snapshot ให้ครบที่พบ ไม่ถือว่าเสร็จเพียงเพราะรวบรวมแล้ว |

Flow หลัก: ทะเบียน/Asset/สถานที่ → แจ้งซ่อม → NEW → มอบหมาย → RECEIVED → เริ่มงาน → IN_PROGRESS → ผลซ่อม/อะไหล่/ตัด stock → COMPLETED; ยกเลิกตามสิทธิ์เป็น CANCELLED

PM: Item Type + Usage EQUIPMENT → Asset จริง → แผน/Checklist → รอบวันหรือเดือน → งาน PM → ผลตรวจและประวัติ

## งานค้างและปัญหาที่ทราบ

- worktree `core-training-flutter-feature-integration` ยัง merge ไม่จบ: `lib/app/router/app_router.dart` และ `test/app/router/business_module_contract_test.dart`; มีทั้ง conflict markers และ index stages เก็บให้แล้ว ไม่แก้แทนในรอบส่งมอบ
- `core-host-notification-recipient` มี WIP Controller/Model/Security 26 ไฟล์ ยังไม่รวมเข้า active baseline
- `laoo` มี WIP หลาย project รวม Employee/Location/Service/Time/Visitor; `service-person-roles` มี WIP Navigation/Person; ดู manifest เพื่อคืนงานทีละชุด
- `core-location-migration` มี SQL เก่า untracked: เก็บเป็นหลักฐานเท่านั้น ห้าม apply ก่อนตรวจซ้ำกับ schema/ledger
- local-only patches: 5291be4, 6c1a520, 70cca51, 8ff7914, 93c982d, aea3ed6, ce01057, e5b4d04; อาจทับ/ซ้ำสิ่งที่เข้า main แล้ว ต้องเทียบก่อนใช้
- Git stash เก่าไม่ใช่งานที่ยืนยันว่าใหม่กว่าปัจจุบัน: ให้ใช้ baseCommit และ message เปรียบเทียบก่อนนำกลับ ไม่ pop/apply ทุกชุดทับ baseline
- 20005 มีประวัติ ScreenType DB=1 แต่ client contract=2: ต้องตรวจ metadata และถามพ่อก่อนทำหน้าจอ ไม่เดาเอง
- ImageSharp build แจ้งไม่มี license: ต้องตรวจสิทธิ์การใช้งานก่อน production
- ชุด snapshot ไม่ได้ compile รวมกัน; ต้องคัดเลือก แก้ conflict และทดสอบหลังรวมที่ mon
- ยังไม่ทดสอบทุก Company/Branch, mobile/QR, notification E2E, stock rollback, UAT ผู้พักอาศัย และรายงานครบทุกหน้าจอในรอบนี้

## Migration / ฐานข้อมูล

- อ่านจาก config เครื่องเดิมโดยไม่เผยรหัสผ่าน: database `DBTDLaooService`
- Source ปัจจุบัน 153 SQL: `APPLIED_MATCH=153`, `PENDING=0`, `CHECKSUM_MISMATCH=0` เทียบเนื้อหา UTF-8 normalized newline
- Ledger มี 161 รายการ มากกว่า source ที่เลือกตรวจ: CSV เก็บทั้ง ledger ห้ามสรุปว่า 8 รายการที่ไม่อยู่ใน source ไม่จำเป็น
- ผลนี้ใช้กับฐานข้อมูลเครื่องนี้เท่านั้น ไม่ได้หมายความว่า DB เครื่อง mon apply แล้ว
- ไม่ apply migration หรือเปลี่ยน schema ในรอบส่งมอบ
- **ประวัติสำคัญ:** ก่อนรอบนี้ ledger ของ `20260924110000_LAOO_visitor_pre_register_host_identity_contract` เคยถูกปรับ checksum ด้วยมือจาก `569E4021C5A08E5EDE07D067155C66F40B1A02E44650BF2671B03CB9C23D8600` เป็น `7120BB53522E2E323448F24CF689C0F67E829166E80F3AB95C7A91518E5555C2`; การตรงกันของ checksum ปัจจุบันไม่ใช่หลักฐานว่า schema เดิมเทียบเท่ากัน ต้องตรวจ metadata จริงก่อนย้าย/ปรับ ledger อื่น ห้าม bypass checksum อัตโนมัติ
- ตรวจและรัน migration ผ่านมาตรฐานเท่านั้น: `powershell -ExecutionPolicy Bypass -File .\tools\scripts\run-migrations.ps1 -Module core`; Core ก่อน Service/Project อื่นตาม dependency โดยต้อง backup และอนุมัติ schema ตามกติกา

## สิ่งที่ต้องส่งแยก (ยังไม่ได้ส่ง)

1. Database backup ของ DBTDLaooService และฐานข้อมูลอื่นที่ legacy config อ้างอิง: ส่งเข้ารหัสผ่านช่องทางปลอดภัย พร้อม restore/ตรวจข้อมูลผู้พักอาศัย ผู้ใช้ และ stock
2. Config เช่น `C:\laooplatform\laoo\laoo_api\local.json`, local.machine.json, appsettings เฉพาะเครื่อง, .env, connection string, JWT keys, certificates/license ตามที่ใช้งานจริง; inventory เป็นรายการที่ตรวจพบ ไม่ใช่คำสั่งให้นำทุก config มาใช้
3. Uploads ของ API เช่น items, service-requests, complaint/เอกสารแนบ; ต้องรักษา path/metadata ให้ตรงฐานข้อมูล ตรวจ inventory และสำรองก่อนย้าย
4. รายงาน output/PDF เดิมและไฟล์ทดสอบที่ไม่ใช่ source หากพ่อยังต้องการเก็บ
5. SDK/toolchain, runtime, build/cache ไม่ส่งผ่าน Git ให้ติดตั้งและสร้างใหม่
6. Credentials Git/DB ต้องตั้งที่ mon แยก ห้าม commit หรือส่งรหัสผ่านในข้อความ PR

## Run / Build / Test

จาก root ของ worktree ที่รับมา หลังจัดเตรียม private config/DB แล้ว:

```powershell
dotnet build laoo_api/laoo_api.csproj
dotnet run --project laoo_api/laoo_api.csproj --launch-profile https
# API profile ปัจจุบันใช้ http://localhost:5080

flutter pub get
flutter run -d chrome --web-port 8080
# หรือ Flutter Windows ตาม workflow ทีม
flutter run -d windows

dotnet run --project tools/navigation-tests -- <root-ที่มี-laoo_api/local.json>
flutter test test/app/router/business_module_contract_test.dart
flutter analyze
flutter build web
```

ใช้ local config ให้ Web ชี้ API ถูกเครื่อง; localhost:8080 เหมือนกันไม่ได้รับประกันว่า source/DB/config เท่ากัน
Verify Center ต้องจัด local.machine.json ตาม runbook ก่อน ใช้ `tools/scripts/verify-center.ps1` และตรวจพารามิเตอร์ role/module ของ source ที่รับ

ผลตรวจรอบส่งมอบ:

- API build: ผ่าน, 0 errors, 1 ImageSharp license warning
- Navigation test: ผ่าน เมื่อส่ง root config `C:\laooplatform\laoo`; ครั้งแรกไม่ผ่านเพราะ worktree ใหม่ยังไม่มี local.json (ไม่คัดลอกรหัสผ่านเข้า Git)
- Integrity working snapshots 219 ไฟล์และ standalone 461 ไฟล์: SHA256 ตรง; index 77 เวอร์ชันตรวจ Git blob hash ตรง
- Stash 9 ชุด: เก็บ source 584 เวอร์ชัน ตรวจ Git blob hash ตรงทั้งหมด; รวม snapshots ทุกชนิด 1,341 ไฟล์ และ local-only patches 8 ชุดตรวจ parse ได้
- Flutter route contract test: ไม่ผ่าน 1 จาก 6 (ผ่าน 5); test เดิมคาด Visitor routable เฉพาะ 36004 แต่ source มี 31002/31005/32001/32002/32003/33001/34003 ด้วย ต้องทบทวน expectation กับ implementation ที่ mon ไม่ปรับ business source ในรอบส่งมอบ
- flutter pub get ระหว่างทดสอบปรับ pubspec.lock เพิ่ม dependencies ตาม pubspec ปัจจุบัน เก็บ lock นี้ร่วมส่งมอบ; generated registrants/cache ไม่ส่ง
- ไม่ได้รัน full Flutter analyze/web build หรือ E2E ทุก Project ในรอบนี้

## ขั้นตอนรับงานของ mon

1. เก็บงานเครื่อง mon ของตัวเองลง handover branch ก่อน ห้าม pull ทับ dirty tree
2. fetch แล้วสร้าง worktree ใหม่จาก `origin/handover/laoo-pat-20260927`; ตรวจ SHA ตรงรายงานส่งมอบ
3. อ่านเอกสารนี้/AGENTS/manifest และส่งมอบชุด config/DB/uploads แยกอย่างปลอดภัย
4. รวบรวม branch/SHA จากทุกเครื่องเพิ่ม: snapshot เครื่องนี้ไม่ครอบคลุมงานที่ไม่เคยส่งจากเครื่องอื่น
5. สร้าง integration branch ชั่วคราว รวม source ทีละ project พร้อม dependencies; เก็บ WIP แยกถ้ายัง build ไม่ผ่าน ไม่จำเป็นต้องรอทุก feature เสร็จก่อนเก็บงาน
6. ตรวจ Core → Shared Contracts → Project → Router/Navigation → migrations → build/test → UI/E2E
7. ให้พ่ออนุมัติ baseline รวมก่อน merge main แล้วให้ทุกเครื่อง sync SHA เดียวกันพร้อม migration/config ที่สัมพันธ์
8. แจ้งรับงานครบแล้ว เครื่องนี้จึงถือว่าส่งต่อความรับผิดชอบสำเร็จ ระหว่างนี้ต้นฉบับทุก worktree ยังคงอยู่ ห้ามลบทิ้ง
