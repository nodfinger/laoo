# PAT final pending cross-project handover — 2026-09-27

## Baseline

- Working branch before this handover: `core/in-app-notifications-phase1` at `c6b44639970dce6491b63ecac43f8b1494989431` (`feat(core): extend visitor host identities`).
- Handover branch: `handover/pat-final-20260927`.
- The branch intentionally starts from the old PAT baseline, not from current `origin/main`.
- Current remote main when this handover was prepared: `a11aa08355cacf51cb29037c5f7a0199ca4bf044`.

## Pending work included

| Area | Files / purpose | State |
|---|---|---|
| Core Location | `CoreLocationController`, location and village location pages | Pending integration; overlaps current shared-location work likely |
| Employee / shared UI | `EmployeeController`, employee form models/workspace/list/test, Service employee page | Pending integration; technician/service-role changes likely overlap main |
| Service | request and QR request pages | Pending UI integration |
| Time | attendance, holiday, leave, settings and route files | Pending integration; route changes may overlap consolidated runtime |
| Visitor | check-in, contact points, routes, inside and settings | Pending integration; route/menu changes likely overlap Visitor handover |
| Meeting | room issue repository/page | Pending integration |
| Evaluation / Expense / Sales / Survey | feature host route registrations | Pending integration; high route-composition collision risk |
| Flutter shared / root | menu management page, `pubspec.lock`, Visitor lockfile | Required lockfiles included; generated plugin registrants excluded |

No migration SQL file is dirty in this working tree. The preceding commit `c6b4463` contains the Visitor host-identity contract and its migration; mon must compare it with main migration ledger before applying anything.

## Completed versus pending

- The changes here are preserved source work only. They are **not accepted as complete, tested, or merged**.
- No build, Flutter analyze, web build, migration run, or end-to-end test was run after these uncommitted edits.
- `git diff --check` had no whitespace errors before staging.

## Dependencies and generated files

- Included: `pubspec.lock`, `projects/visitor/pubspec.lock`, source, test, and this handover document.
- Excluded as generated from local Flutter runs: `linux/flutter/generated_plugin_registrant.cc`, `linux/flutter/generated_plugins.cmake`, `macos/Flutter/GeneratedPluginRegistrant.swift`, `windows/flutter/generated_plugin_registrant.cc`, `windows/flutter/generated_plugins.cmake`.
- Excluded: local config, secrets, `build`, `bin`, `obj`, `.dart_tool`, cache, runtime outputs.
- Regenerate generated files on mon with `flutter pub get` after resolving dependency versions.

## Merge risk with main

`origin/main` advanced from this branch's merge base `2e2332bf7e580bdeecd1d1d0eff506d841732f6d` to `a11aa083...` with Service, Visitor, training/runtime and machine-ownership consolidation. Do not merge this branch directly. Mon should create an integration branch from current main and cherry-pick/reconcile each area, especially:

1. Flutter router/feature-host registrations for Visitor, Time, Evaluation, Expense, Sales, Survey and Meeting.
2. Employee and Service technician fields/pages.
3. Core location pages/controller and shared models.
4. Both lockfiles and generated plugin registrants.

## Build/test after integration

```powershell
dotnet build laoo_api/laoo_api.csproj
flutter pub get
flutter analyze
flutter test
flutter build web
```

Use local config only outside Git. Run migrations through `tools/scripts/run-migrations.ps1` only after comparing the DB ledger/checksum and approving schema changes.
