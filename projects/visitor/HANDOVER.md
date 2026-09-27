# Visitor handover — mhon final — 2026-09-27

Branch: `handover/mhon-final-20260927`
Purpose: preserve the pending Visitor source from the previous mhon workspace for temporary ownership by mon.

## Scope and menus

| MenuCode | Menu name | Source status |
| --- | --- | --- |
| 31002 | รับผู้มาติดต่อ | Check-in, host selection, evidence, check-out and inside list |
| 31005 | ประวัติผู้มาติดต่อ | Source exists; Core metadata controls visibility |
| 32001 | นัดหมายล่วงหน้า | Appointment create/edit/cancel |
| 32002 | สถานะการอนุมัติ | Host approves or rejects appointments |
| 32003 | ยืนยันการเข้าพบ | Host confirmation and evidence review |
| 33001 | กำหนดจุดติดต่อ | Contact point and employee assignment |
| 34003 | รายการผิดปกติ | Read-only exception monitoring route and scoped API |
| 36004 | กำหนดค่าระบบ Visitor | Company Visitor settings |

## Pending source preserved by this branch

- 34003 exception route, repository and responsive UI.
- DORMITORY host selection supports both resident and employee paths.
- Exception API supports pending host confirmation, OTHER check-out, notification failure/no-channel and legacy outcome/reason mismatch.
- Visitor route tests are updated for 34003 implementation.
- `AGENTS.md` changes are included deliberately for mon to review before any eventual integration.

## Earlier related commits

- `fde6269` — Visitor flow baseline in this workspace.
- `5e0645e` / `4f85977` — exception monitoring was previously merged through another handover flow.
- `2fbdc60`, `e5e78e7` — prior Visitor handover notes and label repair.

This final branch keeps the local pending source intact; mon must compare it with current `origin/main` before integrating because `origin/main` has advanced independently.

## Files intentionally not committed

- Flutter generated plugin files under `linux/`, `macos/`, and `windows/`.
- Root `pubspec.lock`: `pubspec.yaml` is unchanged; the lock change was created by `flutter pub get` and adds transitive picker/file-selector packages only.
- `image.png`, `tmp/` PDF output and `work/` draft/scripts: local artifacts, not application source.
- `local.machine.json`, appsettings/secrets, build output, Flutter/Dart cache, runtime logs and uploads.

## Database and migrations

No new Visitor migration is pending in this local handover diff. Existing Visitor migrations are in `database/migrations/`; verify DBTDLaooService history before running anything. Use only:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\scripts\run-migrations.ps1 -Module visitor
```

## Validation and known issues

```powershell
dotnet build .\laoo_api\laoo_api.csproj --no-restore
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze projects\visitor
C:\src\flutter\bin\flutter.bat test projects\visitor\test --no-pub
powershell -ExecutionPolicy Bypass -File .\tools\scripts\check-machine-boundaries.ps1 -Module visitor
```

- API build previously passed with the pre-existing SixLabors ImageSharp license warning.
- Flutter analyze/test previously passed when the workspace dependency cache was available.
- Fresh Flutter `pub get` can fail until Windows Developer Mode enables plugin symlinks.
- Swagger generation has previously failed from duplicate `AssignmentRequest` schemas in the Time module; this is outside Visitor scope.

## What mon must check next

1. Compare this branch against current `origin/main`; do not overwrite newer ownership/integration work.
2. Resolve duplicate 34003 source if the same feature is already on main, retaining the Thai labels and scoped backend checks.
3. Enable Developer Mode, run Flutter pub get/analyze/test and then Verify Center.
4. Verify Core menu metadata/permission for 34003 and test navigation with a Company User.
5. Keep Visitor source changes separate from Core, Root Router, Authentication, Person, User and Employee.
