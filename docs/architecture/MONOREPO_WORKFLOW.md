# LAOO Monorepo Workflow

## Canonical workspace

`C:\laooplatform\laoo` is the only active source of code. Its GitHub remote
`nodfinger/laoo` is the shared source for every development machine.

```text
laoo/
├─ lib/                  LAOO Core application
├─ laoo_api/             Central API host
├─ packages/             Shared contracts, models, UI, and helpers
└─ projects/
   ├─ service/           LAOO_SERVICE business application
   ├─ visitor/           LAOO_VISITOR business application
   └─ meeting/           LAOO_MEETING business application
```

Do not develop features in `C:\laooplatform\laoo_service` or
`C:\laooplatform\laoo_meeting`. They are legacy copies retained only for
backup and comparison.

## Working on another machine

Each machine must have a separate clone. Do not share a live source folder,
`.dart_tool`, `build`, or Git working tree through a network share.

```powershell
git clone https://github.com/nodfinger/laoo.git C:\laooplatform\laoo
cd C:\laooplatform\laoo
git switch main
git pull --ff-only origin main
git switch -c core/employee
```

Use one branch per task. Examples: `core/employee`, `core/item`,
`service/repair-request`, `meeting/room-booking`, and `visitor/check-in`.
Push the branch, review/test it, then merge into `main`. Every machine pulls
the latest `main` before a new task starts.

## Ownership boundaries

| Area | Owner | Rule |
| --- | --- | --- |
| Employee | LAOO Core | Reuse the shared employee contract/UI; do not maintain per-project copies. |
| Item | LAOO Core | Complete the Core screen first; extract reusable contract/UI before another Project needs it. |
| Repair and service flow | Service | Keep under `projects/service`. |
| Meeting reservation flow | Meeting | Keep under `projects/meeting`. |
| Shared contract/UI/theme | Packages | Change only when at least two projects need the same behavior. |

## Current migration status

`laoo_meeting` was audited against `projects/meeting`. No business source,
asset, or database script is missing from the Monorepo target. The external
repository is now a legacy backup and must not receive new feature work.

The central API host is `laoo_api`. Project applications may use their own
local development ports, but must use their declared `PROJECT_CODE`:
`LAOO`, `LAOO_SERVICE`, `LAOO_VISITOR`, or `LAOO_MEETING`.

The standard local port pairs are `8080/5080` for Core, `8081/5081` for
Service, `8082/5082` for Visitor, and `8083/5083` for Meeting. Flutter reads
the API endpoint from `API_URL`.

## Verification before merge

Run the checks affected by the change from the canonical workspace:

```powershell
flutter test
flutter analyze --no-fatal-warnings --no-fatal-infos
dotnet build .\laoo_api\laoo_api.csproj -c Release
```

For a Business Project, also run its Flutter test/build from
`projects\service`, `projects\visitor`, or `projects\meeting`. Do not merge changes that require
an unpublished local copy outside the Monorepo.

The temporary non-fatal analyze flags keep existing lint debt visible while
still blocking compile errors. New or edited files must not introduce new
warnings; lint cleanup is tracked separately from the multi-machine baseline.
