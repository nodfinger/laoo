# LAOO Multi-Machine Center-Host Runbook

## Ownership locked by Project

| Machine | Role | Owned modules / source |
| --- | --- | --- |
| `core` | `center-service` | Root Core, `laoo_api`, shared packages, Stock shared domain, `service`, `sales`, `pos`, `expense`, `intranet` |
| `mhon` | `business` | `time`, `visitor`, `gate_pass`, `project` |
| `mon` | `business` | `meeting`, `training`, `evaluation`, `survey`, `vote`, `five_s` |

`Stock` is a Core shared domain, not a separate Project package. A business machine may own several modules, but every branch and PR is still limited to one `projects/<module>/**` directory.

Every machine clones the repository into its own working directory. Never share a live working tree, `.git`, `.dart_tool`, `build`, `bin`, or `obj`.

Copy the appropriate ignored example to `local.machine.json`:

```powershell
Copy-Item local.machine.mhon.example.json local.machine.json
# or local.machine.mon.example.json / local.machine.core.example.json
```

All examples require Center host ports `8080` and `5080`. Never commit the real `local.machine.json`.

## Boundary verification

`check-machine-boundaries.ps1` reads `role` and `ownedModules` from the local config. A `business` machine can verify only a module included in `ownedModules`, and it rejects every changed file outside that Project directory.

```powershell
.\tools\scripts\check-machine-boundaries.ps1 -Module time
.\tools\scripts\verify-center.ps1 -Module time
```

Run separately for each Project PR. `center-service` is reserved for Core work and can verify Root/shared integration. Project machines must not change Root Router, Navigation, entitlement, MenuCode, permissions, or a shared domain.

## New Project bootstrap

Before assigning a new Project machine, Core must merge a Bootstrap PR that defines:

- ProjectCode, entitlement, approved MenuCode/ScreenType and permission baseline;
- Navigation registration and every approved route contract;
- `projects/<project>/pubspec.yaml`, Feature Host, route contract, and `build<Project>FeatureRoutes()`;
- Root composition, migration namespace, module marker, and boundary support.

After Bootstrap reaches `main`, the Project package owns its placeholders and real GoRoutes. Root must compose the route builder once only and must not retain per-menu placeholders. Unfinished menus remain `TDADProjectMenu.IsActive = 0`.

## Project delivery rules

1. Start from current main:

```powershell
git switch main
git pull --ff-only origin main
git status --short
git switch -c <module>/<feature>
```

2. Make Green changes only in `projects/<module>/**`; use one Project and one feature per branch/PR.
3. Set a menu `IsActive = 1` only in the same Project PR that supplies its migration, API, working route/UI, and tests.
4. Before merge, run boundary check, migration dry-run, project bootstrap test, route duplicate test, and `verify-center -Module <module>`.
5. Pull `origin/main --ff-only` after every merged dependency.

## Core impact protocol

| Level | Meaning | Action |
| --- | --- | --- |
| Green | Only `projects/<project>` and no public contract change | Project owner PRs directly to `main` |
| Yellow | MenuCode, entitlement, Root integration, public route/API/shared UI contract | Core PR merges first, then Project syncs |
| Red | Person, Employee, User, Authentication, Building/Room, Item/Stock, shared schema | Stop dependent work; Core designs and merges a compatible contract first |

Never hide Root/Core/shared edits in a Project PR. Do not create client-side fallback menus.

## One runtime on every machine

All developers run the Root Center host. Ports are local to each computer, so all machines use the same pair:

```powershell
cd C:\laooplatform\laoo\laoo_api
dotnet run
```

```powershell
cd C:\laooplatform\laoo
flutter run -d web-server --web-port 8080 --dart-define=API_URL=http://localhost:5080 --dart-define=PROJECT_CODE=LAOO
```

Business packages contribute to this host. Project-specific ports are not part of the workflow.

## Shared database and migrations

All machines use `DBTDLaooService`. A Project owns only its migration namespace and runs migrations after current `main` is pulled and approval is given:

```powershell
.\tools\scripts\run-migrations.ps1 -Module <module> -DryRun
.\tools\scripts\run-migrations.ps1 -Module <module>
```

The runner validates names/checksums, records `dbo.TDSTSchemaMigration`, and serializes execution. Shared schema changes follow the Red protocol.
