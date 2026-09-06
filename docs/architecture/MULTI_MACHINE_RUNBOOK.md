# LAOO Three-Machine Development Runbook

## Ownership

| Machine | Primary ownership |
| --- | --- |
| 1 | Core, central API, shared packages, Service, database migrations, PR merge |
| 2 | `projects/meeting` |
| 3 | `projects/visitor` |

Every machine clones the complete `nodfinger/laoo` repository to
`C:\laooplatform\laoo`. Never share a live Git working tree, `.dart_tool`,
`build`, `bin`, or `obj` directory over a network.

## First-time setup

1. Install Git, the same Flutter version as Machine 1, .NET 8 SDK, VS Code,
   and the Flutter/Dart extensions.
2. Verify `git --version`, `flutter doctor -v`, `dotnet --version`, and
   `code --version`.
3. Clone only after the baseline PR has been merged into `main`:

```powershell
New-Item -ItemType Directory -Path C:\laooplatform -Force
git clone https://github.com/nodfinger/laoo.git C:\laooplatform\laoo
cd C:\laooplatform\laoo
git switch main
git pull --ff-only origin main
git status --short
```

4. Copy the assigned API's `local.example.json` to `local.json`, then set the
   `DBTDLaooService` connection and the shared JWT secret. `local.json` must
   remain ignored by Git.
5. Run `flutter pub get` in the assigned Flutter project and `dotnet restore`
   for its API.

## Standard ports and commands

| Project | Flutter | API | Project code |
| --- | ---: | ---: | --- |
| Core | 8080 | 5080 | `LAOO` |
| Service | 8081 | 5081 | `LAOO_SERVICE` |
| Visitor | 8082 | 5082 | `LAOO_VISITOR` |
| Meeting | 8083 | 5083 | `LAOO_MEETING` |

Run API and Flutter in separate PowerShell windows. Example for Visitor:

```powershell
cd C:\laooplatform\laoo\projects\visitor\laoo_visitor_api
dotnet run
```

```powershell
cd C:\laooplatform\laoo\projects\visitor
flutter run -d web-server --web-port 8082 --dart-define=API_URL=http://localhost:5082 --dart-define=PROJECT_CODE=LAOO_VISITOR
```

Use the same pattern and assigned ports for Core, Service, and Meeting.

## Daily branch workflow

Start every task from the latest clean `main`:

```powershell
cd C:\laooplatform\laoo
git switch main
git pull --ff-only origin main
git status --short
git switch -c meeting/room-booking
```

Use one task per branch: `core/...`, `service/...`, `visitor/...`,
`meeting/...`, or `integration/...`. Never develop directly on `main`.

Before pushing:

```powershell
git diff --check
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter test
dotnet build .\path\to\project.csproj -c Release
git add path\owned-by-this-task
git diff --cached --name-status
git commit -m "feat(meeting): describe the task"
git push -u origin meeting/room-booking
```

Create a Pull Request to `main`. Machine 1 checks project ownership, secrets,
permissions, scope filters, tests, API build, routes, and migration safety,
then performs a squash merge.

After merge:

```powershell
git switch main
git pull --ff-only origin main
git branch -d meeting/room-booking
```

## Shared-code and conflict rules

- Machine 1 owns `packages`, root routing, central authentication/navigation,
  and shared migration documents.
- Meeting and Visitor changes stay in their project directories. Requests for
  shared changes are integrated by Machine 1 in a separate branch.
- If a branch is behind, run `git fetch origin` and `git merge origin/main`.
- Stop and ask Machine 1 to resolve conflicts in shared packages, root router,
  authentication, navigation, or migrations.
- Never use `git reset --hard`, `git push --force`, or copy a whole project over
  another working tree.

## Shared database rules

- All local APIs connect to `DBTDLaooService`, but secrets stay in ignored
  `local.json` files.
- Only Machine 1 executes schema migrations against the cloud database.
- Machines 2 and 3 commit transaction-safe, idempotent migration scripts for
  review but do not execute them before merge approval.
- Use separate test companies for Service, Meeting, and Visitor.
- Every Partner query scopes by `PartnerID`; every customer query scopes by
  `CompanyID` and validates its Partner relationship.
- Back up the database before important migrations and record each applied
  migration once.

## Visitor bootstrap status

`projects/visitor` is the source for new Visitor business work. It reserves
Flutter/API ports `8082/5082`, uses `PROJECT_CODE=LAOO_VISITOR`, and references
the shared packages through `../../packages`.

The Visitor Project is active so Partners can see its entitlement switch. Its
six menu groups and 22 menus remain inactive until each route and API passes
integration tests. Shared employee, branch, user, organization, permission,
and theme implementations must not be copied into Visitor.
