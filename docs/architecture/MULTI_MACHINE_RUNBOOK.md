# LAOO Multi-Machine Center-Host Runbook

## Ownership

| Machine role | Owned source |
| --- | --- |
| `center-service` | Root Core, `laoo_api`, shared packages, `projects/service` |
| `meeting` | `projects/meeting` and `projects/training` |
| `visitor` | `projects/visitor` |
| `time` | `projects/time` |
| `training` | `projects/training` |
| `intranet` | `projects/intranet` |
| `vote` | `projects/vote` |
| `sales` | `projects/sales` |

Every machine clones `nodfinger/laoo` to `C:\laooplatform\laoo`. Never
share a live working tree, `.git`, `.dart_tool`, `build`, `bin`, or `obj`.
Copy `local.machine.example.json` to ignored `local.machine.json` and set the
role for that machine.

Time machine example:

```json
{
  "role": "time",
  "allowedProjects": ["LAOO_TIME"],
  "webPort": 8080,
  "apiPort": 5080
}
```

Meeting machine with Training example:

```json
{
  "role": "meeting",
  "allowedProjects": ["LAOO", "LAOO_MEETING", "LAOO_TRAINING"],
  "webPort": 8080,
  "apiPort": 5080
}
```

Copy local.machine.meeting-training.example.json to the ignored
local.machine.json on the Meeting machine. Never commit a machine local.machine.json.
Intranet machine example:

```json
{
  "role": "intranet",
  "allowedProjects": ["LAOO", "LAOO_INTRANET"],
  "webPort": 8080,
  "apiPort": 5080
}
```

Copy `local.machine.intranet.example.json` to ignored `local.machine.json` on
that machine. Never commit a real `local.machine.json`.

Vote machine example:

```json
{
  "role": "vote",
  "allowedProjects": ["LAOO", "LAOO_VOTE"],
  "webPort": 8080,
  "apiPort": 5080
}
```

Copy `local.machine.vote.example.json` to ignored `local.machine.json` on that
machine. Never commit a real `local.machine.json`.

Run `tools/scripts/check-machine-boundaries.ps1 -Module <module>` before full
verification. On Meeting, Visitor, and Time machines it rejects changed files
outside the owned Project directory. The Center machine may change Root, Core,
shared packages, and Service, and is responsible for integration verification.

## New Project bootstrap

Before assigning a new machine, the Center machine must merge a Bootstrap PR
that defines:

- ProjectCode, approved MenuCode and ScreenType, and the data ownership table;
- entitlement, Menu/ScreenType/Permission baseline, and Navigation API registration;
- every approved menu and route contract for the Project, not only the first screen;
- `projects/<project>/pubspec.yaml`, `<project>_feature.dart`, Feature Host, route contract, and `build<Project>FeatureRoutes()`;
- Root `pubspec.yaml`, `lib/main.dart`, and `app_router.dart` composition;
- a Project-owned migration directory and unique ProjectCode filename prefix;
- Core read contracts and Project-owned write contracts.

After Bootstrap reaches `main`, every machine pulls with `--ff-only`. The new
machine then works only under `projects/<project>` and runs through the Center
host. Route placeholders belong only inside the Project package; Root must not
keep a per-menu `_scopePlaceholder` after Bootstrap. Do not build the complete
Business Project in Root and move it later.

Bootstrap creates unfinished Project menus with `TDADProjectMenu.IsActive = 0`.
The Project machine opens each menu with `IsActive = 1` only in the same
Project PR that makes its route and screen usable. Menu map or route-contract
changes still require a separate Core Bootstrap extension PR first.

## Core Impact protocol

Classify every change before coding:

| Level | Meaning | Required action |
| --- | --- | --- |
| Green | Only `projects/<project>`; no public contract change | Continue in the Project PR |
| Yellow | Adds API/field/shared component | Notify Center; merge a separate compatible Core PR first |
| Red | Authentication, Permission, Person, Employee, shared schema or migration | Stop dependent work until Core PR is merged and every machine syncs |

A Core Impact description records the requested change, consuming Projects,
API/contract/schema impact, backward compatibility, migration, and merge order.
Never hide Root/Core/Shared edits inside a Project PR.

## One runtime on every machine

All developers run the Root Center host. Ports are local to each computer,
so all three machines use the same pair without conflict:

```powershell
cd C:\laooplatform\laoo\laoo_api
dotnet run
```

```powershell
cd C:\laooplatform\laoo
flutter run -d web-server --web-port 8080 --dart-define=API_URL=http://localhost:5080 --dart-define=PROJECT_CODE=LAOO
```

Business packages contribute routes and controllers to this host. The old
project ports `8081/5081`, `8082/5082`, and `8083/5083` are not part of the
target workflow.

## One API deployment

Publish only the Root Center API. The command bundles the Service, Meeting,
and Visitor module DLLs into the same deployment directory and rejects local
secret files:

```powershell
cd C:\laooplatform\laoo
.\tools\scripts\publish-center-api.ps1
```

The deployment has one executable host, `laoo_api.exe`. Business module DLLs
are implementation libraries loaded by that host; they are not separate APIs
or processes.

## Daily Git workflow

Start a task from clean, current `main`:

```powershell
git switch main
git pull --ff-only origin main
git status --short
git switch -c meeting/room-booking
```

If `main` changes while a task branch is active:

```powershell
git fetch origin
git merge origin/main
```

Resolve conflicts and run Center verification before Commit/Push/Merge:

```powershell
.\tools\scripts\verify-center.ps1 -Module meeting
```

Each machine may create and squash-merge its own PR after verification. Never
push directly to `main`, force-push, reset shared work, or copy whole projects
over another clone. After Merge, switch to `main` and pull with `--ff-only`.

Core and Project dependency order is always: compatible Core PR, machine sync,
then dependent Project PR. A single Login remains company-wide; Project access
and Role Groups remain independently assigned per Project.

## Shared database

All machines use `DBTDLaooService`. Each role owns migrations for its Project
and runs them only after explicit approval and after pulling current `main`:

```powershell
.\tools\scripts\run-migrations.ps1 -Module meeting -DryRun
.\tools\scripts\run-migrations.ps1 -Module meeting
```

For the Time role, use `-Module time`; its owned migrations are under
`projects/time/database/migrations`.
For Training work on the Meeting machine, use `-Module training`; its owned
migrations are under `projects/training/database/migrations`.

The runner validates names and checksums, writes
`dbo.TDSTSchemaMigration`, and serializes execution with the SQL application
lock `LAOO_SCHEMA_MIGRATION`. New migration names use
`yyyyMMddHHmmss_PROJECT_CODE_description.sql`. Shared schema changes require
all machines to sync first. Use backward-compatible expansion before feature
code and defer destructive contraction until every project is updated.

## Visitor status

Visitor is a package/module scaffold. Its 22 route contracts remain marked
unimplemented and must not enter the active route registry until each screen
and API is ready. Shared employee, branch, user, organization, permission,
and theme code remains in Core/shared packages.

Sales machine example:

```json
{
  "role": "sales",
  "allowedProjects": ["LAOO", "LAOO_SALES"],
  "webPort": 8080,
  "apiPort": 5080
}
```

Copy `local.machine.sales.example.json` to ignored `local.machine.json` on that
machine. Never commit a real `local.machine.json`.